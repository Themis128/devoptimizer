"""Create Devin-Lower-Priority task via the registration ps1
(port of create-priority-task-admin.bat).

Runs create-priority-task.ps1 (needs admin). Mutating; --dry-run.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, devin, elevated

SCRIPT = r"D:\DevOptimizer\scripts\create-priority-task.ps1"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    print("Creating Devin-Lower-Priority scheduled task...")
    print("This requires Administrator privileges.")
    if args.dry_run:
        print(f"[dry-run] run {SCRIPT}")
        return

    r = asyncio.run(run_ps_command(f"& '{SCRIPT}'"))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip()
              or "task not created — run as Administrator",
              file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
