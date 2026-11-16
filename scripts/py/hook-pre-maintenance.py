"""Port of scripts/devin/hook-pre-maintenance.ps1 — pre-hook for Devin
maintenance commands. Emits a JSON decision on stdout:
- approve+context: -FixBundle deferred while Devin.exe is running
- block: WSL distro unreachable
- approve: otherwise
Args: --tool-name, --tool-input (matching the ps1 params).
"""
import argparse
import datetime
import json
import re
import subprocess
import sys
from pathlib import Path

LOG_FILE = Path(r"D:\DevOptimizer\logs\devin-hooks.log")


def log(msg):
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} "
                    f"[MAINT-HOOK] {msg}\n")
    except OSError:
        pass


def proc_running(name):
    try:
        out = subprocess.run(["tasklist"], capture_output=True,
                             text=True).stdout
        return name.lower() in out.lower()
    except OSError:
        return False


def emit(decision, **extra):
    print(json.dumps({"decision": decision, **extra}))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tool-name", default="")
    ap.add_argument("--tool-input", default="")
    args = ap.parse_args()

    log(f"Maintenance tool: {args.tool_name}")
    is_repair = re.search("Repair-Devin", args.tool_name)
    is_fix_bundle = re.search("FixBundle", args.tool_input)
    if is_repair and is_fix_bundle and proc_running("Devin"):
        log("DEFER: -FixBundle requested but Devin is running")
        emit("approve", additionalContext=(
            "Devin is running - bundle repair will be DEFERRED until "
            "Devin closes. Close Devin first for immediate repair."))
        return 0

    r = subprocess.run(
        ["wsl.exe", "-d", "Ubuntu-24.04", "--", "bash", "-c",
         "echo ok"], capture_output=True, text=True)
    if "ok" not in (r.stdout or ""):
        log("BLOCK: WSL unreachable for maintenance")
        emit("block",
             reason="WSL distro unreachable. Maintenance requires WSL.")
        return 2

    log("APPROVE: Maintenance checks passed")
    emit("approve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
