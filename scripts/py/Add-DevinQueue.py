"""Enqueue a command for next Devin session start (Python port of devin/Add-DevinQueue.ps1).

Adds to the FCFS queue persisted at C:\\Users\\tbaltzakis\\devin-queue\\
queue-state.json via queue-manager.ps1 -Action enqueue.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, queue

QUEUE_MANAGER = Path(r"C:\Users\tbaltzakis\devin-queue\hooks\queue-manager.ps1")
PWSH = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WindowsApps" / "pwsh.exe"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", help="Command to execute on next session start")
    parser.add_argument("working_dir", nargs="?", default=r"D:\DevOptimizer")
    parser.add_argument("description", nargs="?", default="")
    parser.add_argument("--max-retries", type=int, default=3)
    args = parser.parse_args()

    if not QUEUE_MANAGER.exists():
        print(f"Queue manager not found at {QUEUE_MANAGER}", file=sys.stderr)
        sys.exit(1)

    pwsh = str(PWSH) if PWSH.exists() else "pwsh"
    cmd = [
        pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden", "-File", str(QUEUE_MANAGER),
        "-Action", "enqueue",
        "-Command", args.command,
        "-WorkingDir", args.working_dir,
        "-Description", args.description,
        "-MaxRetries", str(args.max_retries),
    ]
    proc = subprocess.run(cmd)
    sys.exit(proc.returncode)


if __name__ == "__main__":
    main()
