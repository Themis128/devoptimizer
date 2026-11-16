"""Install dev tools, standard mode (port of
tools/Variants/03-Install-Dev-Tools-NoAdmin.bat).

Runs tools/Variants/dev-optimizer-fixed.ps1 -Mode Basic -NoPause.
Mutating; --dry-run.
"""

import argparse
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: install, dev-tools

SCRIPT = (Path(__file__).resolve().parents[2]
          / "tools" / "Variants" / "dev-optimizer-fixed.ps1")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-Command",
           "& {Set-ExecutionPolicy Bypass -Scope Process -Force; "
           f"& '{SCRIPT}' -Mode 'Basic' -NoPause}}"]
    print("Running 03-Install-Dev-Tools (standard mode)...")
    if not SCRIPT.is_file() and not args.dry_run:
        print(f"ERROR: installer script not found: {SCRIPT}",
              file=sys.stderr)
        sys.exit(1)
    if args.dry_run:
        print("[dry-run] " + " ".join(cmd))
        return

    r = subprocess.run(cmd)
    if r.returncode != 0:
        print("ERROR: Operation failed — make sure you are running as "
              "Administrator.", file=sys.stderr)
        sys.exit(1)
    print("Operation completed successfully")


if __name__ == "__main__":
    main()
