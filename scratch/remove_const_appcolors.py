import re
import os
import sys

# Reconfigure stdout to support unicode prints on Windows console
sys.stdout.reconfigure(encoding='utf-8')

workspace = r"d:\SalesAndStockManagement"
analyze_log_path = os.path.join(workspace, "scratch", "analyze_output.txt")

# Regex to capture: file_path, line_number
error_pattern = re.compile(
    r"error - [^-]+ - (lib[\\/][^:]+):(\d+):\d+ - (invalid_constant|const_with_non_constant_argument)"
)

if not os.path.exists(analyze_log_path):
    print("Analyze log not found!")
    exit(1)

# Read captured analyze errors in UTF-16
with open(analyze_log_path, "r", encoding="utf-16") as f:
    log_content = f.read()

errors = []
for line in log_content.splitlines():
    match = error_pattern.search(line)
    if match:
        rel_path = match.group(1)
        line_num = int(match.group(2))
        abs_path = os.path.join(workspace, rel_path)
        errors.append((abs_path, line_num))

print(f"Found {len(errors)} error instances to resolve.")

# Group errors by file so we can read and write each file once
from collections import defaultdict
file_errors = defaultdict(list)
for path, line in errors:
    file_errors[path].append(line)

# Track how many replacements we did
total_replacements = 0

for file_path, lines in file_errors.items():
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        continue
        
    print(f"Processing {file_path} with errors at lines: {lines}")
    
    with open(file_path, "r", encoding="utf-8") as f:
        file_lines = f.readlines()
        
    # We sort error lines in descending order, but wait, 
    # we aren't adding/removing lines, just editing lines in-place,
    # so line numbers remain completely stable!
    
    for err_line_1idx in lines:
        err_line_idx = err_line_1idx - 1
        
        # 1. Check if the line itself contains 'const'
        line_content = file_lines[err_line_idx]
        if re.search(r"\bconst\b", line_content):
            new_line = re.sub(r"\bconst\b\s*", "", line_content)
            file_lines[err_line_idx] = new_line
            total_replacements += 1
            print(f"  Fixed inline at line {err_line_1idx}: {line_content.strip()} -> {new_line.strip()}")
            continue
            
        # 2. If not, scan backwards (up to 15 lines) to find the parent const keyword
        found = False
        for back_idx in range(err_line_idx - 1, max(-1, err_line_idx - 15), -1):
            back_line = file_lines[back_idx]
            if re.search(r"\bconst\b", back_line):
                new_back_line = re.sub(r"\bconst\b\s*", "", back_line)
                file_lines[back_idx] = new_back_line
                total_replacements += 1
                found = True
                print(f"  Fixed parent at line {back_idx + 1}: {back_line.strip()} -> {new_back_line.strip()}")
                break
        
        if not found:
            print(f"  [Warning] Could not find const keyword for error at line {err_line_1idx} in {file_path}")

    # Write back the modified content
    with open(file_path, "w", encoding="utf-8") as f:
        f.writelines(file_lines)

print(f"Successfully finished refactoring. Total const replacements: {total_replacements}")
