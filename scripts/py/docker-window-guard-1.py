"""Persistent Docker Desktop window closer (Python port of docker-window-guard.ps1).

Loops every --interval seconds (default 3) closing any Docker Desktop
dashboard window, bounding dashboard-open time — the 5-min scheduled-task
variant only bounds it to 5 minutes. Engine/tray keep running.
"""

import argparse
import asyncio
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: docker, window, guard

LOG_PATH = Path(r"D:\DevOptimizer\scripts\_docker-window-guard.log")
TITLE_RE = r"Dashboard|Containers|Images|Volumes|Builds|Debug"
SELECT = (
    "Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue | "
    f"Where-Object {{ $_.MainWindowHandle -ne 0 -and "
    f"$_.MainWindowTitle -match '{TITLE_RE}' }}"
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--interval", type=float, default=3,
                        help="Seconds between scans")
    parser.add_argument("--max-iterations", type=int, default=0,
                        help="Stop after N scans (0 = run forever)")
    args = parser.parse_args()

    iteration = 0
    while True:
        try:
            script = SELECT + (" | Select-Object Id, MainWindowTitle | "
                               "ConvertTo-Json -Compress")
            result = asyncio.run(run_ps_command(script))
            wins = json.loads(result.stdout or "[]") if result.returncode == 0 else []
            if isinstance(wins, dict):
                wins = [wins]
            if wins:
                asyncio.run(run_ps_command(
                    SELECT + " | ForEach-Object { $null = $_.CloseMainWindow() }"))
                for p in wins:
                    line = (f"{datetime.now(timezone.utc).isoformat()} closed "
                            f"Docker Desktop window pid={p.get('Id')} "
                            f"title={p.get('MainWindowTitle')}\n")
                    try:
                        with LOG_PATH.open("a", encoding="utf-8") as f:
                            f.write(line)
                    except OSError:
                        pass
        except Exception as e:  # keep the guard alive like the PS try/catch
            print(f"scan error: {e}", file=sys.stderr)

        iteration += 1
        if args.max_iterations and iteration >= args.max_iterations:
            return
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
