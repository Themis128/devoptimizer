"""Create Win11AdminCleanup task (port of
scripts/create-admin-cleanup-task.ps1).

One-shot SYSTEM task firing ~1 minute after registration, running
admin-cleanup-elevated.ps1 via conhost --headless (repo rule).
Mutating; --dry-run; requires elevation.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, cleanup, system, elevated

SCRIPT = r"D:\DevOptimizer\scripts\admin-cleanup-elevated.ps1"

PS_BODY = (
    "$ErrorActionPreference = 'Stop'; "
    "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
    f"-Argument ('--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"{SCRIPT}\"'); "
    "$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1); "
    "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' "
    "-LogonType ServiceAccount -RunLevel Highest; "
    "Register-ScheduledTask -TaskName 'Win11AdminCleanup' "
    "-Action $action -Trigger $trigger -Principal $principal -Force; "
    "Write-Host 'Scheduled task Win11AdminCleanup created (runs in ~1 min)'")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    if args.dry_run:
        print("[dry-run] " + PS_BODY)
        return
    r = asyncio.run(run_ps_command(PS_BODY))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip() or "registration failed — run elevated",
              file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
