"""Register one-time VHDX compaction task (Python port of create-compaction-task.ps1).

Registers DevOptimizer-VHDX-Compaction-OneTime to run compact-wsl-vhdx.ps1
as SYSTEM, once, starting in ~1 minute. Mutating, requires admin.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, vhdx, admin

TASK_NAME = "DevOptimizer-VHDX-Compaction-OneTime"
SCRIPT = r"D:\DevOptimizer\scripts\compact-wsl-vhdx.ps1"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the Register-ScheduledTask script without running it")
    parser.add_argument("--minutes", type=int, default=1,
                        help="Minutes from now for the one-time trigger")
    args = parser.parse_args()

    ps = (
        f"$action = New-ScheduledTaskAction -Execute 'powershell.exe' "
        f"-Argument '-File {SCRIPT} -ForceAll -Force'; "
        f"$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes({args.minutes}); "
        f"$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd; "
        f"$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' "
        f"-LogonType ServiceAccount -RunLevel Highest; "
        f"Register-ScheduledTask -TaskName '{TASK_NAME}' -Action $action "
        f"-Trigger $trigger -Settings $settings -Principal $principal -Force"
    )

    if args.dry_run:
        print(f"[dry-run] would register task '{TASK_NAME}' via elevated PowerShell:")
        print(ps)
        return

    result = asyncio.run(run_ps_command_elevated(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or "Register-ScheduledTask failed", file=sys.stderr)
        sys.exit(result.returncode)
    print(f"Task '{TASK_NAME}' registered (starts in {args.minutes} min)")


if __name__ == "__main__":
    main()
