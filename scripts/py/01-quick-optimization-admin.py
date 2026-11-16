# REQUIRES: admin
"""Port of tools/Variants/01-Quick-Optimization-Admin.bat.

Identical to the NoAdmin variant plus an admin gate; delegates
to the noadmin sibling after the gate.
"""

import ctypes
import subprocess
import sys
from pathlib import Path


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def main():
    if not is_admin():
        print("Administrator privileges required.")
        return 1
    sib = Path(__file__).with_name("01-quick-optimization-noadmin.py")
    return subprocess.run([sys.executable, str(sib)]
                          + sys.argv[1:]).returncode


if __name__ == "__main__":
    sys.exit(main())
