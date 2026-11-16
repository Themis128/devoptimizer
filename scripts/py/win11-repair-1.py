"""Port of scripts/win11-repair.ps1 — elevated Windows 11 repair:
disable orphaned PRI-Driver service, DISM RestoreHealth, sfc /scannow,
read-only chkdsk C: /scan. Transcript to logs + .done marker.
"""
# REQUIRES: admin

import datetime
import subprocess
import sys
from pathlib import Path

# CATEGORY: maintenance
# TAGS: repair, dism, sfc, windows11

LOG_DIR = Path(r"D:\DevOptimizer\logs")
LOG_FILE = LOG_DIR / "win11-repair-20260906.log"
DONE_FILE = LOG_DIR / "win11-repair-20260906.done"


def log(msg):
    line = f"[{datetime.datetime.now():%H:%M:%S}] {msg}"
    print(line)
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def run(cmd, timeout=None):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=timeout)
        for ln in (r.stdout or "").splitlines():
            log(ln)
        return r.returncode
    except (OSError, subprocess.TimeoutExpired) as e:
        log(f"{cmd[0]} failed: {e}")
        return 1


def main():
    log("=== Windows 11 repair started ===")

    log("Disabling orphaned PRI-Driver service (driver file missing)...")
    log(f"PRI-Driver config exit: "
        f"{run(['sc.exe', 'config', 'PRI-Driver', 'start=', 'disabled'])}")

    log("Running DISM /RestoreHealth (5-20 minutes)...")
    log(f"DISM RestoreHealth exit: "
        f"{run(['dism', '/Online', '/Cleanup-Image', '/RestoreHealth'], timeout=3600)}")

    log("Running sfc /scannow (5-15 minutes)...")
    log(f"SFC exit: {run(['sfc', '/scannow'], timeout=2400)}")

    log("Running chkdsk C: /scan (read-only)...")
    log(f"chkdsk exit: {run(['chkdsk', 'C:', '/scan'], timeout=1800)}")

    log("PRI-Driver state after fix:")
    run(["sc.exe", "query", "PRI-Driver"])

    log("=== Windows 11 repair complete ===")
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        DONE_FILE.write_text(datetime.datetime.now().isoformat(),
                             encoding="utf-8")
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
