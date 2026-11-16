"""Port of portable/config-loader.bat - portable launcher shim.

Resolves DEVOPT_HOME (default D:\DevOptimizer), locates the
PowerShell target, and runs it with pwsh (falls back to
powershell), forwarding all arguments - same as the .bat.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

DEVOPT_HOME = Path(os.environ.get("DEVOPT_HOME",
                                  "D:/DevOptimizer"))
TARGET_PS1 = DEVOPT_HOME / "modules" / "config-loader.ps1"


def main():
    if not TARGET_PS1.exists():
        print(f"[ERROR] PowerShell script not found: "
              f"{TARGET_PS1}")
        return 1
    ps = shutil.which("powershell") or shutil.which(
        "pwsh")
    if not ps:
        print("[ERROR] no PowerShell host found")
        return 1
    r = subprocess.run(
        [ps, "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-File", str(TARGET_PS1), *sys.argv[1:]])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
