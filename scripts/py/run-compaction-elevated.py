"""Launch compact-wsl-vhdx.ps1 elevated (port of run-compaction-elevated.bat).

Start-Process powershell -Verb RunAs -File compact-wsl-vhdx.ps1 -ForceAll
-Force -Wait. Mutating (elevated compaction); --dry-run.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: vhdx, compaction, elevated

SCRIPT = r"D:\DevOptimizer\scripts\compact-wsl-vhdx.ps1"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ps = (
        "Start-Process powershell -Verb RunAs -Wait -ArgumentList "
        f"'-File {SCRIPT} -ForceAll -Force'"
    )
    if args.dry_run:
        print(f"[dry-run] elevate + run {SCRIPT} -ForceAll -Force")
        return

    r = asyncio.run(run_ps_command(ps))
    if r.returncode != 0:
        print(r.stderr.strip() or "elevation failed", file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
