"""Win11 OS-level deep cleanup (port of scripts/win11-os-deep-cleanup.ps1).

Removes C:\\Windows.old (takeown/icacls/rd passes), leftover upgrade
folders, disables hibernation, runs DISM analyze+cleanup, clears >30d
system logs and the WU download cache. Logs to logs\\os-cleanup-*.log.
Requires elevation. Mutating; --dry-run.
"""

import argparse
import datetime
import os
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: windows11, dism, hibernation, windows-old, system-logs

LOG_DIR = Path(r"D:\DevOptimizer\logs")


def free_gb() -> float:
    return round(shutil.disk_usage("C:\\").free / 2**30, 2)


def log(lf, msg):
    line = f"{datetime.datetime.now():%H:%M:%S} {msg}"
    print(line)
    try:
        with open(lf, "a") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def run(cmd, dry, logf=None, show=True):
    if dry:
        print(f"[dry-run] {' '.join(str(c) for c in cmd)}")
        return 0
    r = subprocess.run([str(c) for c in cmd], capture_output=True,
                       text=True, errors="replace")
    if show and logf:
        for ln in (r.stdout + r.stderr).splitlines():
            if ln.strip():
                log(logf, f"  {ln.strip()}")
    return r.returncode


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    dry = args.dry_run

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logf = LOG_DIR / ("os-cleanup-"
                      f"{datetime.datetime.now():%Y%m%d-%H%M%S}.log")
    log(logf, "=== Win11 OS deep cleanup start ===")
    log(logf, f"C: free before: {free_gb()} GB")

    win_old = Path("C:\\Windows.old")
    if win_old.exists() or dry:
        log(logf, "Removing C:\\Windows.old (takeown + icacls + rd "
            "passes)...")
        for ps_ in range(1, 6):
            run(["takeown.exe", "/f", r"C:\Windows.old", "/r", "/d", "y",
                 "/a"], dry, logf, show=False)
            run(["icacls.exe", r"C:\Windows.old", "/grant",
                 "administrators:F", "/t", "/c", "/q"], dry, logf,
                show=False)
            run(["icacls.exe", r"C:\Windows.old", "/grant", "SYSTEM:F",
                 "/t", "/c", "/q"], dry, logf, show=False)
            log(logf, f"rd pass {ps_} on C:\\Windows.old")
            run(["cmd.exe", "/c", "rd", "/s", "/q", r"C:\Windows.old"],
                dry, logf)
            if dry or not win_old.exists():
                break
        log(logf, "Windows.old: " +
            ("PARTIAL - TrustedInstaller files remain; run Disk Cleanup "
             "or winold-delete-worker2.ps1 as SYSTEM"
             if win_old.exists() else "removed"))
    else:
        log(logf, "Windows.old: not present")
    log(logf, f"C: free after Windows.old: {free_gb()} GB")

    for pdir in (r"C:\$WINDOWS.~BT", r"C:\$WinREAgent",
                 r"C:\Windows10Upgrade", r"C:\$GetCurrent"):
        if Path(pdir).exists() or dry:
            log(logf, f"Removing leftover upgrade folder {pdir}")
            run(["takeown.exe", "/f", pdir, "/r", "/d", "y"], dry,
                logf, show=False)
            run(["icacls.exe", pdir, "/grant", "administrators:F", "/t",
                 "/c", "/q"], dry, logf, show=False)
            if not dry:
                shutil.rmtree(pdir, ignore_errors=True)

    log(logf, "Disabling hibernation (powercfg /h off)...")
    run(["powercfg.exe", "/h", "off"], dry, logf)
    log(logf, f"C: free after hibernation off: {free_gb()} GB")

    log(logf, "DISM AnalyzeComponentStore...")
    run(["dism.exe", "/Online", "/Cleanup-Image",
         "/AnalyzeComponentStore"], dry, logf)
    log(logf, "DISM StartComponentCleanup (can take 10-60 min)...")
    run(["dism.exe", "/Online", "/Cleanup-Image",
         "/StartComponentCleanup"], dry, logf)
    log(logf, f"C: free after DISM cleanup: {free_gb()} GB")

    cutoff = datetime.datetime.now() - datetime.timedelta(days=30)
    freed = 0
    for t in (r"C:\Windows\Logs", r"C:\Windows\System32\LogFiles",
              r"C:\Windows\Panther", r"C:\Windows\inf\setupapi.dev.log"):
        tp = Path(t)
        if dry:
            print(f"[dry-run] purge >30d files under {t}")
            continue
        if tp.is_dir():
            for f in tp.rglob("*"):
                try:
                    if (f.is_file() and f.stat().st_size > 0 and
                            datetime.datetime.fromtimestamp(
                                f.stat().st_mtime) < cutoff):
                        freed += f.stat().st_size
                        f.unlink()
                except OSError:
                    pass
        elif tp.is_file():
            try:
                st = tp.stat()
                if datetime.datetime.fromtimestamp(st.st_mtime) < cutoff:
                    freed += st.st_size
                    tp.unlink()
            except OSError:
                pass
    log(logf, f"System logs >30d removed: {freed / 2**20:.1f} MB")

    wu = Path(r"C:\Windows\SoftwareDistribution\Download")
    if wu.is_dir() or dry:
        if dry:
            print(f"[dry-run] clear {wu}")
        else:
            for f in wu.iterdir():
                try:
                    if f.is_dir():
                        shutil.rmtree(f, ignore_errors=True)
                    else:
                        f.unlink()
                except OSError:
                    pass
        log(logf, "Windows Update download cache cleared")

    log(logf, f"C: free final: {free_gb()} GB")
    log(logf, "=== Win11 OS deep cleanup done ===")


if __name__ == "__main__":
    main()
