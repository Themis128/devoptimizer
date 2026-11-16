"""Port of portable/onedrive-repair.bat.bat — shim to pwsh:
DEVOPT_HOME (default D:\DevOptimizer) -> scripts\onedrive-repair.ps1
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: shim, launcher

DEVOPT_HOME = Path(os.environ.get("DEVOPT_HOME", r"D:\DevOptimizer"))
TARGET_REL = r"scripts\onedrive-repair.ps1"


def resolve():
    for cand in (DEVOPT_HOME / TARGET_REL,
                 DEVOPT_HOME / "portable" / TARGET_REL,
                 Path(__file__).resolve().parent.parent / TARGET_REL):
        if cand.exists():
            return cand
    return DEVOPT_HOME / TARGET_REL


def main():
    dry = "--dry-run" in sys.argv
    extra = [a for a in sys.argv[1:] if a != "--dry-run"]
    pwsh = shutil.which("pwsh") or shutil.which("powershell")         or "powershell"
    cmd = [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass",
           "-File", str(resolve()), *extra]
    if dry:
        print("[dry-run]", " ".join(cmd))
        return 0
    cwd = DEVOPT_HOME / "portable"
    if not cwd.is_dir():
        cwd = Path(__file__).resolve().parent
    return subprocess.run(cmd, cwd=str(cwd)).returncode


if __name__ == "__main__":
    sys.exit(main())
