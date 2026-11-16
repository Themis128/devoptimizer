"""PS1 shim wrapper (Python port of portable/check-locked-files.bat).

Resolves DEVOPT_HOME (default D:\DevOptimizer), prefers pwsh over
powershell, forwards all CLI args to the target .ps1.
"""

import argparse
import os
import shutil
import subprocess
import sys

# CATEGORY: utilities
# TAGS: shim, wrapper

TARGET_PS1 = r"D:\DevOptimizer\check-locked-files.ps1"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args, rest = parser.parse_known_args()

    home = os.environ.get("DEVOPT_HOME", r"D:\DevOptimizer")
    target = TARGET_PS1.replace("D:\DevOptimizer", home)
    if not os.path.exists(target):
        print(f"[ERROR] PowerShell script not found: {D:\DevOptimizer\check-locked-files.ps1}",
              file=sys.stderr)
        sys.exit(1)
    shell = "pwsh" if shutil.which("pwsh") else "powershell"
    cmd = [shell, "-NoProfile", "-ExecutionPolicy", "Bypass",
           "-File", target, *rest]
    if args.dry_run:
        print("[dry-run] " + " ".join(cmd))
        return
    sys.exit(subprocess.call(cmd))


if __name__ == "__main__":
    main()
