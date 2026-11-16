"""SessionStart hook (Python port of devin/hook-session-start.ps1).

Quick health check on Devin CLI session start: WSL reachability, host
free memory, Devin Desktop version. Logs context and emits the hook JSON.
"""

import argparse
import asyncio
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: devin, hook, session

LOG_FILE = Path(r"D:\DevOptimizer\logs\devin-hooks.log")
DISTRO = "Ubuntu-24.04"


def log_hook(message: str) -> None:
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} [SESSION] {message}\n")
    except OSError:
        pass


def wsl_reachable() -> bool:
    try:
        out = subprocess.run(
            ["wsl.exe", "-d", DISTRO, "--", "bash", "-c", "echo ok"],
            capture_output=True, text=True, timeout=15)
        return "ok" in out.stdout
    except Exception:
        return False


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--tool-name", default="")
    parser.add_argument("--tool-input", default="")
    args = parser.parse_args()

    log_hook("Devin CLI session started")

    wsl_ok = wsl_reachable()

    osq = asyncio.run(run_ps_command(
        "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"))
    try:
        free_gb = round(int(osq.stdout.strip()) / 1048576, 1)
    except (ValueError, AttributeError):
        free_gb = -1

    devin_exe = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Devin" / "Devin.exe"
    if devin_exe.exists():
        ver_q = asyncio.run(run_ps_command(
            f"(Get-Item '{str(devin_exe)}').VersionInfo.ProductVersion"))
        version = ver_q.stdout.strip() or "UNKNOWN"
    else:
        version = "NOT_INSTALLED"

    context = {
        "wslReachable": wsl_ok,
        "hostFreeGB": free_gb,
        "devinVersion": version,
        "timestamp": datetime.now().isoformat(),
    }
    log_hook(f"Session context: {json.dumps(context, separators=(',', ':'))}")

    print(json.dumps({
        "decision": "approve",
        "additionalContext": (
            f"DevOptimizer session start: WSL={wsl_ok}, HostMem={free_gb}GB, "
            "Devin={version}. Run `/devin-health` for full check."
        ).replace("{version}", version),
    }))


if __name__ == "__main__":
    main()
