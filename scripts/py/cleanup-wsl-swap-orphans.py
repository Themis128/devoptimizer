"""Port of scripts/cleanup-wsl-swap-orphans.ps1.

Reaps orphaned swap.vhdx in %TEMP%\\<GUID>\\ left by crashed WSL
VMs. Aged files (> MinAgeHours) are candidates; fresh files only
when an exclusive-open probe proves them unlocked. The live VM's
swap is hypervisor-locked so delete fails and it is skipped.
"""

import argparse
import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

LOG = Path("D:/DevOptimizer/logs/wsl-swap-reaper.log")
GUID = re.compile(
    r"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$")


def log(msg):
    try:
        LOG.parent.mkdir(exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}\n")
    except OSError:
        pass


def locked(path):
    """True if the file cannot be opened exclusively (live VM)."""
    try:
        with open(path, "r+b"):
            return False
    except OSError:
        return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-MinAgeHours", type=int, default=2)
    ap.add_argument("-DryRun", action="store_true")
    a = ap.parse_args()

    cutoff = datetime.now() - timedelta(hours=a.MinAgeHours)
    roots = []
    for r in (os.environ.get("TEMP"),
              r"C:\Users\tbaltzakis\AppData\Local\Temp"):
        if r and os.path.isdir(r) and r not in roots:
            roots.append(r)

    dirs = []
    for root in roots:
        try:
            for e in os.scandir(root):
                if e.is_dir() and GUID.match(e.name):
                    dirs.append(e.path)
        except OSError:
            continue

    reaped = skipped = 0
    reclaimed = 0
    for d in dirs:
        swap = Path(d) / "swap.vhdx"
        if not swap.exists():
            continue
        try:
            st = swap.stat()
        except OSError:
            skipped += 1
            continue
        fresh_orphan = False
        if datetime.fromtimestamp(st.st_mtime) > cutoff:
            if locked(swap):
                skipped += 1
                continue
            fresh_orphan = True
        mb = round(st.st_size / 2**20)
        if a.DryRun:
            log(f"DRYRUN would reap {Path(d).name} swap.vhdx "
                f"{mb} MB (last write "
                f"{datetime.fromtimestamp(st.st_mtime)})")
            reclaimed += st.st_size
            reaped += 1
            continue
        try:
            swap.unlink()
        except OSError as e:
            skipped += 1
            log(f"skip {Path(d).name} swap.vhdx {mb} MB - {e}")
            continue
        reclaimed += st.st_size
        reaped += 1
        how = "fresh-orphan (unlocked)" if fresh_orphan \
            else "aged"
        log(f"reaped {Path(d).name} swap.vhdx {mb} MB "
            f"({how}, last write "
            f"{datetime.fromtimestamp(st.st_mtime)})")
        try:
            if not any(os.scandir(d)):
                os.rmdir(d)
        except OSError:
            pass

    if reaped:
        log(f"done: reaped {reaped} file(s), reclaimed "
            f"{reclaimed / 2**30:.1f} GB, skipped {skipped}")
    else:
        log(f"done: no orphans (skipped {skipped} fresh/locked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
