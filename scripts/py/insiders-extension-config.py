"""PS1 shim wrapper (Python port of portable/insiders-extension-config.bat).

Resolves DEVOPT_HOME (default D:\DevOptimizer), prefers pwsh over
powershell, forwards all CLI args to the target .ps1.
"""

import os
import shutil
import subprocess
import sys

NAME = "insiders-extension-config"


def main() -> int:
    home = os.environ.get("DEVOPT_HOME", r"D:\DevOptimizer")
    target = os.path.join(home, NAME + ".ps1")
    if not os.path.exists(target):
        print(f"[ERROR] PowerShell script not found: {target}",
              file=sys.stderr)
        return 1
    shell = "pwsh" if shutil.which("pwsh") else "powershell"
    cmd = [shell, "-NoProfile", "-ExecutionPolicy", "Bypass",
           "-File", target, *sys.argv[1:]]
    return subprocess.call(cmd)


if __name__ == "__main__":
    sys.exit(main())
