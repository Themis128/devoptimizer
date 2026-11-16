"""Port of portable/advanced-script-updater.bat — pwsh/powershell shim for
"advanced-script-updater.ps1" (relative to DEVOPT_HOME, default D:\DevOptimizer).
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path


def main():
    devopt = Path(os.environ.get("DEVOPT_HOME",
                                 "D:" + chr(92) + "DevOptimizer"))
    target = devopt / "advanced-script-updater.ps1"
    if not target.exists():
        print(f"[ERROR] PowerShell script not found: {target}",
              file=sys.stderr)
        return 1
    try:
        needs7 = any(t in PS1.read_text(
            encoding="utf-8", errors="replace")
            for t in ("-AsHashtable", "??", ".Where("))
    except OSError:
        needs7 = False
    order = ("pwsh", "powershell") if needs7 \
        else ("powershell", "pwsh")
    ps = next((shutil.which(h) for h in order
               if shutil.which(h)), None)
    r = subprocess.run([ps, "-NoProfile", "-ExecutionPolicy",
                        "Bypass", "-File", str(target)]
                       + sys.argv[1:])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
