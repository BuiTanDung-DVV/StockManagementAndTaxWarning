import json
import os
import math

with open(r"d:\SalesAndStockManagement\.understand-anything\tmp\ua-file-extract-results-6.json", "r", encoding="utf-8") as f:
    results_data = json.load(f)

with open(r"d:\SalesAndStockManagement\.understand-anything\tmp\ua-file-analyzer-input-6.json", "r", encoding="utf-8") as f:
    input_data = json.load(f)

batch_import_data = input_data.get("batchImportData", {})
batch_files_info = { f["path"]: f for f in input_data.get("batchFiles", []) }

metadata = {
    "backend/src/config/env.config.ts": {"summary": "Cấu hình biến môi trường và thiết lập chung cho hệ thống.", "tags": ["configuration", "env", "setup"], "type": "config"},
    "backend/src/controllers/auth.controller.ts": {"summary": "Controller xử lý xác thực người dùng, đăng nhập và đăng ký.", "tags": ["api-handler", "authentication", "security"], "type": "file"},
    "backend/src/controllers/customer.controller.ts": {"summary": "Controller quản lý thông tin khách hàng, bao gồm CRUD và lịch sử giao dịch.", "tags": ["api-handler", "customer", "management"], "type": "file"},
    "backend/src/controllers/finance.controller.ts": {"summary": "Controller xử lý các nghiệp vụ tài chính, báo cáo doanh thu và chi phí.", "tags": ["api-handler", "finance", "reporting"], "type": "file"},
    "backend/src/controllers/inventory.controller.ts": {"summary": "Controller quản lý kho hàng, nhập/xuất kho và kiểm kê.", "tags": ["api-handler", "inventory", "management"], "type": "file"},
    "backend/src/controllers/notification.controller.ts": {"summary": "Controller xử lý hệ thống thông báo gửi đến người dùng.", "tags": ["api-handler", "notification", "messaging"], "type": "file"},
    "backend/src/controllers/product.controller.ts": {"summary": "Controller quản lý danh mục và thông tin chi tiết sản phẩm.", "tags": ["api-handler", "product", "management"], "type": "file"},
    "backend/src/controllers/sales.controller.ts": {"summary": "Controller xử lý quy trình bán hàng, tạo đơn hàng và thanh toán.", "tags": ["api-handler", "sales", "order-processing"], "type": "file"},
    "backend/src/controllers/shop-member.controller.ts": {"summary": "Controller quản lý nhân viên và thành viên của cửa hàng.", "tags": ["api-handler", "staff", "management"], "type": "file"},
    "backend/src/controllers/shop-role.controller.ts": {"summary": "Controller quản lý phân quyền và vai trò trong cửa hàng.", "tags": ["api-handler", "authorization", "roles"], "type": "file"},
    "backend/src/controllers/supplier.controller.ts": {"summary": "Controller quản lý thông tin nhà cung cấp và đối tác.", "tags": ["api-handler", "supplier", "management"], "type": "file"},
    "backend/src/controllers/system.controller.ts": {"summary": "Controller xử lý các thiết lập và trạng thái hệ thống.", "tags": ["api-handler", "system", "configuration"], "type": "file"},
    "backend/src/controllers/tax-config.controller.ts": {"summary": "Controller quản lý cấu hình thuế áp dụng cho sản phẩm và hóa đơn.", "tags": ["api-handler", "tax", "configuration"], "type": "file"},
    "backend/src/controllers/tax.controller.ts": {"summary": "Controller xử lý tính toán thuế và báo cáo thuế.", "tags": ["api-handler", "tax", "calculation"], "type": "file"},
    "backend/src/customer/entities.ts": {"summary": "Định nghĩa các thực thể và cấu trúc dữ liệu liên quan đến khách hàng.", "tags": ["data-model", "customer", "database"], "type": "file"},
    "backend/src/finance/entities.ts": {"summary": "Định nghĩa các thực thể và cấu trúc dữ liệu cho nghiệp vụ tài chính.", "tags": ["data-model", "finance", "database"], "type": "file"},
    "backend/src/finance/entities/financial-ledger.entity.ts": {"summary": "Thực thể đại diện cho sổ cái tài chính lưu trữ giao dịch.", "tags": ["data-model", "finance", "ledger"], "type": "file"},
    "backend/src/finance/ledger.entity.ts": {"summary": "Thực thể quản lý chi tiết sổ cái và bút toán kế toán.", "tags": ["data-model", "finance", "accounting"], "type": "file"},
    "backend/src/index.ts": {"summary": "Điểm neo chính khởi chạy ứng dụng backend, cấu hình server và routes.", "tags": ["entry-point", "bootstrap", "server"], "type": "file"},
    "backend/src/inventory/entities.ts": {"summary": "Định nghĩa các thực thể và mô hình dữ liệu cho quản lý kho hàng.", "tags": ["data-model", "inventory", "database"], "type": "file"},
    "backend/src/inventory/lot.entity.ts": {"summary": "Thực thể quản lý lô hàng và thông tin hạn sử dụng trong kho.", "tags": ["data-model", "inventory", "batch"], "type": "file"},
    "backend/src/middleware/auth.middleware.ts": {"summary": "Middleware kiểm tra xác thực người dùng qua token JWT.", "tags": ["middleware", "authentication", "security"], "type": "file"},
    "backend/src/middleware/context.middleware.ts": {"summary": "Middleware thiết lập ngữ cảnh request, lưu trữ thông tin session hiện tại.", "tags": ["middleware", "context", "request"], "type": "file"},
    "backend/src/middleware/lock-transaction.middleware.ts": {"summary": "Middleware xử lý cơ chế khóa giao dịch để ngăn chặn tình trạng race condition.", "tags": ["middleware", "database", "concurrency"], "type": "file"},
    "backend/src/middleware/permission.middleware.ts": {"summary": "Middleware kiểm tra quyền truy cập của người dùng đối với từng tính năng.", "tags": ["middleware", "authorization", "security"], "type": "file"}
}

