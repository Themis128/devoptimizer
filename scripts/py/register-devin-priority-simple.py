"""Register Devin-Raise-Priority task (port of register-devin-priority-simple.ps1).

At-startup task running raise-devin-priority.ps1 as SYSTEM, headless
conhost action. Requires elevation. Mutating.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, devin, priority


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    task_name = "Devin-Raise-Priority"
    task_path = "\\DevOptimizer\\"
    script = r"D:\DevOptimizer\scripts\raise-devin-priority.ps1"

    guard = "" if args.force else "if ($existing) { Write-Output 'exists - use --force to update'; exit 0 }; "
    ps = (
        "$ErrorActionPreference = 'Stop'; "
        f"if (-not (Test-Path '{script}')) {{ Write-Error 'script missing'; exit 1 }}; "
        f"$existing = Get-ScheduledTask -TaskName '{task_name}' -TaskPath '{task_path}' "
        "-ErrorAction SilentlyContinue; "
        f"{guard}"
        "$sh = 'D:\\DevOptimizer\\pwsh\\pwsh.exe'; "
        "if (-not (Test-Path $sh)) { $sh = 'powershell.exe' }; "
        "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
        f"-Argument ('--headless ' + $sh + ' -NoProfile -ExecutionPolicy Bypass -File \"{script}\" -Loop -Interval 30') "
        f"-WorkingDirectory 'D:\\DevOptimizer\\scripts'; "
        "$trigger = New-ScheduledTaskTrigger -AtStartup; "
        "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 24) -RestartCount 0; "
        "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' "
        "-LogonType ServiceAccount -RunLevel Highest; "
        f"Register-ScheduledTask -TaskName '{task_name}' -TaskPath '{task_path}' "
        "-Action $action -Trigger $trigger -Settings $settings "
        "-Principal $principal -Force | Out-Null; "
        "Write-Output 'registered'"
    )

    if args.dry_run:
        print(f"[dry-run] would register {task_path}{task_name} (AtStartup SYSTEM):")
        print(ps)
        return

    result = asyncio.run(run_ps_command_elevated(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or result.stdout.strip() or "registration failed",
              file=sys.stderr)
        sys.exit(result.returncode)
    print(f"Created/updated {task_path}{task_name} (AtStartup, SYSTEM, headless)",
          file=sys.stderr)


if __name__ == "__main__":
    main()
