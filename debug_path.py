#!/usr/bin/env python3
import sys
import os
import importlib.util

# Load the config-loader module
spec = importlib.util.spec_from_file_location(
    "config_loader", 
    os.path.join(os.path.dirname(__file__), "modules", "config-loader.py")
)
config_loader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config_loader)
get_config_path = config_loader.get_config_path

from pathlib import Path

# Test the specific case that's failing
test_path = "../configs/system-config.json"
result_path = get_config_path(test_path)

print(f"Input path: {test_path}")
print(f"Returned path: {result_path}")
print(f"Returned path string: {str(result_path)}")

dev_optimizer_root = Path("D:/DevOptimizer").resolve()
print(f"DevOptimizer root: {dev_optimizer_root}")

try:
    relative = result_path.relative_to(dev_optimizer_root)
    print(f"Relative to root: {relative}")
    print(f"Is within root: True")
except ValueError as e:
    print(f"Is within root: False - {e}")

# Also test what the safe default should be
safe_default = dev_optimizer_root / "configs" / "system-config.json"
print(f"Safe default: {safe_default}")
print(f"Safe default string: {str(safe_default)}")

try:
    relative_safe = safe_default.relative_to(dev_optimizer_root)
    print(f"Safe default relative to root: {relative_safe}")
    print(f"Safe default is within root: True")
except ValueError as e:
    print(f"Safe default is within root: False - {e}")