import json
import os

out_dir = r"d:\SalesAndStockManagement\.understand-anything\intermediate"
# Read from the parts and combine them back to re-split properly
nodes = []
edges = []
for i in range(1, 5):
    with open(os.path.join(out_dir, f"batch-6-part-{i}.json"), "r", encoding="utf-8") as f:
        data = json.load(f)
        nodes.extend(data["nodes"])
        edges.extend(data["edges"])

# Group by files
files = sorted(list(set([n.get("filePath", n["id"].split(":")[1] if ":" in n["id"] else "") for n in nodes])))

parts_data = []
current_nodes = []
current_edges = []
current_node_ids = set()

for f in files:
    # get nodes for this file
    f_nodes = [n for n in nodes if n.get("filePath", n["id"].split(":")[1] if ":" in n["id"] else "") == f]
    f_node_ids = set([n["id"] for n in f_nodes])
    
    # get edges for this file
    f_edges = [e for e in edges if e["source"] in f_node_ids]
    
    if len(current_nodes) + len(f_nodes) > 60 or len(current_edges) + len(f_edges) > 120:
        if len(current_nodes) > 0:
            parts_data.append({"nodes": current_nodes, "edges": current_edges})
            current_nodes = []
            current_edges = []
            current_node_ids = set()
            
    current_nodes.extend(f_nodes)
    current_edges.extend(f_edges)
    current_node_ids.update(f_node_ids)

if len(current_nodes) > 0:
    parts_data.append({"nodes": current_nodes, "edges": current_edges})

# Write to files
for i, part in enumerate(parts_data):
    out_path = os.path.join(out_dir, f"batch-6-part-{i+1}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(part, f, ensure_ascii=False, indent=2)
    print(f"Written part {i+1} to {out_path} (Nodes: {len(part['nodes'])}, Edges: {len(part['edges'])})")

