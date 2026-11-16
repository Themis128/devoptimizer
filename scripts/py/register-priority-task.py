"""Register Devin-Lower-Priority task (port of register-priority-task.bat).

schtasks Devin-Lower-Priority ONSTART, SYSTEM/HIGHEST, runs
lower-devin-priority.ps1 -Loop -Interval 30. Mutating; --dry-run.
"""

import argparse
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: scheduled-task, devin, priority

TASK = "Devin-Lower-Priority"
TR = ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File '
      '"D:\\DevOptimizer\\scripts\\lower-devin-priority.ps1" '
      '-Loop -Interval 30')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    cmd = ["schtasks", "/create", "/tn", TASK, "/tr", TR,
           "/sc", "ONSTART", "/ru", "SYSTEM", "/rl", "HIGHEST", "/f"]
    if args.dry_run:
        print("[dry-run] " + " ".join(cmd))
        return

    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode == 0:
        print("Task created successfully")
    else:
        print("Failed to create task")
        print(r.stderr.strip() or r.stdout.strip(), file=sys.stderr)
    sys.exit(0 if r.returncode == 0 else 1)


if __name__ == "__main__":
    main()
