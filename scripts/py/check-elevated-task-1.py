"""Find elevated/admin VHDX tasks (Python port of check-elevated-task.ps1).

Lists \\DevOptimizer\\ scheduled tasks whose name matches elevated, vhdx
or admin.
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
# TAGS: scheduled-task, admin, vhdx


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit matches as JSON")
    args = parser.parse_args()

    script = (
        "Get-ScheduledTask -TaskPath '\\DevOptimizer\\' -ErrorAction SilentlyContinue | "
        "Where-Object { $_.TaskName -like '*elevated*' -or $_.TaskName -like '*vhdx*' "
        "-or $_.TaskName -like '*admin*' } | Select-Object TaskName, State | "
        "ConvertTo-Json -Compress"
    )
    result = asyncio.run(run_ps_command(script))
    if result.returncode != 0:
        print(result.stderr.strip() or "task query failed", file=sys.stderr)
        sys.exit(result.returncode)

    tasks = json.loads(result.stdout or "[]")
    if isinstance(tasks, dict):
        tasks = [tasks]
    if args.json:
        print(json.dumps(tasks, indent=2))
        return
    for t in tasks:
        print(f"Found: {t.get('TaskName', '')}")


if __name__ == "__main__":
    main()
