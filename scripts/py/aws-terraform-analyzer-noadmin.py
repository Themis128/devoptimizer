"""Port of tools/Variants/AWS-TERRAFORM-ANALYZER-NoAdmin.bat - cmd-delegate.

The original is a self-contained batch script (menus /
chained commands, no single ps1 target), so the port
runs it through cmd.exe with all arguments forwarded -
same treatment as the pwsh-delegate ports for
module-bound ps1 files. Original stays alongside for
review.
"""

import subprocess
import sys
from pathlib import Path

BAT = Path(r"D:/DevOptimizer/tools/Variants/AWS-TERRAFORM-ANALYZER-NoAdmin.bat")


def main():
    if not BAT.exists():
        print(f"[ERROR] not found: {BAT}")
        return 1
    r = subprocess.run(["cmd.exe", "/c", str(BAT),
                        *sys.argv[1:]])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
