"""Compact WSL vhdx (port of scripts/compact-wsl.ps1).

Optimize-VHD -Mode Full on the Ubuntu-24.04 ext4.vhdx. Mutating;
--dry-run; elevation required (Hyper-V cmdlets).
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: wsl, vhdx, compact, storage

VHDX = r"\\wsl.localhost\Ubuntu-24.04\ext4.vhdx"


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--path", default=VHDX)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    ps = (f"Optimize-VHD -Path '{args.path}' -Mode Full; "
          "Write-Host 'Done!'")
    if args.dry_run:
        print("[dry-run] " + ps)
        return
    r = asyncio.run(run_ps_command(ps))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip() or "Optimize-VHD failed — needs "
              "elevation + Hyper-V tools", file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
