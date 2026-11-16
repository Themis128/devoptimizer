"""Register Devin-Raise-Priority task via COM (port of register-devin-priority-task.ps1).

Logon + daily 30-min repeat triggers, interactive-token principal,
headless conhost action. Elevated. Mutating.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, devin, priority, com

SCRIPT = r"D:\DevOptimizer\scripts\raise-devin-priority.ps1"
TASK_NAME = "Devin-Raise-Priority"


def build_ps(force: bool) -> str:
    return (
        "$ErrorActionPreference = 'Stop'; "
        "$service = New-Object -ComObject 'Schedule.Service'; $service.Connect(); "
        "$rootFolder = $service.GetFolder('\\'); "
        "try { $folder = $service.GetFolder('\\DevOptimizer') } "
        "catch { $rootFolder.CreateFolder('DevOptimizer'); "
        "        $folder = $service.GetFolder('\\DevOptimizer') }; "
        + ("try { $folder.DeleteTask('" + TASK_NAME + "', 0) } catch { }; "
           if force else "")
        + "$def = $service.NewTask(0); "
        "$def.RegistrationInfo.Description = "
        "'Raise Devin Desktop process priority to High'; "
        "$def.Settings.Enabled = $true; "
        "$def.Settings.AllowDemandStart = $true; "
        "$def.Settings.StartWhenAvailable = $true; "
        "$def.Settings.ExecutionTimeLimit = 'PT5M'; "
        "$def.Settings.DisallowStartIfOnBatteries = $false; "
        "$def.Settings.StopIfGoingOnBatteries = $false; "
        "$def.Settings.Hidden = $true; "
        "$def.Principal.RunLevel = 1; "
        "$def.Principal.LogonType = 5; "  # InteractiveToken
        "$t1 = $def.Triggers.Create(9); $t1.Enabled = $true; "
        "$t1.UserId = $env:USERNAME; "
        "$t2 = $def.Triggers.Create(2); "
        "$t2.StartBoundary = (Get-Date).ToString('yyyy-MM-dd') + 'T00:00:00'; "
        "$t2.Repetition.Interval = 'PT30M'; "
        "$t2.Repetition.Duration = 'P1D'; "
        "$t2.Repetition.StopAtDurationEnd = $false; "
        "$t2.Enabled = $true; "
        "$sh = 'D:\\DevOptimizer\\pwsh\\pwsh.exe'; "
        "if (-not (Test-Path $sh)) { $sh = 'powershell.exe' }; "
        "$action = $def.Actions.Create(0); "
        "$action.Path = 'conhost.exe'; "
        "$action.Arguments = '--headless ' + $sh + ' -NoProfile "
        f"-ExecutionPolicy Bypass -File \"{SCRIPT}\" -Loop -Interval 30'; "
        "$action.WorkingDirectory = 'D:\\DevOptimizer\\scripts'; "
        f"$folder.RegisterTaskDefinition('{TASK_NAME}', $def, 6, $null, "
        "$null, 5, $null) | Out-Null; "
        "Write-Output 'registered'"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ps = build_ps(args.force)
    if args.dry_run:
        print(f"[dry-run] would register \\DevOptimizer\\{TASK_NAME} (30-min loop):")
        print(ps)
        return

    result = asyncio.run(run_ps_command_elevated(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or result.stdout.strip() or "registration failed",
              file=sys.stderr)
        sys.exit(result.returncode)
    print(f"Created/updated \\DevOptimizer\\{TASK_NAME} "
          "(logon + 30-min repeat, headless)", file=sys.stderr)


if __name__ == "__main__":
    main()
