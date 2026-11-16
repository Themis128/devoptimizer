"""AWS IaC manager (port of
tools/Variants/AWS-IAC-MANAGER-*.bat — the UTF-8 variant).

Same menu as the ASCII variant; delegates to
aws-iac-manager-ascii.py via importlib.
"""

import importlib.util
from pathlib import Path

# CATEGORY: utilities
# TAGS: aws, iac, cloudformation, menu

_spec = importlib.util.spec_from_file_location(
    "aws_iac_manager_ascii",
    Path(__file__).resolve().parent / "aws-iac-manager-ascii.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

if __name__ == "__main__":
    _mod.main()
