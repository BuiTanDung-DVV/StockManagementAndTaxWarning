import json
import re
import os
import math

with open(r'd:\SalesAndStockManagement\.understand-anything\tmp\ua-file-analyzer-input-9.json', 'r', encoding='utf-8') as f:
    input_data = json.load(f)
    
with open(r'd:\SalesAndStockManagement\.understand-anything\tmp\ua-file-extract-results-9.json', 'r', encoding='utf-8') as f:
    extract_data = json.load(f)

batch_files = {item['path']: item for item in input_data['batchFiles']}
batch_import_data = input_data.get('batchImportData', {})
neighbor_map = input_data.get('neighborMap', {})

nodes = []
edges = []

def get_node_type(file_category, file_path):
    if file_category == 'code': return 'file'
    if file_category == 'config': return 'config'
    if file_category == 'docs': return 'document'
    if file_category == 'script': return 'file'
    if file_category == 'markup': return 'file'
    if file_category == 'infra':
        name = file_path.lower()
        if 'docker' in name or 'k8s' in name: return 'service'
        if '.github' in name or '.gitlab' in name: return 'pipeline'
        return 'resource'
    if file_category == 'data':
        name = file_path.lower()
        if name.endswith('.sql'): return 'table'
        if name.endswith('.graphql') or name.endswith('.proto') or name.endswith('.prisma'): return 'schema'
        return 'endpoint'
    return 'file'

def determine_complexity(lines):
    if lines < 50: return 'simple'
    elif lines <= 200: return 'moderate'
    else: return 'complex'

def get_summary_and_tags(file_category, file_path, lines):
    path_lower = file_path.lower()
    summary = "Cung cấp các chức năng liên quan đến " + os.path.basename(file_path)
    tags = []
    
    if file_category == 'code':
        if 'router' in path_lower:
            summary = "Định tuyến và điều hướng các màn hình trong ứng dụng."
            tags = ['router', 'configuration', 'navigation']
        elif 'api_client' in path_lower:
            summary = "Cấu hình HTTP client, quản lý token và giao tiếp với API."
            tags = ['api-client', 'network', 'utility']
        elif 'theme' in path_lower:
            summary = "Định nghĩa giao diện, màu sắc và theme cho ứng dụng."
            tags = ['theme', 'ui', 'configuration']
        elif 'test' in path_lower:
            summary = "Chứa các bài kiểm thử tự động cho hệ thống."
            tags = ['test', 'quality-assurance']
        elif 'utils' in path_lower:
            summary = "Cung cấp các hàm tiện ích hỗ trợ tái sử dụng."
            tags = ['utility', 'helper']
        elif 'appdelegate' in path_lower or 'scenedelegate' in path_lower:
            summary = "Điểm khởi đầu của ứng dụng trên iOS, quản lý vòng đời ứng dụng."
            tags = ['entry-point', 'ios', 'lifecycle']
        else:
            summary = "Tệp mã nguồn " + os.path.basename(file_path) + " của dự án."
            tags = ['source-code', 'component']
    elif file_category == 'config':
        summary = "Tệp cấu hình " + os.path.basename(file_path) + " cho dự án."
        tags = ['configuration', 'setup']
    elif file_category == 'docs':
        summary = "Tài liệu hướng dẫn hoặc mô tả liên quan đến " + os.path.basename(file_path)
        tags = ['documentation', 'guide']
    else:
        summary = "Tệp " + os.path.basename(file_path) + " thuộc loại " + file_category
        tags = ['misc', file_category]
        
    return summary, tags[:5]

for result in extract_data.get('results', []):
    path = result['path']
    file_cat = result['fileCategory']
    lines = result['nonEmptyLines']
    node_type = get_node_type(file_cat, path)
    
    summary, tags = get_summary_and_tags(file_cat, path, lines)
    
    file_node_id = f"{node_type}:{path}"
    
    nodes.append({
        "id": file_node_id,
        "type": node_type,
        "name": os.path.basename(path),
        "filePath": path,
        "summary": summary,
        "tags": tags,
        "complexity": determine_complexity(lines)
    })
    
    # Check imports
    imports = batch_import_data.get(path, [])
    for imp in imports:
        edges.append({
            "source": file_node_id,
            "target": f"file:{imp}",
            "type": "imports",
            "direction": "forward",
            "weight": 0.7
        })

    # Supplement class/func for Dart and Swift
    if path.endswith('.dart') or path.endswith('.swift'):
        try:
            with open(os.path.join(r'd:\SalesAndStockManagement', path), 'r', encoding='utf-8') as sf:
                content = sf.read()
            # Basic regex for class
            class_pattern = r'class\s+([A-Za-z0-9_]+)'
            classes = set(re.findall(class_pattern, content))
            for c in classes:
                if c in ['ChangeNotifier', 'Exception']: continue
                c_id = f"class:{path}:{c}"
                nodes.append({
                    "id": c_id,
                    "type": "class",
                    "name": c,
                    "summary": f"Lớp {c} trong {os.path.basename(path)}.",
                    "tags": ["class", "model-or-service", "oop"],
                    "complexity": "simple"
                })
                edges.append({
                    "source": file_node_id,
                    "target": c_id,
                    "type": "contains",
                    "direction": "forward",
                    "weight": 1.0
                })
        except Exception as e:
            print("Error reading", path, e)

# Split if needed
nodeCount = len(nodes)
edgeCount = len(edges)

if nodeCount <= 60 and edgeCount <= 120:
    out_path = r'd:\SalesAndStockManagement\.understand-anything\intermediate\batch-9.json'
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump({"nodes": nodes, "edges": edges}, f, indent=2, ensure_ascii=False)
    print(f"Wrote single part to {out_path} with {nodeCount} nodes and {edgeCount} edges")
else:
    parts = math.ceil(max(nodeCount / 60, edgeCount / 120))
    # chunking based on files to keep nodes and edges consistent
    file_paths = sorted(list(batch_files.keys()))
    chunk_size = math.ceil(len(file_paths) / parts)
    
    for i in range(parts):
        part_paths = file_paths[i*chunk_size : (i+1)*chunk_size]
        part_nodes = [n for n in nodes if ('filePath' in n and n['filePath'] in part_paths) or (':' in n['id'] and n['id'].split(':')[1] in part_paths)]
        part_node_ids = set([n['id'] for n in part_nodes])
        part_edges = [e for e in edges if e['source'] in part_node_ids]
        
        out_path = fr'd:\SalesAndStockManagement\.understand-anything\intermediate\batch-9-part-{i+1}.json'
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump({"nodes": part_nodes, "edges": part_edges}, f, indent=2, ensure_ascii=False)
        print(f"Wrote part {i+1} to {out_path} with {len(part_nodes)} nodes and {len(part_edges)} edges")
