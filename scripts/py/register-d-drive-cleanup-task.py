"""Register D-Drive-Cleanup task (port of
scripts/register-d-drive-cleanup-task.ps1).

Daily 02:30 SYSTEM task, 2h limit, 3x restart @10m, Priority 7 —
runs Clean-DDrive.ps1 -MonthsInactive 2 -Force under conhost
--headless (repo rule). Mutating; --dry-run; requires elevation.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, cleanup, d-drive, elevated

SCRIPT = r"D:\DevOptimizer\scripts\Clean-DDrive.ps1"

PS_BODY = (
    "$ErrorActionPreference = 'Stop'; "
    "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
    f"-Argument ('--headless pwsh.exe -NoProfile -File \"{SCRIPT}\" -MonthsInactive 2 -Force'); "
    "$trigger = New-ScheduledTaskTrigger -Daily -At 02:30; "
    "$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable "
    "-DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Hours 2) "
    "-RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 10) "
    "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Priority 7; "
    "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' "
    "-LogonType ServiceAccount -RunLevel Highest; "
    "Register-ScheduledTask -TaskName 'DevOptimizer\\D-Drive-Cleanup' "
    "-Action $action -Trigger $trigger -Settings $settings "
    "-Principal $principal -Force; "
    "Write-Host 'Task registered (SYSTEM, daily 02:30)'")


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
