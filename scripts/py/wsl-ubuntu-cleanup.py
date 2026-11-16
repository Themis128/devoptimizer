"""WSL Ubuntu garbage sweep (port of
scripts/wsl-ubuntu-cleanup.ps1).

apt cache, journal vacuum 100MB, uv cache, gh cache >30d — inside
Ubuntu-24.04 as root. Skips silently when vmmemWSL absent. Logs to
logs/wsl-ubuntu-cleanup.log. --dry-run; --json.
"""

import argparse
import datetime
import json
import os
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: wsl, ubuntu, apt, journal, cache

LOG_FILE = r"D:\DevOptimizer\logs\wsl-ubuntu-cleanup.log"
STEPS = [
    ("apt-get clean", "apt-get clean -y"),
    ("journal vacuum 100M",
     "journalctl --vacuum-size=100M | tail -1"),
    ("uv cache clean",
     'sudo -u tbaltzakis -H bash -c "command -v uv >/dev/null && '
     'uv cache clean || rm -rf /home/tbaltzakis/.cache/uv/archive-v0"'),
    ("gh cache prune >30d",
     "find /home/tbaltzakis/.cache/gh -type f -mtime +30 -delete"),
]


def log(line: str, path: Path):
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(path, "a") as fh:
        fh.write(f"{stamp} {line}\n")


def wsl_root(cmd: str):
    env = dict(os.environ, WSL_UTF8="1")
    return subprocess.run(
        ["wsl.exe", "-d", "Ubuntu-24.04", "-u", "root", "--",
         "sh", "-c", cmd], capture_output=True, text=True,
        timeout=300, env=env)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--log", default=LOG_FILE)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    env = dict(os.environ, WSL_UTF8="1")
    vm = subprocess.run(["tasklist", "/FI", "IMAGENAME eq vmmemWSL"],
                        capture_output=True, text=True, env=env)
    if "vmmemWSL" not in vm.stdout:
        if args.dry_run:
            print("[dry-run] would skip: vmmemWSL absent")
            return
        log("WSL not running (skipped)", Path(args.log))
        return

    if args.dry_run:
        for name, cmd in STEPS:
            print(f"[dry-run] {name}: {cmd}")
        return

    before = wsl_root("df -B1 / | tail -1 | awk '{print $4}'")
    results = {}
    for name, cmd in STEPS:
        r = wsl_root(cmd)
        results[name] = r.stdout.strip()
        log(f"{name}: {r.stdout.strip() or 'ok'}", Path(args.log))
    after = wsl_root("df -B1 / | tail -1 | awk '{print $4}'")
    try:
        delta = (int(after.stdout.strip()) -
                 int(before.stdout.strip())) // (1024**2)
    except ValueError:
        delta = 0
    log(f"done: freed ~{delta} MB", Path(args.log))
    if args.json:
        print(json.dumps({"freed_mb": delta, "steps": results}))
    else:
        print(f"wsl-ubuntu-cleanup done: freed ~{delta} MB")


if __name__ == "__main__":
    main()
