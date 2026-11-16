"""Comprehensive 12-step system cleanup (port of
scripts/FIXED-SYSTEM-DEEP-CLEAN.ps1).

1 recycle bin, 2 temp folders, 3 browser caches, 4 dev caches,
5 WER (ProgramData), 6 thumbnail cache, 7 WU download cache
(service-stopped), 8 prefetch >30d, 9 Application/System/Security
event logs, 10 DNS flush, 11 Windows Store LocalCache, 12 cleanmgr
/sagerun:1. Warns when not elevated. Mutating; --dry-run.
"""

import argparse
import ctypes
import datetime
import glob
import os
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: deep-clean, system, temp, cache, event-log
# REQUIRES: admin

LA = os.environ.get("LOCALAPPDATA", "")
AD = os.environ.get("APPDATA", "")
TMP = os.environ.get("TEMP", "")
MB = 2**20


def ts():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def ok(msg):
    print(f"[{ts()}] [SUCCESS] {msg}")


def warn(msg):
    print(f"[{ts()}] [WARNING] {msg}")


def info(msg):
    print(f"[{ts()}] [INFO] {msg}")


def nuke(path, dry):
    """Remove contents of dir (or glob matches); return MB freed."""
    freed = 0
    p = Path(path)
    if not p.exists() and "*" not in path:
        return 0
    items = [Path(x) for x in glob.glob(path)] if "*" in path else \
        [p]
    for root in items:
        for f in root.rglob("*"):
            try:
                if f.is_file():
                    freed += f.stat().st_size
            except OSError:
                pass
        if not dry:
            if root.is_dir():
                for child in root.iterdir():
                    try:
                        if child.is_dir():
                            shutil.rmtree(child, ignore_errors=True)
                        else:
                            child.unlink()
                    except OSError:
                        pass
            elif root.is_file():
                try:
                    root.unlink()
                except OSError:
                    pass
    return freed / MB


def run(cmd, dry):
    if dry:
        print(f"[dry-run] {' '.join(str(c) for c in cmd)}")
        return 0
    return subprocess.run([str(c) for c in cmd],
                          capture_output=True).returncode


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run
    total = 0.0
    start = datetime.datetime.now()

    try:
        if not ctypes.windll.shell32.IsUserAnAdmin():
            warn("run as Administrator for best results")
    except Exception:
        pass

    info("Step 1/12: Emptying Recycle Bin...")
    run(["powershell", "-NoProfile", "-Command",
         "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"], dry)
    ok("Recycle Bin emptied")

    info("Step 2/12: Clearing Windows Temp folders...")
    for path in (TMP, rf"{LA}\Temp", r"C:\Windows\Temp",
                 r"C:\Windows\Logs"):
        s = nuke(path, dry)
        ok(f"Cleaned {path} : {s:.2f} MB")
        total += s

    info("Step 3/12: Clearing Browser Caches...")
    for path in (
            rf"{LA}\Google\Chrome\User Data\Default\Cache",
            rf"{LA}\Google\Chrome\User Data\Default\Code Cache",
            rf"{LA}\Microsoft\Edge\User Data\Default\Cache",
            rf"{LA}\Microsoft\Edge\User Data\Default\Code Cache",
            rf"{AD}\Mozilla\Firefox\Profiles\*\cache2"):
        s = nuke(path, dry)
        if s or Path(path.rstrip("*")).exists():
            ok(f"Cleaned {path} : {s:.2f} MB")
            total += s

    info("Step 4/12: Clearing Development Caches...")
    for path in (rf"{AD}\npm-cache", rf"{AD}\pnpm-cache",
                 rf"{AD}\yarn-cache", rf"{AD}\Code\CachedData",
                 rf"{AD}\Cursor\CachedData", rf"{AD}\Code\logs",
                 rf"{AD}\Cursor\logs"):
        s = nuke(path, dry)
        if Path(path).exists():
            ok(f"Cleaned {path} : {s:.2f} MB")
            total += s

    info("Step 5/12: Clearing Windows Error Reporting...")
    s = nuke(r"C:\ProgramData\Microsoft\Windows\WER", dry)
    ok(f"Cleaned WER : {s:.2f} MB")
    total += s

    info("Step 6/12: Clearing Thumbnail Cache...")
    for pat in (rf"{LA}\Microsoft\Windows\Explorer\thumbcache_*.db",
                rf"{LA}\Microsoft\Windows\Explorer\thumbcache_sr.db"):
        if dry:
            print(f"[dry-run] delete {pat}")
        else:
            for f in glob.glob(pat):
                try:
                    Path(f).unlink()
                except OSError:
                    pass
    ok("Thumbnail cache cleared")

    info("Step 7/12: Clearing Windows Update Cache...")
    run(["net", "stop", "wuauserv"], dry)
    s = nuke(r"C:\Windows\SoftwareDistribution\Download", dry)
    ok(f"Cleaned Windows Update Cache : {s:.2f} MB")
    total += s
    run(["net", "start", "wuauserv"], dry)

    info("Step 8/12: Clearing Prefetch (keeping recent)...")
    pf = Path(r"C:\Windows\Prefetch")
    cutoff = (datetime.datetime.now() -
              datetime.timedelta(days=30)).timestamp()
    s = 0
    for f in pf.glob("*") if pf.is_dir() else []:
        try:
            if f.is_file() and f.stat().st_mtime < cutoff:
                s += f.stat().st_size
                if not dry:
                    f.unlink()
        except OSError:
            pass
    ok(f"Cleaned old Prefetch files : {s / MB:.2f} MB")
    total += s / MB

    info("Step 9/12: Clearing System Event Logs...")
    for log_name in ("Application", "System", "Security"):
        run(["powershell", "-NoProfile", "-Command",
             f"Clear-EventLog -LogName {log_name} "
             "-ErrorAction SilentlyContinue"], dry)
        ok(f"Cleared {log_name} event log")

    info("Step 10/12: Clearing DNS Cache...")
    run(["ipconfig", "/flushdns"], dry)
    ok("DNS cache flushed")

    info("Step 11/12: Clearing Windows Store Cache...")
    s = nuke(rf"{LA}\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe"
             r"\LocalCache", dry)
    ok(f"Cleaned Windows Store Cache : {s:.2f} MB")
    total += s

    info("Step 12/12: Running Disk Cleanup...")
    run([r"C:\Windows\System32\cleanmgr.exe", "/sagerun:1"], dry)
    ok("Disk cleanup completed")

    elapsed = (datetime.datetime.now() - start).total_seconds()
    print("=" * 64)
    ok(f"Cleanup finished in {elapsed:.0f}s - "
       f"total freed ~{total:.1f} MB "
       f"({'dry-run' if dry else 'applied'})")


if __name__ == "__main__":
    main()
