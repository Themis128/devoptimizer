"""Register Admin-Cleanup-System as SYSTEM task
(port of scripts/register-admin-task-elevated.bat).

Weekly SUN 03:00, SYSTEM/HIGHEST, 72h limit, hidden — action wrapped in
conhost --headless per the repo's headless-action rule. Self-elevates
when not already admin (the hub doesn't auto-elevate .py entries).
Mutating; --dry-run.
"""

import argparse
import asyncio
import sys
import tempfile
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, cleanup, system, elevated

SCRIPT = r"D:\DevOptimizer\scripts\admin-cleanup-system.ps1"

PS_BODY = (
    "$ErrorActionPreference = 'Stop'; "
    "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
    f"-Argument ('--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"{SCRIPT}\"'); "
    "$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 03:00; "
    "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
    "-DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden "
    "-ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8; "
    "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' "
    "-LogonType ServiceAccount -RunLevel Highest; "
    "Register-ScheduledTask -TaskName 'Admin-Cleanup-System' "
    "-TaskPath '\\DevOptimizer\\' -Action $action -Trigger $trigger "
    "-Settings $settings -Principal $principal -Force; "
    "Write-Host 'Registered Admin-Cleanup-System task (SYSTEM account)'"
)


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


async def elevate(ps_body: str) -> int:
    with tempfile.NamedTemporaryFile(
            "w", suffix=".ps1", delete=False) as f:
        f.write(ps_body)
        tmp = f.name
    try:
        esc = tmp.replace("'", "''")
        r = await run_ps_command(
            "$p = Start-Process powershell -Verb RunAs -Wait -PassThru "
            f"-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','{esc}'; "
            "exit $p.ExitCode")
        return r.returncode
    finally:
        Path(tmp).unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.dry_run:
        print("[dry-run] " + PS_BODY)
        return

    if not is_admin():
        print("elevating via UAC...", file=sys.stderr)
        sys.exit(asyncio.run(elevate(PS_BODY)))

    r = asyncio.run(run_ps_command(PS_BODY))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip() or "registration failed", file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
