import json
import os
import math

with open(r'd:\SalesAndStockManagement\.understand-anything\tmp\ua-file-extract-results-8.json', 'r', encoding='utf8') as f:
    data = json.load(f)

with open(r'd:\SalesAndStockManagement\.understand-anything\tmp\ua-file-analyzer-input-8.json', 'r', encoding='utf8') as f:
    input_data = json.load(f)

batchImportData = input_data.get('batchImportData', {})
neighborMap = input_data.get('neighborMap', {})

nodes = []
edges = []

file_info = {
    "backend/src/services/inventory.service.ts": {"summary": "Service quản lý hàng tồn kho, xử lý kiểm kê, tính toán giá vốn và điều chỉnh kho.", "tags": ["service", "inventory", "business-logic", "data-model"]},
    "backend/src/services/notification.service.ts": {"summary": "Service gửi thông báo và quản lý các loại cảnh báo trong hệ thống.", "tags": ["service", "notification", "utility"]},
    "backend/src/services/posting.service.ts": {"summary": "Service quản lý hạch toán và ghi nhận các bút toán kế toán.", "tags": ["service", "accounting", "business-logic"]},
    "backend/src/services/product.service.ts": {"summary": "Service quản lý thông tin sản phẩm, danh mục, và giá bán.", "tags": ["service", "product", "business-logic", "data-model"]},
    "backend/src/services/profile.service.ts": {"summary": "Service quản lý thông hồ sơ người dùng và cửa hàng.", "tags": ["service", "profile", "user-management"]},
    "backend/src/services/sales.service.ts": {"summary": "Service quản lý quy trình bán hàng, xử lý đơn hàng và thanh toán.", "tags": ["service", "sales", "business-logic", "transaction"]},
    "backend/src/services/shop-member.service.ts": {"summary": "Service quản lý thành viên trong cửa hàng và phân quyền truy cập.", "tags": ["service", "authorization", "user-management"]},
    "backend/src/services/shop-role.service.ts": {"summary": "Service định nghĩa và quản lý vai trò của người dùng trong hệ thống cửa hàng.", "tags": ["service", "authorization", "role-management"]},
    "backend/src/services/sms.service.ts": {"summary": "Service tích hợp và xử lý việc gửi tin nhắn SMS.", "tags": ["service", "sms", "integration"]},
    "backend/src/services/supplier.service.ts": {"summary": "Service quản lý thông tin nhà cung cấp và lịch sử giao dịch.", "tags": ["service", "supplier", "data-model"]},
    "backend/src/services/system.service.ts": {"summary": "Service xử lý các tác vụ hệ thống và cấu hình chung.", "tags": ["service", "system", "configuration"]},
    "backend/src/services/tax.service.ts": {"summary": "Service tính toán thuế, xử lý các nghiệp vụ liên quan đến thuế quan và hóa đơn.", "tags": ["service", "tax", "accounting"]},
    "backend/src/shop/entities.ts": {"summary": "Định nghĩa các entity liên quan đến cửa hàng, thông tin cấu hình và chi tiết shop.", "tags": ["entity", "database", "data-model"]},
    "backend/src/supplier/entities.ts": {"summary": "Định nghĩa entity cho nhà cung cấp và các thông tin liên hệ liên quan.", "tags": ["entity", "database", "data-model"]},
    "backend/src/system/audit-log.subscriber.ts": {"summary": "Subscriber cơ sở dữ liệu để tự động ghi log các thay đổi và thao tác hệ thống.", "tags": ["subscriber", "audit-log", "database", "event-handler"]},
    "backend/src/system/entities.ts": {"summary": "Định nghĩa các entity hệ thống bao gồm hồ sơ cửa hàng, nhật ký hoạt động và hóa đơn.", "tags": ["entity", "database", "data-model"]},
    "fix_imports.js": {"summary": "Script hỗ trợ tự động sửa lỗi đường dẫn import trong mã nguồn.", "tags": ["script", "utility", "build-system"]},
    "fix_imports2.js": {"summary": "Script hỗ trợ phụ để sửa lỗi và điều chỉnh định dạng import code.", "tags": ["script", "utility", "build-system"]},
    "ios/Flutter/AppFrameworkInfo.plist": {"summary": "Tệp cấu hình plist cho framework ứng dụng Flutter trên nền tảng iOS.", "tags": ["configuration", "ios", "flutter", "mobile"]},
    "ios/Flutter/Debug.xcconfig": {"summary": "Cấu hình build debug của Xcode cho dự án Flutter iOS.", "tags": ["configuration", "ios", "build-system", "debug"]},
    "ios/Flutter/Release.xcconfig": {"summary": "Cấu hình build release của Xcode cho dự án Flutter iOS.", "tags": ["configuration", "ios", "build-system", "release"]},
    "ios/Runner.xcodeproj/project.pbxproj": {"summary": "Tệp tin project chính của Xcode chứa các cấu hình build, liên kết thư viện cho iOS.", "tags": ["configuration", "ios", "xcode", "project-file"]},
    "ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata": {"summary": "Định nghĩa cấu trúc workspace Xcode cho runner iOS.", "tags": ["configuration", "ios", "xcode", "workspace"]},
    "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist": {"summary": "Cấu hình kiểm tra workspace Xcode của môi trường phát triển.", "tags": ["configuration", "ios", "xcode"]},
    "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings": {"summary": "Cài đặt workspace Xcode quy định các thiết lập chia sẻ chung cho iOS.", "tags": ["configuration", "ios", "xcode"]}
}

