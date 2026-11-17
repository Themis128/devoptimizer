"""Register Devin-Session-Manager task (port of create-devin-session-task.bat).

schtasks \\DevOptimizer\\Devin-Session-Manager, every 4h from 00:15,
HIGHEST as tbaltzakis, runs manage-devin-sessions.ps1 -WhatIf.
Mutating; --dry-run.
"""

import argparse
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: scheduled-task, devin, watchdog

TASK = r"\DevOptimizer\Devin-Session-Manager"
TR = ("powershell.exe -NoProfile -ExecutionPolicy Bypass -File "
      "D:\\DevOptimizer\\scripts\\manage-devin-sessions.ps1 -WhatIf")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    cmd = ["schtasks", "/create", "/tn", TASK, "/tr", TR,
           "/sc", "HOURLY", "/mo", "4", "/st", "00:15",
           "/rl", "HIGHEST", "/ru", "tbaltzakis", "/f"]
    if args.dry_run:
        print("[dry-run] " + " ".join(cmd))
        return

    r = subprocess.run(cmd, capture_output=True, text=True)
    print(r.stdout.strip() or r.stderr.strip() or f"rc={r.returncode}")
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
