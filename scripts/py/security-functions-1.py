"""Port of portable/security-functions.bat: DEVOPT_HOME shim for scripts\security-functions.ps1."""
import os
import shutil
import subprocess
import sys
from pathlib import Path

home = os.environ.get("DEVOPT_HOME", r"D:\DevOptimizer")
target = os.path.join(home, r"scripts\security-functions.ps1")
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
