"""Port of scripts/register-docker-prune-task.ps1 — registers/unregisters DevOptimizer-Docker-Prune (monthly 1st 04:30)
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

TASK = "DevOptimizer-Docker-Prune"
SCRIPT = "D:" + chr(92) + "DevOptimizer" + chr(92) + "scripts" \
    + chr(92) + "devoptimizer-housekeeping.ps1"


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
          + chr(34) + SCRIPT + chr(34) + " -PruneDocker")
    r = subprocess.run(
        ["schtasks.exe", "/Create", "/TN", TASK]
        + "/SC MONTHLY /M * /D 1 /ST 04:30".split() + ["/TR", tr, "/F", "/IT"])
    if r.returncode != 0:
        print("schtasks /Create failed",
              r.returncode, file=sys.stderr)
        return r.returncode
    print("Registered", TASK, "(monthly 1st 04:30)")
    print("Runs:", SCRIPT + " -PruneDocker")
    print("Remove with: scripts/py/register-docker-prune-task.py --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
