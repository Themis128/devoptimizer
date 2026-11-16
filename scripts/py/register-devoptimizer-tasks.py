"""Register DevOptimizer tasks (port of
scripts/register-devoptimizer-tasks.ps1).

Registers Extended-Cleanup (weekly Mon 02:30) +
DevOptimizer-Elevated-Cleanup (every 15 days 03:00, SYSTEM), plus
Storage Sense policy bits. conhost --headless actions. Self-elevates;
--dry-run.
"""

import argparse
import asyncio
import sys
import tempfile
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import is_admin, run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, cleanup, elevated

PS_BODY = (
    "$ErrorActionPreference = 'Stop'; "
    "$extAction = New-ScheduledTaskAction -Execute 'conhost.exe' "
    "-Argument '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"D:\\DevOptimizer\\scripts\\extended-cleanup.ps1\"'; "
    "$extTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At '02:30'; "
    "$extSettings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable "
    "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
    "-ExecutionTimeLimit (New-TimeSpan -Hours 2); "
    "Register-ScheduledTask -TaskName 'Extended-Cleanup' -TaskPath '\\DevOptimizer\\' "
    "-Action $extAction -Trigger $extTrigger -Settings $extSettings -Force | Out-Null; "
    "Write-Host '[OK] \\DevOptimizer\\Extended-Cleanup'; "
    "$elevAction = New-ScheduledTaskAction -Execute 'conhost.exe' "
    "-Argument '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"D:\\DevOptimizer\\scripts\\elevated-complete-cleanup.ps1\"'; "
    "$elevTrigger = New-ScheduledTaskTrigger -Daily -DaysInterval 15 -At '03:00'; "
    "$elevSettings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable "
    "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
    "-ExecutionTimeLimit (New-TimeSpan -Hours 4); "
    "Register-ScheduledTask -TaskName 'DevOptimizer-Elevated-Cleanup' "
    "-TaskPath '\\DevOptimizer\\' -Action $elevAction -Trigger $elevTrigger "
    "-User 'SYSTEM' -RunLevel Highest -Settings $elevSettings -Force | Out-Null; "
    "Write-Host '[OK] \\DevOptimizer\\DevOptimizer-Elevated-Cleanup'; "
    "$sp = 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\StorageSense\\Parameters\\StoragePolicy'; "
    "New-Item -Path $sp -Force | Out-Null; "
    "Set-ItemProperty -Path $sp -Name '01' -Type DWord -Value 1")


async def elevate(tmp: Path, ps_body: str):
    esc = str(tmp).replace("\\", "\\\\")
    cmd = ("$p = Start-Process powershell -Verb RunAs -Wait -PassThru "
           "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass',"
           f"'-File','\"{esc}\"'; exit $p.ExitCode")
    return await run_ps_command(cmd)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.dry_run:
        print("[dry-run] " + PS_BODY)
        return
    if not is_admin():
        tmp = Path(tempfile.gettempdir()) / "register-devopt-tasks.ps1"
        tmp.write_text(PS_BODY, encoding="utf-8")
        r = asyncio.run(elevate(tmp, PS_BODY))
        tmp.unlink(missing_ok=True)
    else:
        r = asyncio.run(run_ps_command(PS_BODY))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip() or "registration failed", file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
