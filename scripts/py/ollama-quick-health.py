"""Port of portable/ollama-quick-health.bat — pwsh/powershell shim for
Path("tests") / "ollama-quick-health.ps1" (relative to DEVOPT_HOME, default D:\DevOptimizer).
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path


def main():
    devopt = Path(os.environ.get("DEVOPT_HOME",
                                 "D:" + chr(92) + "DevOptimizer"))
    target = devopt / Path("tests") / "ollama-quick-health.ps1"
    if not target.exists():
        print(f"[ERROR] PowerShell script not found: {target}",
              file=sys.stderr)
        return 1
    ps = shutil.which("pwsh") or shutil.which("powershell")
    r = subprocess.run([ps, "-NoProfile", "-ExecutionPolicy",
                        "Bypass", "-File", str(target)]
                       + sys.argv[1:])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
