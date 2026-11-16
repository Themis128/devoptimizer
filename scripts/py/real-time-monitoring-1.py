"""Port of portable/real-time-monitoring.bat: DEVOPT_HOME shim for scripts\real-time-monitoring.ps1."""
import os
import shutil
import subprocess
import sys
from pathlib import Path

home = os.environ.get("DEVOPT_HOME", r"D:\DevOptimizer")
target = os.path.join(home, r"scripts\real-time-monitoring.ps1")
if not os.path.isfile(target):
    print(f"[ERROR] PowerShell script not found: {target}")
    sys.exit(1)
ps = shutil.which("pwsh") or shutil.which("powershell")
if not ps:
    print("[ERROR] Neither pwsh nor powershell found in PATH")
    sys.exit(1)
sys.exit(subprocess.call(
    [ps, "-NoProfile", "-ExecutionPolicy", "Bypass",
     "-File", target] + sys.argv[1:]))
