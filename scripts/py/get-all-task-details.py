"""Port of scripts/get-all-task-details.ps1 — dump triggers, actions
and key settings (ExecutionTimeLimit, StartWhenAvailable, WakeToRun,
RunOnlyIfIdle, DisallowStartIfOnBatteries, StopIfGoingOnBatteries) for
every task under \\DevOptimizer\\ via Get-ScheduledTask.
"""
import json
import subprocess
import sys

SETTINGS_KEYS = ("ExecutionTimeLimit", "StartWhenAvailable",
                 "WakeToRun", "RunOnlyIfIdle",
                 "DisallowStartIfOnBatteries",
                 "StopIfGoingOnBatteries")

PS = ("Get-ScheduledTask -TaskPath '\\DevOptimizer\\' "
      "-ErrorAction SilentlyContinue | ForEach-Object { "
      "$t = $_; [pscustomobject]@{ TaskName = $t.TaskName; "
      "Triggers = $t.Triggers; Actions = $t.Actions; "
      "Settings = $t.Settings | Select-Object "
      + ",".join(SETTINGS_KEYS) + " } } | ConvertTo-Json -Depth 5")


def main():
    r = subprocess.run(["powershell", "-NoProfile", "-Command", PS],
                       capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        print("No tasks under \\DevOptimizer\\")
        return 0
    tasks = json.loads(r.stdout)
    if isinstance(tasks, dict):
        tasks = [tasks]
    for t in tasks:
        print(f"=== {t.get('TaskName')} ===")
        for section in ("Triggers", "Actions", "Settings"):
            print(f"  {section}:")
            print(json.dumps(t.get(section), indent=4,
                             default=str))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
