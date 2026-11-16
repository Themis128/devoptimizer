"""Register the Devin lower-priority task (Python port of create-priority-task.ps1).

Registers \\DevOptimizer\\Devin-Lower-Priority to run
lower-devin-priority.ps1 -Loop -Interval 30 at startup as SYSTEM.
Mutating, requires admin.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, devin, admin

TASK_NAME = "Devin-Lower-Priority"
TASK_PATH = "\\DevOptimizer\\"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the Register-ScheduledTask script without running it")
    args = parser.parse_args()

    ps = (
        "$action = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "
        "'--headless powershell.exe -NoProfile -ExecutionPolicy Bypass "
        "-File \"D:\\DevOptimizer\\scripts\\lower-devin-priority.ps1\" "
        "-Loop -Interval 30'; "
        "$trigger = New-ScheduledTaskTrigger -AtStartup; "
        "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 24); "
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
    print("Task created")


if __name__ == "__main__":
    main()
