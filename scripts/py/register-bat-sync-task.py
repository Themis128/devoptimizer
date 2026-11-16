"""Register the BAT-Sync task + startup launcher (Python port of register-bat-sync-task.ps1).

Registers a daily 03:00 LIMITED scheduled task running sync-bat-ps1.ps1
and drops a .cmd launcher in the Startup folder. Mutating.
"""

import argparse
import asyncio
import os
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, sync, startup


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=r"D:\DevOptimizer")
    parser.add_argument("--task-name", default="DevOptimizer\\BAT-Sync")
    parser.add_argument("--launcher-name", default="DevOptimizer-BAT-Sync.cmd")
    parser.add_argument("--dry-run", action="store_true",
                        help="Describe actions without applying them")
    args = parser.parse_args()

    sync_script = Path(args.root) / "scripts" / "sync-bat-ps1.ps1"
    launcher = (Path(args.root) / "portable" / "sync-bat-ps1.bat")

    ps = (
        f"if (-not (Test-Path '{sync_script}')) {{ Write-Error 'sync script missing'; exit 1 }}; "
        "$exec = (Get-Command pwsh -ErrorAction SilentlyContinue).Source; "
        "if (-not $exec) { $exec = (Get-Command powershell -ErrorAction SilentlyContinue).Source }; "
        "if (-not $exec) { Write-Error 'no powershell'; exit 1 }; "
        f"$command = '\"' + $exec + '\" -NoProfile -ExecutionPolicy Bypass -File \"{sync_script}\"'; "
        f"& schtasks.exe /Delete /TN '{args.task_name}' /F 2>$null | Out-Null; "
        f"& schtasks.exe /Create /TN '{args.task_name}' /TR $command /SC DAILY "
        "/ST 03:00 /RL LIMITED /F; "
        "if ($LASTEXITCODE -ne 0) { Write-Error \"schtasks failed $LASTEXITCODE\"; exit 1 }; "
        "$startup = [Environment]::GetFolderPath('Startup'); "
        f"Set-Content -Path (Join-Path $startup '{args.launcher_name}') "
        "-Value \"@echo off`r`ncall `\"D:\\DevOptimizer\\portable\\sync-bat-ps1.bat`\"`r`n\" "
        "-Encoding ASCII; "
        "Write-Output 'DONE'"
    )

    if args.dry_run:
        print(f"[dry-run] would delete+create task '{args.task_name}' "
              f"(daily 03:00 LIMITED) and write Startup\\{args.launcher_name}:")
        print(ps)
        return

    result = asyncio.run(run_ps_command(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or result.stdout.strip() or "registration failed",
              file=sys.stderr)
        sys.exit(result.returncode)
    print(f"Scheduled task '{args.task_name}' registered and startup launcher "
          f"created ({args.launcher_name}).")


if __name__ == "__main__":
    main()
