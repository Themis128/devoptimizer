"""One-click elevation for 2026-10-27 trigger fixes
(port of apply-trigger-fixes-20261027.bat).

RunAs-elevates logs\\trigger-fixes-20261027.ps1:
  1) Devin-Session-Manager: 4h repetition made INDEFINITE
  2) WSL-Ubuntu-Cleanup: 02:30 -> 02:20 (de-collide with weekly restart)
Mutating; --dry-run.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, elevated, fix

SCRIPT = r"D:\DevOptimizer\logs\trigger-fixes-20261027.ps1"
LOG = r"D:\DevOptimizer\logs\trigger-fixes-20261027.log"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ps = ("Start-Process powershell -Verb RunAs -Wait "
          f"-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','{SCRIPT}'")
    if args.dry_run:
        print(f"[dry-run] elevate + run {SCRIPT}")
        return

    r = asyncio.run(run_ps_command(ps))
    if r.returncode != 0:
        print(r.stderr.strip() or "elevation failed", file=sys.stderr)
        sys.exit(r.returncode)
    print(f"Done. Log: {LOG}")


if __name__ == "__main__":
    main()
