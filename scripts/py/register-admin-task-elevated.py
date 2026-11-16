"""Register the weekly Admin-Cleanup-System task (Python port of register-admin-task-elevated.ps1).

Registers \\DevOptimizer\\Admin-Cleanup-System: admin-cleanup-system.ps1,
Sundays 03:00, SYSTEM account, highest run level. Mutating, requires admin.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, cleanup, admin

TASK_NAME = "Admin-Cleanup-System"
TASK_PATH = "\\DevOptimizer\\"
SCRIPT = r"D:\DevOptimizer\scripts\admin-cleanup-system.ps1"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the Register-ScheduledTask script without running it")
    args = parser.parse_args()

    ps = (
        f"$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "
        f"'-NoProfile -ExecutionPolicy Bypass -File \"{SCRIPT}\"'; "
        "$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 03:00; "
        "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8; "
        "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' "
        "-LogonType ServiceAccount -RunLevel Highest; "
        f"Register-ScheduledTask -TaskName '{TASK_NAME}' -TaskPath '{TASK_PATH}' "
        "-Action $action -Trigger $trigger -Settings $settings "
        "-Principal $principal -Force"
    )

    if args.dry_run:
        print(f"[dry-run] would register task '{TASK_PATH}{TASK_NAME}':")
        print(ps)
        return

    result = asyncio.run(run_ps_command_elevated(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or "Register-ScheduledTask failed", file=sys.stderr)
        sys.exit(result.returncode)
    print("Registered Admin-Cleanup-System task (SYSTEM account)")


if __name__ == "__main__":
    main()
