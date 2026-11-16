"""Port of tools/Variants/06-System-Health-Check-Admin.bat —
same health check as the NoAdmin variant but refuses to run
unelevated. Delegates to 06-system-health-check-noadmin.py once
the admin gate passes.
"""
import ctypes
import subprocess
import sys
from pathlib import Path


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except (AttributeError, OSError):
        return False


def main():
    if not is_admin():
        print("\n[ERROR] This script requires Administrator"
              " privileges.")
        print("Please run this script as Administrator.\n")
        if sys.stdin.isatty():
            input("Press Enter to exit...")
        return 1
    print("[INFO] Running with Administrator privileges")
    sib = Path(__file__).with_name(
        "06-system-health-check-noadmin.py")
    r = subprocess.run([sys.executable, str(sib)] + sys.argv[1:])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
