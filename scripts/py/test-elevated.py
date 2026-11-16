# REQUIRES: admin
"""Port of scripts/test-elevated.ps1."""
import ctypes
import getpass
import subprocess
import sys


def main():
    try:
        admin = bool(
            ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        admin = False
    print(f"Running elevated: {getpass.getuser()}")
    print(f"IsAdmin: {admin}")
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Get-ScheduledTask -TaskPath "
         "'\\DevOptimizer\\' -ErrorAction "
         "SilentlyContinue | Select-Object TaskName, "
         "State, TaskPath | Format-Table -AutoSize"],
        capture_output=True, text=True)
    print(r.stdout or r.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
