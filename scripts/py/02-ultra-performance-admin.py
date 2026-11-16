"""Port of tools/Variants/02-Ultra-Performance-Admin.bat —
identical behavior to the NoAdmin variant (the original's
:checkAdmin is never invoked): run dev-optimizer-fixed.ps1
-Mode 'Basic' -NoPause from the script's directory.
"""
import subprocess
import sys
from pathlib import Path


def main():
    script_dir = Path(__file__).resolve().parent
    target = script_dir / "dev-optimizer-fixed.ps1"
    print("\nRunning 02-Ultra-Performance.bat...\n")
    r = subprocess.run(
        ["powershell", "-ExecutionPolicy", "Bypass", "-Command",
         "& {Set-ExecutionPolicy Bypass -Scope Process -Force;"
         f" & '{target}' -Mode 'Basic' -NoPause}}"])
    if r.returncode != 0:
        print("ERROR: Operation failed Make sure you are running"
              " as Administrator.")
        if sys.stdin.isatty():
            input("Press Enter to exit...")
        return 1
    print("Operation completed successfully")
    if sys.stdin.isatty():
        input("Press Enter to exit...")
    return 0


if __name__ == "__main__":
    sys.exit(main())
