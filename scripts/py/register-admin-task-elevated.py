"""Register Admin-Cleanup-System as SYSTEM task
(port of scripts/register-admin-task-elevated.bat).

Weekly SUN 03:00, SYSTEM/HIGHEST, 72h limit, hidden — action wrapped in
conhost --headless per the repo's headless-action rule. Mutating;
--dry-run.
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

SCRIPT = r"D:\DevOptimizer\scripts\admin-cleanup-system.ps1"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ps = (
        "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
        f"-Argument ('--headless pwsh.exe -NoProfile -ExecutionPolicy Bypass -File \"{SCRIPT}\"'); "
        "$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 03:00; "
        "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8; "
        "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' "
        "-LogonType ServiceAccount -RunLevel Highest; "
        "Register-ScheduledTask -TaskName 'Admin-Cleanup-System' "
        "-TaskPath '\\DevOptimizer\\' -Action $action -Trigger $trigger "
        "-Settings $settings -Principal $principal -Force; "
        "Write-Host 'Registered Admin-Cleanup-System task (SYSTEM account)'"
    )
    if args.dry_run:
        print("[dry-run] " + ps)
        return

    r = asyncio.run(run_ps_command(ps))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip() or "registration failed — run elevated",
              file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
