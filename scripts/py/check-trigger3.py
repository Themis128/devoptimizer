"""Show trigger type names (Python port of check-trigger3.ps1).

Prints the CLR type names of a once-at-12:00 scheduled-task trigger and its
Repetition member.
"""

import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities


def main() -> None:
    script = (
        "$t = New-ScheduledTaskTrigger -Once -At '12:00'; "
        "$t.GetType().FullName; $t.Repetition.GetType().FullName"
    )
    result = asyncio.run(run_ps_command(script))
    if result.returncode != 0:
        print(result.stderr.strip() or "trigger query failed", file=sys.stderr)
        sys.exit(result.returncode)
    print(result.stdout.strip())


if __name__ == "__main__":
    main()
