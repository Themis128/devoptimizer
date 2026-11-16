"""Show DevOptimizer task trigger times (Python port of check-task-triggers.ps1).

Lists each \\DevOptimizer\\ scheduled task with its trigger StartBoundary,
including days-of-week where set.
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: scheduled-task, trigger


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit results as JSON")
    args = parser.parse_args()

    script = (
        "Get-ScheduledTask -TaskPath '\\DevOptimizer\\' -ErrorAction SilentlyContinue | "
        "ForEach-Object { $t = $_; foreach ($tr in $t.Triggers) { "
        "  $timeInfo = $tr.StartBoundary; "
        "  if ($tr.DaysOfWeek) { $timeInfo = \"$($tr.DaysOfWeek) at $timeInfo\" }; "
        "  [pscustomobject]@{ TaskName = $t.TaskName; Time = $timeInfo } } } | "
        "ConvertTo-Json -Compress"
    )
    result = asyncio.run(run_ps_command(script))
    if result.returncode != 0:
        print(result.stderr.strip() or "task query failed", file=sys.stderr)
        sys.exit(result.returncode)

    rows = json.loads(result.stdout or "[]")
    if isinstance(rows, dict):
        rows = [rows]
    if args.json:
        print(json.dumps(rows, indent=2))
        return
    print(f"{'TaskName':<45} Time")
    for r in rows:
        print(f"{r.get('TaskName', ''):<45} {r.get('Time', '')}")


if __name__ == "__main__":
    main()