nodes = []
edges = []

for result in results_data.get("results", []):
    path = result.get("path")
    meta = metadata.get(path, {"summary": "Phân tích file mã nguồn.", "tags": ["code"], "type": "file"})
    lines = result.get("nonEmptyLines", 0)
    complexity = "simple"
    if lines > 200:
        complexity = "complex"
    elif lines >= 50:
        complexity = "moderate"
        
    file_id = f"file:{path}"
    if meta["type"] != "file":
        file_id = f"{meta['type']}:{path}"
        
    nodes.append({
        "id": file_id,
        "type": meta["type"],
        "name": os.path.basename(path),
        "filePath": path,
        "summary": meta["summary"],
        "tags": meta["tags"],
        "complexity": complexity,
        "languageNotes": "Sử dụng TypeScript"
    })
    
    # functions
    exported_names = {exp["name"] for exp in result.get("exports", [])}
    for func in result.get("functions", []):
        func_lines = func.get("endLine", 0) - func.get("startLine", 0) + 1
        is_exported = func["name"] in exported_names
        if func_lines >= 10 or is_exported:
            func_id = f"function:{path}:{func['name']}"
            nodes.append({
                "id": func_id,
                "type": "function",
                "name": func["name"],
                "summary": f"Hàm xử lý {func['name']} trong {os.path.basename(path)}.",
                "tags": ["function", "logic"],
                "complexity": "complex" if func_lines > 50 else ("moderate" if func_lines > 20 else "simple"),
                "lineRange": [func.get("startLine", 0), func.get("endLine", 0)]
            })
            edges.append({
                "source": file_id,
                "target": func_id,
                "type": "contains",
                "direction": "forward",
                "weight": 1.0
            })
            if is_exported:
                edges.append({
                    "source": file_id,
                    "target": func_id,
                    "type": "exports",
                    "direction": "forward",
                    "weight": 0.8
                })

    # classes
    for cls in result.get("classes", []):
        cls_lines = cls.get("endLine", 0) - cls.get("startLine", 0) + 1
        methods_count = len(cls.get("methods", []))
        is_exported = cls["name"] in exported_names
        if cls_lines >= 20 or methods_count >= 2 or is_exported:
            cls_id = f"class:{path}:{cls['name']}"
            nodes.append({
                "id": cls_id,
                "type": "class",
                "name": cls["name"],
                "summary": f"Lớp {cls['name']} định nghĩa cấu trúc dữ liệu hoặc logic tại {os.path.basename(path)}.",
                "tags": ["class", "data-model"] if "entities" in path else ["class", "component"],
                "complexity": "complex" if cls_lines > 100 else ("moderate" if cls_lines > 30 else "simple"),
                "lineRange": [cls.get("startLine", 0), cls.get("endLine", 0)]
            })
            edges.append({
                "source": file_id,
                "target": cls_id,
                "type": "contains",
                "direction": "forward",
                "weight": 1.0
            })
            if is_exported:
                edges.append({
                    "source": file_id,
                    "target": cls_id,
                    "type": "exports",
                    "direction": "forward",
                    "weight": 0.8
                })

    # imports
    for imp in batch_import_data.get(path, []):
        edges.append({
            "source": file_id,
            "target": f"file:{imp}",
            "type": "imports",
            "direction": "forward",
            "weight": 0.7
        })

# Splitting logic
node_count = len(nodes)
edge_count = len(edges)

out_dir = r"d:\SalesAndStockManagement\.understand-anything\intermediate"
os.makedirs(out_dir, exist_ok=True)

if node_count <= 60 and edge_count <= 120:
    out_path = os.path.join(out_dir, "batch-6.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"nodes": nodes, "edges": edges}, f, ensure_ascii=False, indent=2)
    print(f"Written to single file: {out_path} (Nodes: {node_count}, Edges: {edge_count})")
else:
    parts = math.ceil(max(node_count / 60, edge_count / 120))
    # Group by files
    unique_files = sorted(list(metadata.keys()))
    chunk_size = math.ceil(len(unique_files) / parts)
    
    for i in range(parts):
        chunk_files = set(unique_files[i*chunk_size : (i+1)*chunk_size])
        part_nodes = []
        part_edges = []
        
        part_node_ids = set()
        for n in nodes:
            # For file node
            fp = n.get("filePath", "")
            if fp == "" and ":" in n["id"]:
                # function:path:name
                fp = n["id"].split(":")[1]
            if fp in chunk_files:
                part_nodes.append(n)
                part_node_ids.add(n["id"])
                
        for e in edges:
            if e["source"] in part_node_ids:
                part_edges.append(e)
                
        out_path = os.path.join(out_dir, f"batch-6-part-{i+1}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({"nodes": part_nodes, "edges": part_edges}, f, ensure_ascii=False, indent=2)
        print(f"Written part {i+1} to {out_path} (Nodes: {len(part_nodes)}, Edges: {len(part_edges)})")
