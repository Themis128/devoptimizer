"""Restart Devin Desktop gracefully (Python port of restart-devin-weekly.ps1).

Stops Devin processes (graceful first, then forced), waits, then relaunches
Devin.exe from the standard install locations. Logs to the DevOptimizer
restart log. Mutating (kills/starts processes).
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, restart, process

LOG_PATH = Path(os.environ.get("USERPROFILE", "")) / \
    r"AppData\Local\DevOptimizer\logs\devin-restart.log"

DEVIN_CANDIDATES = [
    Path(os.environ.get("LOCALAPPDATA", "")) / r"Programs\Devin\Devin.exe",
    Path(os.environ.get("PROGRAMFILES", r"C:\Program Files")) / r"Devin\Devin.exe",
    Path(os.environ.get("PROGRAMFILES(X86)", r"C:\Program Files (x86)")) / r"Devin\Devin.exe",
    Path(os.environ.get("LOCALAPPDATA", "")) / r"Devin\Devin.exe",
]


def log(msg: str, level: str = "INFO") -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    line = f"{time.strftime('%Y-%m-%d %H:%M:%S')} [{level}] {msg}"
    with LOG_PATH.open("a", encoding="ascii", errors="replace") as f:
        f.write(line + "\n")
    print(line)


def devin_pids() -> list[int]:
    out = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq Devin.exe", "/FO", "CSV", "/NH"],
        capture_output=True, text=True, timeout=30).stdout
    pids = []
    for line in out.splitlines():
        cols = [c.strip('"') for c in line.split('","')]
        if len(cols) > 1 and cols[0].lower() == "devin.exe":
            try:
                pids.append(int(cols[1].rstrip('"')))
            except ValueError:
                continue
    return pids


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true",
                        help="Kill without attempting graceful close first")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    log("=== Devin Weekly Restart Started ===")
    pids = devin_pids()
    if args.dry_run:
        log(f"[dry-run] would stop {len(pids)} Devin pid(s) {pids} and relaunch")
        return

    for pid in pids:
        log(f"Stopping Devin PID {pid}")
        if not args.force:
            # graceful: taskkill without /F closes the main window first
            subprocess.run(["taskkill", "/PID", str(pid)],
                           capture_output=True, timeout=15)
            deadline = time.time() + 10
            while time.time() < deadline and pid in devin_pids():
                time.sleep(0.5)
        if pid in devin_pids():
            log(f"PID {pid} still alive, forcing", "WARN")
            subprocess.run(["taskkill", "/F", "/PID", str(pid)],
                           capture_output=True, timeout=15)

    time.sleep(5)

    exe = next((p for p in DEVIN_CANDIDATES if p.exists()), None)
    if exe is None:
        log("Devin.exe not found in standard locations", "ERROR")
        sys.exit(1)
    log(f"Starting Devin from {exe}")
    subprocess.Popen([str(exe)], close_fds=True)
    log("=== Devin Weekly Restart Completed Successfully ===")


if __name__ == "__main__":
    main()
