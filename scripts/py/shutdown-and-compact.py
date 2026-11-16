"""Shut down WSL and compact its ext4.vhdx (Python port of shutdown-and-compact.ps1).

Runs `wsl --shutdown`, waits, then Optimize-VHD -Mode Full on the Ubuntu
ext4.vhdx. Mutating and requires admin — use --dry-run to preview.
"""

import argparse
import asyncio
import sys
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command  # noqa: E402
from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: wsl, vhdx, compaction, admin

VHDX_PATH = (r"C:\Users\tbaltzakis\AppData\Local\wsl"
             r"\{12c19879-cec8-4dd1-9fe4-7049940b6a2f}\ext4.vhdx")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Report actions without applying them")
    parser.add_argument("--vhdx", default=VHDX_PATH, help="VHDX path to compact")
    args = parser.parse_args()

    if args.dry_run:
        print(f"[dry-run] would run 'wsl --shutdown', wait 3s, then "
              f"Optimize-VHD -Mode Full on {args.vhdx}")
        return

    print("=== Shutting down WSL ===")
    asyncio.run(run_command(["wsl", "--shutdown"], timeout=60))
    time.sleep(3)

    print(f"=== Compacting {args.vhdx} ===")
    vhdx = args.vhdx.replace("'", "''")
    result = asyncio.run(run_ps_command_elevated(
        f"Optimize-VHD -Path '{vhdx}' -Mode Full", timeout=1800))
    if result.returncode != 0:
        print(result.stderr.strip() or "Optimize-VHD failed", file=sys.stderr)
        sys.exit(result.returncode)
    print("Done!")


if __name__ == "__main__":
    main()
