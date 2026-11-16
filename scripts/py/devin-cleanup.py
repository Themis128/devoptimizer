"""Devin Desktop cleanup wrapper (port of
scripts/devin/devin-cleanup.ps1).

Commands: check / report / plan -> devin-doctor via WSL;
prune-acp / cleanup-sessions / daily-maintenance / health ->
DevOptimizer ps1 wrappers. --days N.
"""

import argparse
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, cleanup, wsl

DISTRO = "Ubuntu-24.04"
SCRIPTS_DIR = Path(__file__).resolve().parent.parent


def wsl(cmd: str):
    r = subprocess.run(
        ["wsl.exe", "-d", DISTRO, "--", "bash", "-c", cmd],
        capture_output=True, text=True, timeout=600)
    out = (r.stdout or "").replace("\x00", "")
    return [l for l in out.splitlines() if l.strip()]


def run_ps(script: str, *extra):
    subprocess.run(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-File", str(script), *extra])


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("command", choices=["check", "report", "plan",
                                       "prune-acp", "cleanup-sessions",
                                       "daily-maintenance", "health"],
                   nargs="?", default="check")
    p.add_argument("--days", type=int, default=14)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    cmd = args.command
    if args.dry_run:
        if cmd in ("check", "report", "plan"):
            print(f"[dry-run] wsl devin-doctor {cmd}")
        else:
            print(f"[dry-run] devin-cleanup {cmd} --days {args.days}")
        return

    if cmd in ("check", "report", "plan"):
        print(f"=== devin-doctor {cmd} ===")
        for line in wsl('export PATH="$HOME/.local/bin:$PATH" && '
                        f"devin-doctor {cmd}"):
            print(line)
    elif cmd == "prune-acp":
        print(f"=== Pruning ACP messages ({args.days}d retention) ===")
        run_ps(SCRIPTS_DIR / "prune-acp.ps1", "-Days", str(args.days))
    elif cmd == "cleanup-sessions":
        print("=== Cleaning superseded commit dirs / server logs ===")
        run_ps(SCRIPTS_DIR / "Repair-Devin.ps1", "-CleanLeftovers",
               "-PruneServerLogs", "-Days", str(args.days), "-Force")
    elif cmd == "daily-maintenance":
        run_ps(SCRIPTS_DIR / "Invoke-DevinDailyMaintenance.ps1")
    elif cmd == "health":
        for line in wsl('export PATH="$HOME/.local/bin:$PATH" && '
                        "devin-doctor check"):
            print(line)


if __name__ == "__main__":
    main()
