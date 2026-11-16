"""Register the DD-Settings-Watchdog task (Python port of register-dd-watchdog.ps1).

Registers \\DevOptimizer\\DD-Settings-Watchdog: dd-settings-watchdog.ps1 at
logon plus every 5 minutes for 3650 days, interactive user, highest run
level. Mutating, requires admin.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, docker, watchdog, admin

TASK_NAME = "DD-Settings-Watchdog"
TASK_PATH = "\\DevOptimizer\\"
SCRIPT = r"D:\DevOptimizer\scripts\dd-settings-watchdog.ps1"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the Register-ScheduledTask script without running it")
    args = parser.parse_args()

    ps = (
        # conhost wraps the portable pwsh directly — the Store pwsh.exe stub
        # is broken and the headless rewrapper skips conhost actions.
        f"$action = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "
        f"'--headless \"D:\\DevOptimizer\\pwsh\\pwsh.exe\" -NoProfile "
        f"-ExecutionPolicy Bypass -File \"{SCRIPT}\"'; "
        "$trigger1 = New-ScheduledTaskTrigger -AtLogOn; "
        "$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) "
        "-RepetitionInterval (New-TimeSpan -Minutes 5) "
        "-RepetitionDuration (New-TimeSpan -Days 3650); "
        "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8; "
        "$principal = New-ScheduledTaskPrincipal -UserId "
        "(Get-CimInstance Win32_ComputerSystem).UserName -LogonType Interactive "
        "-RunLevel Highest; "
        f"Register-ScheduledTask -TaskName '{TASK_NAME}' -TaskPath '{TASK_PATH}' "
        "-Action $action -Trigger $trigger1,$trigger2 -Settings $settings "
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
    print("Registered DD-Settings-Watchdog task")


if __name__ == "__main__":
    main()
