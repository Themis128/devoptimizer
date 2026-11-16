"""DevOptimizer automation module (Python port of automation-module.ps1).

Modes: setup (predefined tasks), create, list, remove, run, oneclick,
backup, update, maintenance. Task registration via conhost headless +
pwsh fallback. Mutating; --dry-run.
"""

import argparse
import asyncio
import json
import sys
import urllib.request
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: automation, scheduled-task, maintenance

PREDEFINED = {
    "daily_cleanup": ("Daily System Cleanup", "smart-cleanup.ps1",
                      "daily", "-Mode automated"),
    "weekly_optimization": ("Weekly System Optimization",
                            "ai-optimization.ps1", "weekly",
                            "-Mode comprehensive"),
    "monthly_maintenance": ("Monthly System Maintenance",
                            "deep-maintenance.ps1", "monthly",
                            "-Mode full"),
    "backup_config": ("Configuration Backup", "backup-config.ps1",
                      "daily", "-Mode config"),
    "update_check": ("Update Check", "update-checker.ps1",
                     "daily", "-Mode check"),
}

TRIGGERS = {
    "daily": "New-ScheduledTaskTrigger -Daily -At '02:00'",
    "weekly": "New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '03:00'",
    "monthly": "New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At '04:00'",
    "hourly": "New-ScheduledTaskTrigger -Once -At (Get-Date) "
              "-RepetitionInterval (New-TimeSpan -Hours 1) "
              "-RepetitionDuration (New-TimeSpan -Days 365)",
}


def create_ps(task_name: str, script: str, schedule: str,
              parameters: str) -> str:
    trigger = TRIGGERS.get(schedule.lower(), TRIGGERS["daily"])
    return (
        "$sh = 'D:\\DevOptimizer\\pwsh\\pwsh.exe'; "
        "if (-not (Test-Path $sh)) { $sh = 'powershell.exe' }; "
        "$action = New-ScheduledTaskAction -Execute 'conhost.exe' "
        f"-Argument ('--headless ' + $sh + ' -NoProfile -ExecutionPolicy Bypass "
        f"-File \"{script}\" {parameters}') "
        "-WorkingDirectory 'D:\\DevOptimizer'; "
        f"$trigger = {trigger}; "
        "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -StartWhenAvailable "
        "-RunOnlyIfNetworkAvailable; "
        "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' "
        "-LogonType ServiceAccount -RunLevel Highest; "
        f"Register-ScheduledTask -TaskPath '\\DevOptimizer\\' "
        f"-TaskName '{task_name}' -Action $action -Trigger $trigger "
        "-Settings $settings -Principal $principal -Force | Out-Null; "
        f"Write-Output 'registered {task_name}'"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--mode", default="schedule",
                        choices=["setup", "create", "list", "remove", "run",
                                 "oneclick", "backup", "update",
                                 "maintenance", "schedule"])
    parser.add_argument("--task-name", default="")
    parser.add_argument("--schedule", default="daily",
                        choices=list(TRIGGERS))
    parser.add_argument("--script", default="./custom-task.ps1")
    parser.add_argument("--parameters", default="")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if args.mode == "setup":
        print("Setting up predefined automation tasks:", file=sys.stderr)
        for key, (name, script, sched, params) in PREDEFINED.items():
            ps = create_ps(name, script, sched, params)
            if args.dry_run:
                print(f"  [dry-run] {key}: {name} ({sched})", file=sys.stderr)
                continue
            r = asyncio.run(run_ps_command(ps))
            print(f"  {key}: rc={r.returncode}", file=sys.stderr)
        return

    if args.mode == "create":
        if not args.task_name:
            print("TaskName required for create", file=sys.stderr)
            sys.exit(1)
        ps = create_ps(args.task_name, args.script, args.schedule,
                       args.parameters)
        if args.dry_run:
            print(f"[dry-run] would register {args.task_name}:")
            print(ps)
            return
        r = asyncio.run(run_ps_command(ps))
        print(r.stdout.strip(), file=sys.stderr)
        sys.exit(r.returncode)

    if args.mode == "list":
        ps = ("Get-ScheduledTask -TaskPath '\\DevOptimizer\\' | "
              "Select-Object TaskName, State | ConvertTo-Json -Compress")
        r = asyncio.run(run_ps_command(ps))
        tasks = json.loads(r.stdout.strip()) if r.stdout.strip() else []
        if isinstance(tasks, dict):
            tasks = [tasks]
        if args.json:
            print(json.dumps(tasks, indent=2))
        else:
            for t in tasks:
                print(f"  {t['TaskName']:40} {t['State']}")
        return

    if args.mode in ("remove", "run"):
        if not args.task_name:
            print("TaskName required", file=sys.stderr)
            sys.exit(1)
        verb = ("Unregister-ScheduledTask -Confirm:$false"
                if args.mode == "remove" else "Start-ScheduledTask")
        ps = (f"{verb} -TaskPath '\\DevOptimizer\\' "
              f"-TaskName '{args.task_name}'")
        if args.dry_run:
            print(f"[dry-run] {verb} {args.task_name}")
            return
        r = asyncio.run(run_ps_command(ps))
        print(r.stdout.strip() or f"{args.mode} -> rc {r.returncode}",
              file=sys.stderr)
        sys.exit(r.returncode)

    if args.mode == "update":
        try:
            rel = json.loads(urllib.request.urlopen(
                "https://api.github.com/repos/devoptimizer/enhanced-suite/"
                "releases/latest", timeout=15).read())
            tag = rel.get("tag_name", "?")
            print(f"latest release: {tag} (current 2.0.0)")
        except Exception as e:  # noqa: BLE001
            print(f"update check failed: {e}", file=sys.stderr)
        return

    print("DevOptimizer Automation Module")
    print("  --mode setup/create/list/remove/run/oneclick/backup/"
          "update/maintenance")
    print("  (oneclick/backup/maintenance: handled by dedicated scripts)")


if __name__ == "__main__":
    main()
