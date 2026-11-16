"""Close Docker Desktop dashboard windows (Python port of docker-dashboard-guard.ps1).

com.docker.backend polls `docker stats` every ~5s while a dashboard
window exists, spawning conhost flashes (docker/for-win#13923/#13967).
Closing the window stops the polling; engine/tray keep running.
"""

import argparse
import asyncio
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: docker, window, guard

LOG_PATH = Path(r"D:\DevOptimizer\scripts\_docker-dashboard-guard.log")
TITLE_RE = r"Dashboard|Containers|Images|Volumes|Builds|Debug"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="List matching windows without closing them")
    parser.add_argument("--json", action="store_true", help="Emit result as JSON")
    args = parser.parse_args()

    select = (
        f"Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue | "
        f"Where-Object {{ $_.MainWindowHandle -ne 0 -and "
        f"$_.MainWindowTitle -match '{TITLE_RE}' }}"
    )
    script = select + " | Select-Object Id, MainWindowTitle | ConvertTo-Json -Compress"
    result = asyncio.run(run_ps_command(script))
    if result.returncode != 0:
        print(result.stderr.strip() or "process query failed", file=sys.stderr)
        sys.exit(result.returncode)

    wins = json.loads(result.stdout or "[]")
    if isinstance(wins, dict):
        wins = [wins]

    if args.json:
        print(json.dumps({"windows": wins, "closed": 0 if args.dry_run else len(wins)}))
        if args.dry_run:
            return

    if args.dry_run:
        print(f"[dry-run] {len(wins)} Docker Desktop window(s) would be closed")
        return

    if wins:
        close = select + " | ForEach-Object { $_.CloseMainWindow() | Out-Null }"
        asyncio.run(run_ps_command(close))
        line = (f"{datetime.now(timezone.utc).isoformat()} "
                f"closed {len(wins)} Docker Desktop window(s)\n")
        try:
            with LOG_PATH.open("a", encoding="utf-8") as f:
                f.write(line)
        except OSError as e:
            print(f"log write failed: {e}", file=sys.stderr)
        print(f"closed {len(wins)} Docker Desktop window(s)")


if __name__ == "__main__":
    main()
