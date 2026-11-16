"""Register Admin-Cleanup-System task (port of create-admin-system-task.bat).

schtasks /Create \\DevOptimizer\\Admin-Cleanup-System, weekly SUN 03:00,
SYSTEM/HIGHEST, interactive token. Mutating; --dry-run.
"""

import argparse
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: scheduled-task, cleanup, system

TASK = r"\DevOptimizer\Admin-Cleanup-System"
TR = ('pwsh.exe -NoProfile -ExecutionPolicy Bypass -File '
      '"D:\\DevOptimizer\\scripts\\admin-cleanup-system.ps1"')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    cmd = ["schtasks", "/Create", "/TN", TASK, "/TR", TR,
           "/SC", "WEEKLY", "/D", "SUN", "/ST", "03:00",
           "/RU", "SYSTEM", "/RL", "HIGHEST", "/F", "/IT"]
    if args.dry_run:
        print("[dry-run] " + " ".join(cmd))
        return

    r = subprocess.run(cmd, capture_output=True, text=True)
    print(r.stdout.strip() or r.stderr.strip() or f"rc={r.returncode}")
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
