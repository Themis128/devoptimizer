"""Pre-session gate hook (Python port of devin/hook-pre-devin.ps1).

Blocks the session when WSL is unreachable or Devin Desktop is missing;
warns via additionalContext when host memory is low. Emits the hook
decision JSON.
"""

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
# TAGS: devin, hook, gate

LOG_FILE = Path(r"D:\DevOptimizer\logs\devin-hooks.log")
DISTRO = "Ubuntu-24.04"
MIN_FREE_GB = 1.5


def log_hook(message: str) -> None:
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} [PRE] {message}\n")
    except OSError:
        pass


def emit(decision: str, **extra) -> None:
    print(json.dumps({"decision": decision, **extra}))


def main() -> None:
    try:
        ping = subprocess.run(
            ["wsl.exe", "-d", DISTRO, "--", "bash", "-c", "echo ok"],
            capture_output=True, text=True, timeout=15)
        wsl_ok = "ok" in ping.stdout
    except Exception:
        wsl_ok = False
    if not wsl_ok:
        log_hook(f"BLOCK: WSL distro '{DISTRO}' unreachable")
        emit("block",
             reason="WSL distro unreachable. Run "
                    "`wsl -d Ubuntu-24.04 --exec true` first.")
        sys.exit(2)

    osq = asyncio.run(run_ps_command(
        "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"))
    try:
        free_gb = round(int(osq.stdout.strip()) / 1048576, 1)
    except (ValueError, AttributeError):
        free_gb = -1
    if 0 <= free_gb < MIN_FREE_GB:
        log_hook(f"WARN: Host memory low: {free_gb} GB")
        emit("approve",
             additionalContext=f"Host memory low ({free_gb} GB). "
                               "Devin operations may fail.")
        sys.exit(0)

    devin_exe = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Devin" / "Devin.exe"
    if not devin_exe.exists():
        log_hook("BLOCK: Devin Desktop not installed")
        emit("block", reason=f"Devin Desktop not found at {devin_exe}")
        sys.exit(2)

    log_hook("APPROVE: Environment checks passed")
    emit("approve")
    sys.exit(0)


if __name__ == "__main__":
    main()
