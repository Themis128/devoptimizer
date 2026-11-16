"""Register WSL-Vhdx-Compact task (Python port of Register-VhdxCompaction.ps1).

Daily 03:45 task for Invoke-VhdxCompaction.ps1 as tbaltzakis/Highest
(SYSTEM principals ghost on this Insider build). Self-elevating; the
elevated pass runs THIS port's body via a temp .ps1 so the registered
action stays the headless conhost one. --remove unregisters,
--trigger-now probes the deferred run.
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
SELF_PS1 = r"$env:TEMP\register-vhdxcompaction-self.ps1"


def build_body(args: argparse.Namespace) -> str:
    """The PS body that does the actual work (runs inside the elevation)."""
    if args.remove:
        return (
            f"Unregister-ScheduledTask -TaskPath '{TASK_PATH}' "
            f"-TaskName '{TASK_NAME}' -Confirm:$false "
            "-ErrorAction SilentlyContinue; "
            f"Write-Output 'Removed {TASK_PATH}{TASK_NAME}'"
        )
    ps = (
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
    return ps


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--remove", action="store_true")
    parser.add_argument("--trigger-now", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    body = build_body(args)

    # outer wrapper: non-admin -> write body to temp ps1 + elevate with -File;
    # admin -> run the body inline.
    ps = (
        "$isAdmin = ([Security.Principal.WindowsPrincipal]"
        "[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("
        "[Security.Principal.WindowsBuiltInRole]::Administrator); "
        "if (-not $isAdmin) { "
        f"  Set-Content '{SELF_PS1}' @'\n{body}\n'@ -Encoding UTF8; "
        f"  Start-Process powershell -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','{SELF_PS1}'); "
        f"  if (Test-Path '{SENTINEL}') {{ Get-Content '{SENTINEL}' -Raw }}; exit 0 }}; "
        + body
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
