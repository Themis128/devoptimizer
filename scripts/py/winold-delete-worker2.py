"""Windows.old SYSTEM delete worker (port of
scripts/winold-delete-worker2.ps1).

Writes a worker .ps1 (rd passes over Windows.old + leftover upgrade
folders), registers a one-shot SYSTEM task for it, waits, then
unregisters. For TrustedInstaller-owned trees admins can't delete.
Requires elevation; --dry-run.
"""

import argparse
import asyncio
import os
import sys
import tempfile
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: cleanup
# TAGS: windows-old, system, elevated, task

LOG = r"D:\DevOptimizer\logs\winold-worker2.log"
TASK = "DevOptimizer-WinOldDelete"
TARGETS = [r"C:\Windows.old", r"C:\$WINDOWS.~BT", r"C:\$WinREAgent",
           r"C:\Windows10Upgrade", r"C:\$GetCurrent"]

WORKER = """$ErrorActionPreference = 'Continue'
$log = '{LOG}'
function Log([string]$m) {{ Add-Content $log ("{{0}} {{1}}" -f (Get-Date -Format 'HH:mm:ss'), $m) }}
Log "=== worker body start ==="
foreach ($t in @({TARGETS})) {{
    if (-not (Test-Path -LiteralPath $t)) {{ continue }}
    for ($i = 1; $i -le 6 -and (Test-Path -LiteralPath $t); $i++) {{
        Log "rd pass $i on $t"
        & cmd.exe /c "rd /s /q `"$t`"" 2>&1 | ForEach-Object {{ Log "  $_" }}
        Start-Sleep -Seconds 5
    }}
    Log "$t exists now: $(Test-Path -LiteralPath $t)"
}}
Log "=== worker body done ==="
"""


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    body = WORKER.format(
        LOG=LOG,
        TARGETS=", ".join(f"'{t}'" for t in TARGETS))
    if args.dry_run:
        print("[dry-run] worker body:")
        print(body)
        print(f"[dry-run] register+start {TASK}, wait <=60m, "
              "unregister, delete worker")
        return

    worker = Path(tempfile.gettempdir()) / "winold-delete-body.ps1"
    worker.write_text(body, encoding="utf-8")
    ps = (
        "$ErrorActionPreference = 'Stop'; "
        "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
        f"-Argument ('--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"{worker}\"'); "
        "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' "
        "-LogonType ServiceAccount -RunLevel Highest; "
        f"Register-ScheduledTask -TaskName '{TASK}' -Action $action "
        "-Principal $principal -Force | Out-Null; "
        f"Start-ScheduledTask -TaskName '{TASK}'; "
        "$deadline = (Get-Date).AddMinutes(60); "
        "while ((Get-Date) -lt $deadline) { "
        f"if ((Test-Path '{LOG}') -and (Select-String -Path '{LOG}' "
        "-Pattern 'worker body done' -Quiet)) { break }; "
        "Start-Sleep -Seconds 20 }; "
        f"Unregister-ScheduledTask -TaskName '{TASK}' -Confirm:$false "
        "-ErrorAction SilentlyContinue; "
        f"Remove-Item '{worker}' -Force -ErrorAction SilentlyContinue; "
        f"Write-Host ('done. Windows.old exists: ' + (Test-Path 'C:\\Windows.old'))")
    r = asyncio.run(run_ps_command(ps, timeout=3800))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip() or "failed — run elevated",
              file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
