"""Port of scripts/ADVANCED-DIAGNOSTICS.ps1.

Delegates to the PowerShell original via pwsh ->
powershell -File: interactive diagnostics menu driving DISM/sfc/WMI collectors
All arguments forwarded; exit code preserved.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

PS1 = Path(r"D:\DevOptimizer\scripts\ADVANCED-DIAGNOSTICS.ps1")


def main():
    if not PS1.exists():
        print(f"[ERROR] not found: {PS1}")
        return 1
    ps = shutil.which("pwsh") or shutil.which(
        "powershell")
    if not ps:
        print("[ERROR] no PowerShell host")
        return 1
    r = subprocess.run(
        [ps, "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-File", str(PS1), *sys.argv[1:]])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
