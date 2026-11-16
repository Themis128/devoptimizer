"""Port of tools/Variants/02-Ultra-Performance-NoAdmin.bat — runs
dev-optimizer-fixed.ps1 -Mode 'Basic' -NoPause from the script's
directory; exit 1 on failure.
"""
import subprocess
import sys
from pathlib import Path


def main():
    script_dir = (Path(__file__).resolve().parents[2]
                  / "tools" / "Variants")
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
