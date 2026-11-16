"""List running Devin processes (Python port of check-devin-processes.ps1).

Shows Id, ProcessName, CPU and working set for every process whose name
contains "Devin".
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
# TAGS: devin, processes, monitoring


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit process list as JSON")
    args = parser.parse_args()

    script = (
        "Get-Process | Where-Object { $_.ProcessName -like '*Devin*' } | "
        "Select-Object Id, ProcessName, CPU, WS | ConvertTo-Json -Compress"
    )
    result = asyncio.run(run_ps_command(script))
    if result.returncode != 0:
        print(result.stderr.strip() or "process query failed", file=sys.stderr)
        sys.exit(result.returncode)

    processes = json.loads(result.stdout or "[]")
    if isinstance(processes, dict):
        processes = [processes]

    if args.json:
        print(json.dumps(processes, indent=2))
        return

    print(f"{'Id':>8}  {'ProcessName':<32} {'CPU':>10} {'WS (MB)':>12}")
    for p in processes:
        ws_mb = round((p.get("WS") or 0) / 1048576, 1)
        print(f"{p.get('Id', ''):>8}  {p.get('ProcessName', ''):<32} "
              f"{p.get('CPU') or 0:>10} {ws_mb:>12}")


if __name__ == "__main__":
    main()
