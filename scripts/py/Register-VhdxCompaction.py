"""Register WSL-Vhdx-Compact task (Python port of Register-VhdxCompaction.ps1).

Daily 03:45 task for Invoke-VhdxCompaction.ps1 as tbaltzakis/Highest
(SYSTEM principals ghost on this Insider build). Self-elevating, headless
conhost action. --remove unregisters, --trigger-now probes the deferred run.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, vhdx, compaction, elevated

TASK_NAME = "WSL-Vhdx-Compact"
TASK_PATH = "\\DevOptimizer\\"
SCRIPT = r"D:\DevOptimizer\scripts\Invoke-VhdxCompaction.ps1"
SENTINEL = r"D:\DevOptimizer\logs\register-vhdxcompaction-result.json"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--remove", action="store_true")
    parser.add_argument("--trigger-now", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    self_ps1 = str(Path(__file__).resolve().parent.parent / "Register-VhdxCompaction.ps1")

    # self-elevate when not admin, mirroring the original
    ps = (
        "$isAdmin = ([Security.Principal.WindowsPrincipal]"
        "[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("
        "[Security.Principal.WindowsBuiltInRole]::Administrator); "
        "if (-not $isAdmin) { "
        f"  $elevArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File','\"{self_ps1}\"'); "
        + ("  $elevArgs += '-Remove'; " if args.remove else "")
        + ("  $elevArgs += '-TriggerNow'; " if args.trigger_now else "")
        + "  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList $elevArgs; "
        f"  if (Test-Path '{SENTINEL}') {{ Get-Content '{SENTINEL}' -Raw }}; exit 0 }}; "
    )

    if args.remove:
        ps += (
            f"Unregister-ScheduledTask -TaskPath '{TASK_PATH}' -TaskName '{TASK_NAME}' "
            "-Confirm:$false -ErrorAction SilentlyContinue; "
            f"Write-Output 'Removed {TASK_PATH}{TASK_NAME}'"
        )
    else:
        ps += (
            "$sh = 'D:\\DevOptimizer\\pwsh\\pwsh.exe'; "
            "if (-not (Test-Path $sh)) { $sh = 'powershell.exe' }; "
            "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
            f"-Argument ('--headless ' + $sh + ' -NoProfile -ExecutionPolicy Bypass -File \"{SCRIPT}\"') "
            f"-WorkingDirectory 'D:\\DevOptimizer'; "
            "$trigger = New-ScheduledTaskTrigger -Daily -At '03:45'; "
            "$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable "
            "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
            "-RestartCount 8 -RestartInterval (New-TimeSpan -Minutes 30) "
            "-ExecutionTimeLimit (New-TimeSpan -Hours 2) "
            "-MultipleInstances IgnoreNew; "
            "$principal = New-ScheduledTaskPrincipal -UserId 'tbaltzakis' "
            "-LogonType Interactive -RunLevel Highest; "
            f"Register-ScheduledTask -TaskPath '{TASK_PATH}' -TaskName '{TASK_NAME}' "
            "-Action $action -Trigger $trigger -Settings $settings "
            "-Principal $principal -Force -ErrorAction Stop | Out-Null; "
            f"$probe = Get-ScheduledTask -TaskPath '{TASK_PATH}' -TaskName '{TASK_NAME}'; "
            "Write-Output ('elevated-view: State=' + $probe.State) "
        )
        if args.trigger_now:
            ps += (
                f"; Start-ScheduledTask -TaskPath '{TASK_PATH}' -TaskName '{TASK_NAME}'; "
                "$w = 0; do { Start-Sleep 5; $w += 5; "
                f"  $p = Get-ScheduledTask -TaskPath '{TASK_PATH}' -TaskName '{TASK_NAME}'; "
                "  $info = $p | Get-ScheduledTaskInfo } "
                "while ($p.State -eq 'Running' -and $w -lt 180); "
                "Write-Output ('triggerNow: lastResult=' + $info.LastTaskResult)"
            )
        ps += (
            f"; [pscustomobject]@{{ ok=$true; at=(Get-Date).ToString('o') }} | "
            f"ConvertTo-Json | Set-Content '{SENTINEL}'"
        )

    if args.dry_run:
        print(f"[dry-run] would run ({'remove' if args.remove else 'register'}):")
        print(ps)
        return

    result = asyncio.run(run_ps_command(ps, timeout=300))
    print(result.stdout.strip(), file=sys.stderr)
    if result.returncode != 0:
        print(result.stderr.strip() or "registration failed", file=sys.stderr)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
