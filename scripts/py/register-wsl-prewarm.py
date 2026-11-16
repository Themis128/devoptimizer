"""Register WSL-PreWarm task (port of
scripts/devin/Register-WSL-PreWarm.ps1).

At-logon +15s task warming the Ubuntu-24.04 VM
(`conhost --headless wsl.exe -d Ubuntu-24.04 --exec true` per repo
headless rule). --remove unregisters; --dry-run.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: wsl, scheduled-task, prewarm

TASK_NAME = "WSL-PreWarm"


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--remove", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.remove:
        ps = ("Unregister-ScheduledTask -TaskPath '\\DevOptimizer\\' "
              f"-TaskName '{TASK_NAME}' -Confirm:$false "
              "-ErrorAction SilentlyContinue; "
              f"Write-Host 'Removed \\DevOptimizer\\{TASK_NAME}'")
    else:
        ps = (
            "$ErrorActionPreference = 'Stop'; "
            "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
            "-Argument '--headless wsl.exe -d Ubuntu-24.04 --exec true'; "
            "$trigger = New-ScheduledTaskTrigger -AtLogOn -User "
            "'$env:USERDOMAIN\\$env:USERNAME'; "
            "$trigger.Delay = 'PT15S'; "
            "$settings = New-ScheduledTaskSettingsSet "
            "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
            "-ExecutionTimeLimit (New-TimeSpan -Minutes 2) "
            "-MultipleInstances IgnoreNew; "
            "$principal = New-ScheduledTaskPrincipal -UserId "
            "'$env:USERDOMAIN\\$env:USERNAME' -LogonType Interactive; "
            "Register-ScheduledTask -TaskPath '\\DevOptimizer\\' "
            f"-TaskName '{TASK_NAME}' -Action $action "
            "-Trigger $trigger -Settings $settings "
            "-Principal $principal -Force; "
            f"Write-Host 'Registered \\DevOptimizer\\{TASK_NAME}'")
    if args.dry_run:
        print("[dry-run] " + ps)
        return
    r = asyncio.run(run_ps_command(ps))
    if r.stdout.strip():
        print(r.stdout.strip())
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
