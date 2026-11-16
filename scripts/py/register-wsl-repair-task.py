"""Port of scripts/register-wsl-repair-task.ps1 — registers/unregisters DevOptimizer-WSL-Repair (every 30 min)
via schtasks.exe with a hidden conhost wrapper.
"""
# REQUIRES: admin
import ctypes

def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required", file=sys.stderr)
        sys.exit(1)

import subprocess
import sys
from pathlib import Path

TASK = "DevOptimizer-WSL-Repair"
SCRIPT = "D:" + chr(92) + "DevOptimizer" + chr(92) + "scripts" \
    + chr(92) + "repair-wsl-docker-integration.ps1"


def main():
    _ensure_admin()
    if "--unregister" in sys.argv:
        subprocess.run(["schtasks.exe", "/Delete", "/TN", TASK,
                        "/F"], capture_output=True)
        print("Unregistered", TASK)
        return 0
    pwsh = "D:" + chr(92) + "DevOptimizer" + chr(92) + "pwsh" \
        + chr(92) + "pwsh.exe"
    if not Path(pwsh).exists():
        pwsh = "pwsh.exe"
    tr = ("C:" + chr(92) * 2 + "Windows" + chr(92) * 2
          + "System32" + chr(92) * 2
          + "conhost.exe --headless " + chr(34) + pwsh
          + chr(34) + " -NoProfile -ExecutionPolicy Bypass -File "
          + chr(34) + SCRIPT + chr(34))
    r = subprocess.run(
        ["schtasks.exe", "/Create", "/TN", TASK]
        + "/SC MINUTE /MO 30".split() + ["/TR", tr, "/F", "/IT"])
    if r.returncode != 0:
        print("schtasks /Create failed",
              r.returncode, file=sys.stderr)
        return r.returncode
    print("Registered", TASK, "(every 30 min)")
    print("Runs:", SCRIPT + "")
    print("Remove with: scripts/py/register-wsl-repair-task.py --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
