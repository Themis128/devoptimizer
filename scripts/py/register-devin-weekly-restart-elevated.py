"""Register Devin-Weekly-Restart via COM (port of register-devin-weekly-restart-elevated.ps1).

Weekly Sunday 03:00 task for restart-devin-weekly.ps1, headless conhost
action. Elevated via Schedule.Service. Mutating.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, devin, restart, com

SCRIPT = r"D:\DevOptimizer\scripts\restart-devin-weekly.ps1"
TASK_NAME = "Devin-Weekly-Restart"
LOG_PATH = r"$env:USERPROFILE\AppData\Local\DevOptimizer\logs\devin-restart.log"


def build_ps(force: bool) -> str:
    return (
        "$ErrorActionPreference = 'Stop'; "
        "$service = New-Object -ComObject 'Schedule.Service'; $service.Connect(); "
        "$rootFolder = $service.GetFolder('\\\\'); "
        "try { $folder = $service.GetFolder('\\DevOptimizer') } "
        "catch { $rootFolder.CreateFolder('DevOptimizer'); "
        "        $folder = $service.GetFolder('\\DevOptimizer') }; "
        + ("try { $folder.DeleteTask('" + TASK_NAME + "', 0) } catch { }; "
           if force else "")
        + "$def = $service.NewTask(0); "
        "$def.RegistrationInfo.Description = 'Weekly Devin Desktop restart'; "
        "$def.Settings.Enabled = $true; "
        "$def.Settings.StartWhenAvailable = $true; "
        "$def.Settings.RunOnlyIfNetworkAvailable = $false; "
        "$def.Settings.ExecutionTimeLimit = 'PT2H'; "
        "$def.Settings.Hidden = $true; "
        "$def.Principal.RunLevel = 1; "
        "$def.Principal.LogonType = 3; "
        "$trigger = $def.Triggers.Create(3); "  # weekly
        "$trigger.DaysOfWeek = 1; "  # Sunday
        "$trigger.StartBoundary = (Get-Date).ToString('yyyy-MM-dd') + 'T03:00:00'; "
        "$trigger.Enabled = $true; "
        "$sh = 'D:\\DevOptimizer\\pwsh\\pwsh.exe'; "
        "if (-not (Test-Path $sh)) { $sh = 'powershell.exe' }; "
        "$action = $def.Actions.Create(0); "
        "$action.Path = 'conhost.exe'; "
        "$action.Arguments = '--headless ' + $sh + ' -NoProfile "
        f"-ExecutionPolicy Bypass -File \"{SCRIPT}\"'; "
        "$action.WorkingDirectory = 'D:\\DevOptimizer\\scripts'; "
        f"$folder.RegisterTaskDefinition('{TASK_NAME}', $def, 6, $null, "
        "$null, 3, $null) | Out-Null; "
        f"Write-Output ('registered; logs at ' + '{LOG_PATH}')"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ps = build_ps(args.force)
    if args.dry_run:
        print(f"[dry-run] would register \\DevOptimizer\\{TASK_NAME} (Sun 03:00):")
        print(ps)
        return

    result = asyncio.run(run_ps_command_elevated(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or result.stdout.strip() or "registration failed",
              file=sys.stderr)
        sys.exit(result.returncode)
    print(result.stdout.strip(), file=sys.stderr)
    print(f"Created/updated \\DevOptimizer\\{TASK_NAME} (Sun 03:00, headless)",
          file=sys.stderr)


if __name__ == "__main__":
    main()
