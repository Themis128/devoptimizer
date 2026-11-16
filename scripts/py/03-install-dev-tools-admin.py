"""Port of tools/Variants/03-Install-Dev-Tools-Admin.bat - cmd-delegate.

The original is a self-contained batch script (menus /
chained commands, no single ps1 target), so the port
runs it through cmd.exe with all arguments forwarded -
same treatment as the pwsh-delegate ports for
module-bound ps1 files. Original stays alongside for
review.
"""
# REQUIRES: admin

import subprocess
import sys
from pathlib import Path

BAT = Path(r"D:/DevOptimizer/tools/Variants/03-Install-Dev-Tools-Admin.bat")


def main():
    if not BAT.exists():
        print(f"[ERROR] not found: {BAT}")
        return 1
    flags = getattr(subprocess, "CREATE_NEW_CONSOLE", 0)
    r = subprocess.run(["cmd.exe", "/c", str(BAT),
                        *sys.argv[1:]],
                       creationflags=flags)
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
