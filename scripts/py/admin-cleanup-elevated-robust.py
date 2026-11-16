"""Robust elevated admin cleanup (port of
scripts/admin-cleanup-elevated-robust.ps1).

DISM RestoreHealth then StartComponentCleanup /ResetBase, WU cache
(service-stopped), Delivery Optimization cache, ALL-but-newest shadow
copies, system temp, recycle bin (all users via Shell.Application),
thumbcache/iconcache, crash dumps + WER, Windows.old. Continues on
partial failure; logs to
D:\\DevOptimizer\\logs\\admin-cleanup-robust-*.log. Elevated; --dry-run.
"""

import argparse
import ctypes
import datetime
import glob
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: windows11, robust, dism, shadow-copies, wer, recycle-bin

LOG_DIR = Path(r"D:\DevOptimizer\logs")


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def gb(b):
    return round(b / 2**30, 2)


def mb(b):
    return round(b / 2**20, 1)


def dir_size(path):
    total = 0
    for f in Path(path).rglob("*"):
        try:
            if f.is_file():
                total += f.stat().st_size
        except OSError:
            pass
    return total


def clear(path):
    for f in Path(path).iterdir():
        try:
            if f.is_dir():
                shutil.rmtree(f, ignore_errors=True)
            else:
                f.unlink()
        except OSError:
            pass


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--admin", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run
    if args.admin and not (is_admin() or dry):
        sys.exit("This script requires Administrator privileges.")

    logf = LOG_DIR / ("admin-cleanup-robust-"
                      f"{datetime.datetime.now():%Y%m%d-%H%M%S}.log")

    def log(msg):
        line = f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {msg}"
        print(line)
        if not dry:
            LOG_DIR.mkdir(parents=True, exist_ok=True)
            with open(logf, "a") as fh:
                fh.write(line + "\n")

    def run(cmd, echo=True):
        if dry:
            print(f"[dry-run] {' '.join(str(c) for c in cmd)}")
            return 0, ""
        r = subprocess.run([str(c) for c in cmd], capture_output=True,
                           text=True, errors="replace")
        out = r.stdout + r.stderr
        if echo:
            for ln in out.splitlines():
                if ln.strip():
                    log(f"  {ln.strip()}")
        return r.returncode, out

    before = shutil.disk_usage("C:\\").free
    log("=== Robust Admin Cleanup Started ===")
    log(f"C: free before: {gb(before)} GB")

    log("--- [1] DISM RestoreHealth + Component Cleanup ---")
    try:
        log("Running: Dism /Online /Cleanup-Image /RestoreHealth")
        rc, _ = run(["Dism", "/Online", "/Cleanup-Image",
                     "/RestoreHealth", "/NoRestart"])
        if rc != 0:
            log(f"WARN: RestoreHealth exit {rc} (may be benign)")
        log("Running: Dism /Online /Cleanup-Image "
            "/StartComponentCleanup /ResetBase")
        rc, _ = run(["Dism", "/Online", "/Cleanup-Image",
                     "/StartComponentCleanup", "/ResetBase",
                     "/NoRestart"])
        log("[1] DISM: COMPLETED" if rc == 0 else
            f"WARN: StartComponentCleanup exit {rc}")
    except Exception as e:
        log(f"ERR DISM: {e}")

    log("--- [2] Windows Update Download Cache ---")
    wu = Path(r"C:\Windows\SoftwareDistribution\Download")
    try:
        if wu.is_dir() or dry:
            s0 = dir_size(wu) if not dry else 0
            run(["net", "stop", "wuauserv"], echo=False)
            if not dry:
                clear(wu)
            run(["net", "start", "wuauserv"], echo=False)
            s1 = dir_size(wu) if not dry else 0
            log(f"[2] Windows Update cache: cleaned {gb(s0 - s1)} GB")
        else:
            log("[2] Windows Update cache: path not found")
    except Exception as e:
        log(f"WARN WU cache: {e}")

    log("--- [3] Delivery Optimization Cache ---")
    do = Path(os.environ.get("LOCALAPPDATA", "")) / \
        "Microsoft/Windows/DeliveryOptimization"
    try:
        if do.is_dir() or dry:
            size = dir_size(do) if not dry else 0
            if dry:
                print(f"[dry-run] rm -rf {do}")
            else:
                shutil.rmtree(do, ignore_errors=True)
            log(f"[3] Delivery Optimization: cleaned {mb(size)} MB")
        else:
            log("[3] Delivery Optimization: not found")
    except Exception as e:
        log(f"WARN DO cache: {e}")

    log("--- [4] Shadow Copies (all old) ---")
    try:
        if dry:
            print("[dry-run] vssadmin list/delete shadows /for=c:")
        else:
            rc, out = run(["vssadmin", "list", "shadows", "/for=c:"])
            count = len(re.findall(r"Shadow Copy ID", out))
            if count > 1:
                for i in range(count - 1):
                    log(f"Deleting oldest shadow copy "
                        f"({i + 1}/{count - 1})...")
                    run(["vssadmin", "delete", "shadows", "/for=c:",
                         "/oldest", "/quiet"])
                log(f"[4] Shadow copies: deleted {count - 1} old "
                    "copies")
            elif count == 1:
                log("[4] Shadow copies: only 1 (kept)")
            else:
                log("[4] Shadow copies: none found")
    except Exception as e:
        log(f"WARN VSS: {e}")

    log("--- [5] System Temp (C:\\Windows\\Temp) ---")
    try:
        tp = Path(r"C:\Windows\Temp")
        if tp.is_dir() or dry:
            s0 = dir_size(tp) if not dry else 0
            if not dry:
                clear(tp)
            s1 = dir_size(tp) if not dry else 0
            log(f"[5] System Temp: cleaned {mb(s0 - s1)} MB")
    except Exception as e:
        log(f"WARN System Temp: {e}")

    log("--- [6] Recycle Bin (all users) ---")
    try:
        if dry:
            print("[dry-run] Shell.Application Recycle Bin purge")
        else:
            rc, out = run(
                ["powershell", "-NoProfile", "-Command",
                 "$s = New-Object -ComObject Shell.Application; "
                 "$r = $s.Namespace(0x0a); "
                 "if ($r) { $n = $r.Items().Count; "
                 "$r.Items() | ForEach-Object { "
                 "$_.InvokeVerb('Delete') }; "
                 "Write-Host \"emptied $n items\" } else { "
                 "Write-Host 'no bin' }"])
            log(f"[6] Recycle Bin: {out.strip()}")
    except Exception as e:
        log(f"WARN Recycle Bin: {e}")

    log("--- [7] Thumbnail Cache ---")
    try:
        la = os.environ.get("LOCALAPPDATA", "")
        for pat in (rf"{la}\Microsoft\Windows\Explorer\thumbcache_*.db",
                    rf"{la}\Microsoft\Windows\Explorer\iconcache_*.db"):
            for f in glob.glob(pat):
                if dry:
                    print(f"[dry-run] del {f}")
                else:
                    try:
                        os.remove(f)
                    except OSError:
                        pass
        log("[7] Thumbnail/Icon cache: cleared")
    except Exception as e:
        log(f"WARN Thumbnails: {e}")

    log("--- [8] Crash Dumps & WER ---")
    la = os.environ.get("LOCALAPPDATA", "")
    for w in (r"C:\Windows\Minidump", r"C:\Windows\MEMORY.DMP",
              rf"{la}\CrashDumps",
              r"C:\ProgramData\Microsoft\Windows\WER"):
        wp = Path(w)
        try:
            if wp.is_dir():
                size = dir_size(wp)
                if size > 0 and not dry:
                    clear(wp)
                log(f"[8] {wp.name}: -{mb(size)} MB")
            elif wp.is_file() and not dry:
                wp.unlink(missing_ok=True)
        except Exception as e:
            log(f"WARN {w}: {e}")

    log("--- [9] Windows.old ---")
    try:
        win_old = Path(r"C:\Windows.old")
        if win_old.is_dir() or dry:
            size = dir_size(win_old) if not dry else 0
            run(["Dism", "/Online", "/Cleanup-Image",
                 "/StartComponentCleanup", "/NoRestart"], echo=False)
            if not dry:
                shutil.rmtree(win_old, ignore_errors=True)
            log(f"[9] Windows.old: removed {gb(size)} GB")
        else:
            log("[9] Windows.old: not found")
    except Exception as e:
        log(f"WARN Windows.old: {e}")

    after = shutil.disk_usage("C:\\").free
    log("=== Summary ===")
    log(f"C: free before: {gb(before)} GB")
    log(f"C: free after : {gb(after)} GB")
    log(f"Freed on C:   : {gb(after - before)} GB")
    log(f"Log saved to: {logf}")


if __name__ == "__main__":
    main()