for file_result in data.get('results', []):
    path = file_result['path']
    fileCategory = file_result.get('fileCategory', 'code')
    lines = file_result.get('nonEmptyLines', 0)
    
    node_type = 'file'
    if fileCategory == 'config':
        node_type = 'config'
    elif fileCategory == 'docs':
        node_type = 'document'
    elif fileCategory == 'infra':
        node_type = 'service' if ('docker' in path.lower() or 'manifest' in path.lower()) else ('resource' if 'tf' in path.lower() else 'pipeline')
    elif fileCategory == 'data':
        node_type = 'table' if 'sql' in path.lower() else ('schema' if 'schema' in path.lower() or 'graphql' in path.lower() else 'endpoint')
        
    if path.endswith('.pbxproj') or path.endswith('.xcworkspacedata') or path.endswith('.xcsettings'):
        node_type = 'config'

    complexity = 'complex' if lines > 200 else ('moderate' if lines > 50 else 'simple')
    info = file_info.get(path, {"summary": "Tệp tin mã nguồn.", "tags": ["file"]})
    
    file_node_id = f"{node_type}:{path}"
    nodes.append({
        "id": file_node_id,
        "type": node_type,
        "name": os.path.basename(path),
        "filePath": path,
        "summary": info["summary"],
        "tags": info["tags"],
        "complexity": complexity
    })
    
    if path in batchImportData:
        for imp in batchImportData[path]:
            edges.append({"source": file_node_id, "target": f"file:{imp}", "type": "imports", "direction": "forward", "weight": 0.7})
            
    for func in file_result.get('functions', []):
        func_lines = func['endLine'] - func['startLine'] + 1
        is_exported = any(e['name'] == func['name'] for e in file_result.get('exports', []))
        if func_lines >= 10 or is_exported:
            func_id = f"function:{path}:{func['name']}"
            nodes.append({
                "id": func_id,
                "type": "function",
                "name": func['name'],
                "summary": f"Hàm {func['name']} xử lý nghiệp vụ.",
                "tags": ["function", "business-logic"],
                "complexity": "moderate" if func_lines > 20 else "simple",
                "lineRange": [func['startLine'], func['endLine']]
            })
            edges.append({"source": file_node_id, "target": func_id, "type": "contains", "direction": "forward", "weight": 1.0})
            if is_exported:
                edges.append({"source": file_node_id, "target": func_id, "type": "exports", "direction": "forward", "weight": 0.8})

    for cls in file_result.get('classes', []):
        cls_lines = cls['endLine'] - cls['startLine'] + 1
        num_methods = len(cls.get('methods', []))
        is_exported = any(e['name'] == cls['name'] for e in file_result.get('exports', []))
        if cls_lines >= 20 or num_methods >= 2 or is_exported:
            cls_id = f"class:{path}:{cls['name']}"
            nodes.append({
                "id": cls_id,
                "type": "class",
                "name": cls['name'],
                "summary": f"Lớp {cls['name']} quản lý dữ liệu và logic.",
                "tags": ["class", "data-model"],
                "complexity": "complex" if cls_lines > 100 else ("moderate" if cls_lines > 50 else "simple"),
                "lineRange": [cls['startLine'], cls['endLine']]
            })
            edges.append({"source": file_node_id, "target": cls_id, "type": "contains", "direction": "forward", "weight": 1.0})
            if is_exported:
                edges.append({"source": file_node_id, "target": cls_id, "type": "exports", "direction": "forward", "weight": 0.8})

print(f"Total nodes: {len(nodes)}")
print(f"Total edges: {len(edges)}")

os.makedirs(r'd:\SalesAndStockManagement\.understand-anything\intermediate', exist_ok=True)

parts = math.ceil(max(len(nodes) / 60, len(edges) / 120))
if parts <= 1:
    with open(r'd:\SalesAndStockManagement\.understand-anything\intermediate\batch-8.json', 'w', encoding='utf8') as f:
        json.dump({"nodes": nodes, "edges": edges}, f, indent=2, ensure_ascii=False)
    print("Written 1 parts.")
else:
    sorted_files = sorted(file_result['path'] for file_result in data.get('results', []))
    chunk_size = math.ceil(len(sorted_files) / parts)
    
    for k in range(parts):
        chunk_files = set(sorted_files[k*chunk_size : (k+1)*chunk_size])
        
        def get_file_path(node):
            if 'filePath' in node:
                return node['filePath']
            else:
                return node['id'].split(':')[1]

        part_nodes = [n for n in nodes if get_file_path(n) in chunk_files]
        part_node_ids = set(n['id'] for n in part_nodes)
        part_edges = [e for e in edges if e['source'] in part_node_ids]
        
        with open(fr'd:\SalesAndStockManagement\.understand-anything\intermediate\batch-8-part-{k+1}.json', 'w', encoding='utf8') as f:
            json.dump({"nodes": part_nodes, "edges": part_edges}, f, indent=2, ensure_ascii=False)
    print(f"Written {parts} parts.")
