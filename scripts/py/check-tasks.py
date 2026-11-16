"""Show DevOptimizer task run state (Python port of check-tasks.ps1).

Lists TaskName, NextRunTime, LastRunTime and LastTaskResult for every
scheduled task under \\DevOptimizer\\.
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
# TAGS: scheduled-task, health


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit results as JSON")
    args = parser.parse_args()

    script = (
        "$results = @(); "
        "foreach ($t in (Get-ScheduledTask -TaskPath '\\DevOptimizer\\' "
        "-ErrorAction SilentlyContinue)) { "
        "  $info = Get-ScheduledTaskInfo -TaskName $t.TaskName; "
        "  $results += [pscustomobject]@{ TaskName = $t.TaskName; "
        "    NextRunTime = $info.NextRunTime; LastRunTime = $info.LastRunTime; "
        "    LastTaskResult = $info.LastTaskResult } }; "
        "$results | ConvertTo-Json -Compress"
    )
    result = asyncio.run(run_ps_command(script, timeout=180))
    if result.returncode != 0:
        print(result.stderr.strip() or "task query failed", file=sys.stderr)
        sys.exit(result.returncode)

    rows = json.loads(result.stdout or "[]")
    if isinstance(rows, dict):
        rows = [rows]
    if args.json:
        print(json.dumps(rows, indent=2, default=str))
        return
    print(f"{'TaskName':<45} {'NextRunTime':<20} {'LastRunTime':<20} Result")
    for r in rows:
        print(f"{r.get('TaskName', ''):<45} {str(r.get('NextRunTime', '')):<20} "
              f"{str(r.get('LastRunTime', '')):<20} {r.get('LastTaskResult', '')}")


if __name__ == "__main__":
    main()
