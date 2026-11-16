"""Real-time monitor (port of tools/Variants/REAL-TIME-MONITOR-*.bat).

Periodic health check: critical hub files present, PowerShell execution
policy not blocking, admin status — logs to logs/real-time-monitor.log
every 5s (--interval). --admin selects the admin variant.
"""

import argparse
import asyncio
import sys
import time
from datetime import datetime
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: monitor, health, logs

SCRIPT_DIR = Path(r"D:\DevOptimizer")
CRITICAL = ["01-Quick-Optimization.bat", "06-System-Health-Check.bat",
            "00-LAUNCHER.bat"]


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def log(logf, msg: str) -> None:
    line = f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line)
    logf.parent.mkdir(parents=True, exist_ok=True)
    with open(logf, "a", encoding="utf-8") as f:
        f.write(line + "\n")


async def check_health(script_dir: Path, logf) -> tuple[str, int]:
    issues = 0
    for f in CRITICAL:
        if not (script_dir / f).is_file():
            issues += 1
            log(logf, f"WARNING: Critical file missing - {f}")
    r = await run_ps_command("Get-ExecutionPolicy")
    if "bypass" not in r.stdout.lower():
        issues += 1
        log(logf, "WARNING: PowerShell execution policy may block "
                  "scripts")
    if not is_admin():
        issues += 1
        log(logf, "WARNING: Not running with administrator privileges")
    return ("HEALTHY" if issues == 0 else "DEGRADED"), issues


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--interval", type=int, default=5)
    p.add_argument("--once", action="store_true",
                   help="single health check, no loop")
    p.add_argument("--script-dir", default=str(SCRIPT_DIR))
    args = p.parse_args()

    script_dir = Path(args.script_dir)
    logf = script_dir / "logs" / "real-time-monitor.log"
    log(logf, "Real-time monitor started")

    while True:
        status, issues = asyncio.run(check_health(script_dir, logf))
        print(f"Health Status: {status}\nIssues Detected: {issues}")
        if args.once:
            sys.exit(0 if issues == 0 else 1)
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
