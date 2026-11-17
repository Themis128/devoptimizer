"""Create Devin-Lower-Priority task via COM (port of create-priority-task-com.ps1).

Schedule.Service COM registration: AtStartup trigger, SYSTEM principal,
BelowNormal-priority loop script, headless conhost action. Elevated.
Mutating.
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


def build_ps(script: str, task_name: str, task_path: str, force: bool) -> str:
    return (
        "$ErrorActionPreference = 'Stop'; "
        "$service = New-Object -ComObject 'Schedule.Service'; $service.Connect(); "
        "$rootFolder = $service.GetFolder('\\'); "
        "try { $folder = $service.GetFolder('\\DevOptimizer') } "
        "catch { $rootFolder.CreateFolder('DevOptimizer'); "
        "        $folder = $service.GetFolder('\\DevOptimizer') }; "
        + ("try { $folder.DeleteTask('" + task_name + "', 0) } catch { }; "
           if force else "")
        + "$def = $service.NewTask(0); "
        "$def.RegistrationInfo.Description = "
        "'Lower Devin Desktop process priority to BelowNormal'; "
        "$def.Settings.Enabled = $true; "
        "$def.Settings.AllowDemandStart = $true; "
        "$def.Settings.StartWhenAvailable = $true; "
        "$def.Settings.ExecutionTimeLimit = 'PT24H'; "
        "$def.Settings.DisallowStartIfOnBatteries = $false; "
        "$def.Settings.StopIfGoingOnBatteries = $false; "
        "$def.Settings.Hidden = $true; "
        "$def.Principal.RunLevel = 1; "
        "$def.Principal.LogonType = 3; "
        "$def.Principal.UserId = 'SYSTEM'; "
        "$trigger = $def.Triggers.Create(8); $trigger.Enabled = $true; "
        # headless action (rewrapper skips conhost actions)
        "$sh = 'D:\\DevOptimizer\\pwsh\\pwsh.exe'; "
        "if (-not (Test-Path $sh)) { $sh = 'powershell.exe' }; "
        "$action = $def.Actions.Create(0); "
        "$action.Path = 'conhost.exe'; "
        "$action.Arguments = '--headless ' + $sh + ' -NoProfile "
        f"-ExecutionPolicy Bypass -File \"{script}\" -Loop -Interval 30'; "
        "$action.WorkingDirectory = 'D:\\DevOptimizer\\scripts'; "
        f"$folder.RegisterTaskDefinition('{task_name}', $def, 6, 'SYSTEM', "
        "$null, 3, $null) | Out-Null; "
        f"Write-Output 'registered {task_path}{task_name}'"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    task_name = "Devin-Lower-Priority"
    task_path = "\\DevOptimizer\\"
    script = r"D:\DevOptimizer\scripts\lower-devin-priority.ps1"

    if not args.dry_run:
        probe = asyncio.run(run_ps_command_elevated(
            f"if (-not (Test-Path '{script}')) {{ exit 1 }}"))
        if probe.returncode != 0:
            print(f"Script not found: {script}", file=sys.stderr)
            sys.exit(1)

    ps = build_ps(script, task_name, task_path, args.force)
    if args.dry_run:
        print(f"[dry-run] would register {task_path}{task_name} via COM:")
        print(ps)
        return

    result = asyncio.run(run_ps_command_elevated(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or result.stdout.strip() or "registration failed",
              file=sys.stderr)
        sys.exit(result.returncode)
    print(f"Created/updated {task_path}{task_name} (SYSTEM, AtStartup, headless)",
          file=sys.stderr)


if __name__ == "__main__":
    main()
