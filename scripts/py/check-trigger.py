"""Inspect a once-at-12:00 scheduled-task trigger (Python port of check-trigger.ps1).

Shows the full property set of the trigger object produced by
New-ScheduledTaskTrigger -Once -At '12:00'.
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
    parser.add_argument("--json", action="store_true", help="Emit raw trigger JSON")
    args = parser.parse_args()

    result = asyncio.run(run_ps_command(
        "New-ScheduledTaskTrigger -Once -At '12:00' | ConvertTo-Json -Depth 4 -Compress"))
    if result.returncode != 0:
        print(result.stderr.strip() or "trigger query failed", file=sys.stderr)
        sys.exit(result.returncode)

    trigger = json.loads(result.stdout or "{}")
    if args.json:
        print(json.dumps(trigger, indent=2))
    else:
        for key, value in sorted(trigger.items()):
            print(f"{key}: {value}")


if __name__ == "__main__":
    main()
