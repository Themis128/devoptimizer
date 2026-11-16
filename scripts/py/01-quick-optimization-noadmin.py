"""Port of tools/Variants/01-Quick-Optimization-NoAdmin.bat —
banner + error-logged wrapper running dev-optimizer-fixed.ps1
-Mode 'Basic' -NoPause; exit = error count.
"""
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = (Path(__file__).resolve().parents[2]
            / "tools" / "Variants")
LOG_FILE = SCRIPT_DIR / "logs" / "quick-optimization.log"


def main():
    (SCRIPT_DIR / "logs").mkdir(exist_ok=True)
    errors = [0]

    def log_error(msg):
        errors[0] += 1
        try:
            with open(LOG_FILE, "a", encoding="utf-8") as fh:
                fh.write(time.strftime("[%Y-%m-%d %H:%M:%S] ")
                         + f"ERROR: {msg}\n")
        except OSError:
            pass
        print(f"ERROR: {msg}")

    print("\n" + "=" * 60)
    print("[INFO] Running in standard mode without Administrator"
          " privileges")
    print("[INFO] Some system-level features may be limited")
    print("                    01-Quick-Optimization.bat")
    print("=" * 60)
    print("Error handling: ENABLED")
    print(f"Log file: {LOG_FILE}\n")

    target = SCRIPT_DIR / "dev-optimizer-fixed.ps1"
    if not target.exists():
        log_error(f"PowerShell script not found: {target}")
        print("ERROR: Required PowerShell script not found!")
        print("Please ensure dev-optimizer-fixed.ps1 is in the"
              " same directory.")
        if sys.stdin.isatty():
            input("Press Enter to exit...")
        return 1

    print("Running PowerShell optimization script...")
    r = subprocess.run(
        ["powershell", "-ExecutionPolicy", "Bypass", "-Command",
         "& {Set-ExecutionPolicy Bypass -Scope Process -Force;"
         f" & '{target}' -Mode 'Basic' -NoPause}}"])
    if r.returncode != 0:
        log_error("PowerShell optimization script")

    if errors[0]:
        print(f"\nWARNING: {errors[0]} error(s) occurred."
              f" Check log: {LOG_FILE}\n")
        if sys.stdin.isatty():
            input("Press Enter to exit...")
        return errors[0]
    print("\nSUCCESS: Quick optimization completed without"
          " errors.\n")
    if sys.stdin.isatty():
        input("Press Enter to exit...")
    return 0


if __name__ == "__main__":
    sys.exit(main())
