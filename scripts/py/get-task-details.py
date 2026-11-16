"""Port of scripts/get-task-details.ps1 — dump triggers, actions and
settings of the \\DevOptimizer\\Safe-Cleanup-Daily scheduled task via
Get-ScheduledTask (locale-independent, unlike schtasks parsing).
"""
import json
import subprocess
import sys

PS = ("$t = Get-ScheduledTask -TaskPath '\\DevOptimizer\\' "
      "-TaskName 'Safe-Cleanup-Daily' -ErrorAction SilentlyContinue; "
      "if (-not $t) { exit 3 }; "
      "$t | Select-Object TaskName, TaskPath, State, Triggers, "
      "Actions, Settings | ConvertTo-Json -Depth 5")


def main():
    r = subprocess.run(["powershell", "-NoProfile", "-Command", PS],
                       capture_output=True, text=True)
    if r.returncode == 3 or not r.stdout.strip():
        print("Task not found", file=sys.stderr)
        return 1
    print(json.dumps(json.loads(r.stdout), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
