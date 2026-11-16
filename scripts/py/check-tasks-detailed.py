"""Port of scripts/check-tasks-detailed.ps1 — list every task under
\\DevOptimizer\\ with trigger type, start boundary and repetition as a
table, via Get-ScheduledTask (locale-independent).
"""
import subprocess
import sys

PS = ("Get-ScheduledTask -TaskPath '\\DevOptimizer\\' "
      "-ErrorAction SilentlyContinue | ForEach-Object { "
      "$t = $_; foreach ($tr in $t.Triggers) { "
      "[pscustomobject]@{ TaskName = $t.TaskName; "
      "Schedule = $tr.GetType().Name; "
      "Time = $tr.StartBoundary; "
      "Repetition = $tr.RepetitionInterval } } } | "
      "ConvertTo-Json")


def main():
    r = subprocess.run(["powershell", "-NoProfile", "-Command", PS],
                       capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        print("No tasks under \\DevOptimizer\\", file=sys.stderr)
        return 1
    import json
    rows = json.loads(r.stdout)
    if isinstance(rows, dict):
        rows = [rows]
    cols = ("TaskName", "Schedule", "Time", "Repetition")
    w = [max(len(str(row.get(c, ""))) for row in
             rows + [dict.fromkeys(cols, c)]) for c in cols]
    print("  ".join(c.ljust(w[i]) for i, c in enumerate(cols)))
    for row in rows:
        print("  ".join(str(row.get(c, "")).ljust(w[i])
                        for i, c in enumerate(cols)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
