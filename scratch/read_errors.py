import os

path = r"d:\SalesAndStockManagement\scratch\analyze_output.txt"
if os.path.exists(path):
    with open(path, "r", encoding="utf-16") as f:
        lines = f.readlines()
    print(f"Total lines: {len(lines)}")
    for line in lines[:30]:
        print(line.strip())
else:
    print("File not found")
