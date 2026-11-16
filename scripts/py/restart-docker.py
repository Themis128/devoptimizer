"""Restart Docker Desktop (Python port of restart-docker.ps1).

Stops com.docker.backend and Docker Desktop processes, waits 5s, then
relaunches Docker Desktop. Requires admin.
"""

import argparse
import asyncio
import sys
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command  # noqa: E402

# CATEGORY: utilities
# TAGS: docker, restart, admin

DOCKER_DESKTOP = r"C:\Program Files\Docker\Docker\Docker Desktop.exe"
PROCESSES = ("com.docker.backend", "Docker Desktop")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Report what would happen without doing it")
    parser.add_argument("--wait", type=int, default=5,
                        help="Seconds between stop and relaunch")
    args = parser.parse_args()

    if args.dry_run:
        print(f"[dry-run] would stop {', '.join(PROCESSES)}, "
              f"wait {args.wait}s, launch {DOCKER_DESKTOP}")
        return

    for name in PROCESSES:
        asyncio.run(run_command(
            ["taskkill", "/F", "/IM", f"{name}.exe" if not name.endswith(".exe") else name]))
    time.sleep(args.wait)

    result = asyncio.run(run_command(
        ["powershell", "-NoProfile", "-Command",
         f"Start-Process '{DOCKER_DESKTOP}'"]))
    if result.returncode != 0:
        print(result.stderr.strip() or "failed to launch Docker Desktop", file=sys.stderr)
        sys.exit(result.returncode)
    print("Docker Desktop relaunched")


if __name__ == "__main__":
    main()
