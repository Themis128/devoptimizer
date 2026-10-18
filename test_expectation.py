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

def test_expectation(input_path, should_be_blocked, description):
    """Test what the test expectation logic would be"""
    dev_optimizer_root = Path("D:/DevOptimizer").resolve()
    
    result_path = get_config_path(input_path)
    
    try:
        result_path.relative_to(dev_optimizer_root)
        is_within_root = True
    except ValueError:
        is_within_root = False
    
    # This is the test's logic
    if should_be_blocked:
        passed = not is_within_root
        status = "BLOCKED" if not is_within_root else "NOT BLOCKED"
    else:
        passed = is_within_root
        status = "ALLOWED" if is_within_root else "BLOCKED"
    
    print(f"{'PASS' if passed else 'FAIL'} | {description:35} | {status} (is_within_root={is_within_root})")
    return passed

print("Testing expectation logic...")
print("=" * 60)

test_cases = [
    # (input_path, should_be_blocked, description)
    ("", False, "Empty string"),
    (None, False, "None value"),
    ("configs/system-config.json", False, "Normal relative path"),
    ("./configs/system-config.json", False, "Path with leading dot"),
    ("/configs/system-config.json", False, "Path with leading slash"),
    ("../configs/system-config.json", True, "Path with parent directory"),
    ("..\\configs\\system-config.json", True, "Path with Windows parent directory"),
    ("configs/../system-config.json", True, "Path with embedded parent directory"),
    ("/etc/passwd", True, "Absolute path outside root"),
    ("D:\\Windows\\System32\\config\\sam", True, "Windows absolute path outside root"),
    ("configs/../../etc/passwd", True, "Multiple parent directories"),
    ("..", True, "Just parent directory"),
    (".", True, "Current directory"),
    ("configs/./system-config.json", False, "Path with current directory reference"),
]

all_passed = True
for input_path, should_be_blocked, description in test_cases:
    passed = test_expectation(input_path, should_be_blocked, description)
    if not passed:
        all_passed = False

print("=" * 60)
if all_passed:
    print("All tests PASSED according to expectation logic!")
else:
    print("Some tests FAILED according to expectation logic!")