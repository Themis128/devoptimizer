"""Scheduled wrapper for elevated admin cleanup (port of
scripts/win11-admin-cleanup-scheduled.ps1).

Runs win11-admin-cleanup-elevated-fixed.ps1 then the gated VHDX
compaction step, logging to logs\\win11-admin-cleanup-<date>.log.
Elevated; --dry-run.
"""

import argparse
import asyncio
import datetime
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: cleanup
# TAGS: cleanup, elevated, scheduled

LOG_DIR = r"D:\DevOptimizer\logs"


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    log = (Path(LOG_DIR) /
           f"win11-admin-cleanup-{datetime.date.today():%Y%m%d}.log")
    ps = (
        f"Start-Transcript -Path '{log}' -Force | Out-Null; try {{ "
        "& 'D:\\DevOptimizer\\scripts\\win11-admin-cleanup-elevated-fixed.ps1'; "
        "& 'D:\\DevOptimizer\\scripts\\Invoke-VhdxCompaction.ps1' "
        "-AsLibrary } finally { Stop-Transcript | Out-Null }")
    if args.dry_run:
        print("[dry-run] " + ps)
        return
    # DISM repair can take 10-30 min — cap at 1h like the task itself.
    r = asyncio.run(run_ps_command(ps, timeout=3600))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip() or "cleanup failed — run elevated",
              file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
