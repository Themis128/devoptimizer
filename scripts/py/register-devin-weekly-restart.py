"""Register the weekly Devin-Restart task (Python port of register-devin-weekly-restart.ps1).

Weekly Sunday 03:00 task running restart-devin-weekly.ps1 under a headless
conhost action. Mutating.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, devin, restart


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true",
                        help="Update the task if it already exists")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    task_name = "Devin-Weekly-Restart"
    task_path = "\\DevOptimizer\\"
    script = r"D:\DevOptimizer\scripts\restart-devin-weekly.ps1"
    log_path = r"$env:USERPROFILE\AppData\Local\DevOptimizer\logs\devin-restart.log"

    guard = "" if args.force else "if ($existing) { Write-Error 'exists'; exit 2 }; "
    ps = (
        "$ErrorActionPreference = 'Stop'; "
        f"if (-not (Test-Path '{script}')) {{ Write-Error 'script missing'; exit 1 }}; "
        f"$existing = Get-ScheduledTask -TaskName '{task_name}' -TaskPath '{task_path}' "
        "-ErrorAction SilentlyContinue; "
        f"{guard}"
        # headless action (rewrapper skips conhost actions)
        "$sh = 'D:\\DevOptimizer\\pwsh\\pwsh.exe'; "
        "if (-not (Test-Path $sh)) { $sh = 'powershell.exe' }; "
        "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
        f"-Argument ('--headless ' + $sh + ' -NoProfile -ExecutionPolicy Bypass -File \"{script}\"') "
        f"-WorkingDirectory 'D:\\DevOptimizer\\scripts'; "
        "$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 03:00; "
        "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -StartWhenAvailable "
        "-RunOnlyIfNetworkAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 2) "
        "-RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5); "
        "$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME "
        "-LogonType Password -RunLevel Highest; "
        f"Register-ScheduledTask -TaskName '{task_name}' -TaskPath '{task_path}' "
        "-Action $action -Trigger $trigger -Settings $settings "
        "-Principal $principal -Force | Out-Null; "
        f"Write-Output ('registered; logs at ' + '{log_path}')"
    )

    if args.dry_run:
        print(f"[dry-run] would register {task_path}{task_name} (Sun 03:00):")
        print(ps)
        return

    result = asyncio.run(run_ps_command(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or result.stdout.strip() or "registration failed",
              file=sys.stderr)
        sys.exit(result.returncode)
    print(f"Created/updated {task_path}{task_name} (Sun 03:00, headless)", file=sys.stderr)
    print(result.stdout.strip())


if __name__ == "__main__":
    main()
