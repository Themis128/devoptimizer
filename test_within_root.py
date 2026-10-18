#!/usr/bin/env python3
from pathlib import Path

dev_optimizer_root = Path("D:/DevOptimizer").resolve()
print(f"DevOptimizer root: {dev_optimizer_root}")

# Test various paths
test_paths = [
    "D:/DevOptimizer/configs/system-config.json",
    "D:/DevOptimizer/configs/../system-config.json", 
    "D:/DevOptimizer/../DevOptimizer/configs/system-config.json",
    "D:/Other/configs/system-config.json",
    "/etc/passwd"
]

for path_str in test_paths:
    path = Path(path_str)
    try:
        relative = path.relative_to(dev_optimizer_root)
        print(f"{path_str:50} -> WITHIN ROOT: {relative}")
    except ValueError:
        print(f"{path_str:50} -> NOT WITHIN ROOT")