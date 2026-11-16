"""Launch Otter desktop with CDP :9333 (Python port of Start-OtterDesktop.ps1).

ELECTRON_RUN_AS_NODE=1 makes every Electron binary boot as plain node;
the launcher strips that var and adds --remote-debugging-port=9333 so the
notetaker toggle can drive Record/Stop. --register/--unregister manage
the DevOptimizer-Otter-Desktop AtLogOn task.
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
# TAGS: otter, cdp, launcher, scheduled-task

TASK_NAME = "DevOptimizer-Otter-Desktop"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--register", action="store_true",
                        help="Register the AtLogOn task")
    parser.add_argument("--unregister", action="store_true",
                        help="Remove the AtLogOn task")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    otter_exe = os.path.join(
        os.environ.get("LOCALAPPDATA", ""),
        r"Programs\@otter-aidesktop-app", "Otter.exe")
    launcher = Path(__file__).resolve().parent.parent / "Start-OtterDesktop.ps1"

    if args.unregister:
        if args.dry_run:
            print(f"[dry-run] would Unregister-ScheduledTask '{TASK_NAME}'")
            return
        asyncio.run(run_ps_command(
            f"Unregister-ScheduledTask -TaskName '{TASK_NAME}' "
            "-Confirm:$false -ErrorAction SilentlyContinue"))
        print(f"Removed scheduled task {TASK_NAME}")
        return

    if args.register:
        # conhost --headless action: the headless-rewrapper skips conhost
        # actions, so emit the portable pwsh path directly when it exists.
        ps = (
            "$sh = 'D:\\DevOptimizer\\pwsh\\pwsh.exe'; "
            "if (-not (Test-Path $sh)) { $sh = 'powershell.exe' }; "
            f"$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
            f"-Argument ('--headless ' + $sh + ' -NoProfile -ExecutionPolicy Bypass "
            f"-File \"{launcher}\"'); "
            "$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME; "
            f"Register-ScheduledTask -TaskName '{TASK_NAME}' -Action $action "
            "-Trigger $trigger -Description 'Launch Otter desktop with CDP "
            ":9333 for the notes toggle' -Force | Out-Null"
        )
        if args.dry_run:
            print(f"[dry-run] would register '{TASK_NAME}':")
            print(ps)
            return
        result = asyncio.run(run_ps_command(ps))
        if result.returncode != 0:
            print(result.stderr.strip() or "registration failed", file=sys.stderr)
            sys.exit(result.returncode)
        print(f"Registered scheduled task {TASK_NAME}")
        return

    if not Path(otter_exe).exists():
        print(f"Otter.exe not found at {otter_exe}", file=sys.stderr)
        sys.exit(1)

    if args.dry_run:
        print(f"[dry-run] would start '{otter_exe} --remote-debugging-port=9333' "
              "without ELECTRON_RUN_AS_NODE")
        return

    ps = (
        "$psi = New-Object System.Diagnostics.ProcessStartInfo; "
        f"$psi.FileName = '{otter_exe}'; "
        "$psi.Arguments = '--remote-debugging-port=9333'; "
        "$psi.UseShellExecute = $false; "
        "$psi.EnvironmentVariables.Remove('ELECTRON_RUN_AS_NODE') | Out-Null; "
        "[void][System.Diagnostics.Process]::Start($psi)"
    )
    result = asyncio.run(run_ps_command(ps))
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
