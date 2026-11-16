"""Register Devin-Session-Manager task (port of register-devin-session-manager.ps1).

Every-4-hours task (starting 00:15) running manage-devin-sessions.ps1
in -WhatIf safety mode, headless conhost action. Elevated. Mutating.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, devin, sessions

SCRIPT = r"D:\DevOptimizer\scripts\manage-devin-sessions.ps1"
TASK_NAME = "Devin-Session-Manager"
TASK_PATH = "\\DevOptimizer\\"
LOG_PATH = r"D:\DevOptimizer\logs\devin-session-manager.log"


def build_ps(force: bool) -> str:
    guard = "" if force else "if ($existing) { Write-Error 'exists'; exit 2 }; "
    return (
        "$ErrorActionPreference = 'Stop'; "
        f"if (-not (Test-Path '{SCRIPT}')) {{ Write-Error 'script missing'; exit 1 }}; "
        f"$existing = Get-ScheduledTask -TaskName '{TASK_NAME}' "
        f"-TaskPath '{TASK_PATH}' -ErrorAction SilentlyContinue; "
        f"{guard}"
        "$sh = 'D:\\DevOptimizer\\pwsh\\pwsh.exe'; "
        "if (-not (Test-Path $sh)) { $sh = 'powershell.exe' }; "
        "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
        f"-Argument ('--headless ' + $sh + ' -NoProfile -ExecutionPolicy Bypass -File \"{SCRIPT}\" -WhatIf') "
        f"-WorkingDirectory 'D:\\DevOptimizer\\scripts'; "
        "$trigger = New-ScheduledTaskTrigger -Once -At 00:15 "
        "-RepetitionInterval (New-TimeSpan -Hours 4) "
        "-RepetitionDuration (New-TimeSpan -Days 3650); "
        "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -StartWhenAvailable "
        "-RunOnlyIfNetworkAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 1) "
        "-RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5); "
        "$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME "
        "-LogonType Password -RunLevel Highest; "
        f"Register-ScheduledTask -TaskName '{TASK_NAME}' -TaskPath '{TASK_PATH}' "
        "-Action $action -Trigger $trigger -Settings $settings "
        "-Principal $principal -Force | Out-Null; "
        "Write-Output 'registered'"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ps = build_ps(args.force)
    if args.dry_run:
        print(f"[dry-run] would register {TASK_PATH}{TASK_NAME} (every 4h, WhatIf):")
        print(ps)
        return

    result = asyncio.run(run_ps_command_elevated(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or result.stdout.strip() or "registration failed",
              file=sys.stderr)
        sys.exit(result.returncode)
    print(f"Created/updated {TASK_PATH}{TASK_NAME} — every 4h from 00:15, "
          f"WhatIf mode. Logs: {LOG_PATH}", file=sys.stderr)


if __name__ == "__main__":
    main()
