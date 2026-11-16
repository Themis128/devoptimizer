"""SYSTEM-account admin cleanup (port of
scripts/admin-cleanup-system.ps1).

DISM cleanup + ResetBase, WU cache, Delivery Optimization cache,
oldest shadow copy, Windows.old, WER report dirs, system temp
(Windows\\Temp + Prefetch). Alerts via lib\\Notify.ps1
Send-DevOptAlert on failures. Logs to
D:\\DevOptimizer\\logs\\admin-cleanup-system.log. Elevated/SYSTEM.
Mutating; --dry-run.
"""

import argparse
import asyncio
import datetime
import glob
import os
import shutil
import subprocess
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: cleanup
# TAGS: windows11, system, dism, wer, prefetch, scheduled-task

LOG_FILE = Path(r"D:\DevOptimizer\logs\admin-cleanup-system.log")
NOTIFY_PS = _REPO_ROOT / "scripts" / "lib" / "Notify.ps1"


def mb(b):
    return round(b / 2**20, 1)


def gb(b):
    return round(b / 2**30, 2)


def log(msg):
    line = f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {msg}"
    print(line)
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_FILE, "a") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def alert(title, msg, tags, event_id, dry):
    if dry:
        print(f"[dry-run] alert {event_id}: {title}")
        return
    t = ", ".join(f"'{x}'" for x in tags)
    m = msg.replace("'", "''")[:400]
    asyncio.run(run_ps_command(
        f". '{NOTIFY_PS}'; Send-DevOptAlert -Severity Warning "
        f"-Title '{title}' -Message '{m}' -Tags {t} "
        f"-EventId {event_id} -ErrorAction SilentlyContinue"))


def run(cmd, dry, echo=True):
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
    args = ap.parse_args()
    dry = args.dry_run

    before = shutil.disk_usage("C:\\").free
    log("=== Admin Cleanup (SYSTEM) ===")
    log(f"C: free before: {gb(before)} GB")

    log("\n--- [1] DISM Component Store Cleanup ---")
    rc, out = run(["Dism", "/Online", "/Cleanup-Image",
                   "/StartComponentCleanup", "/NoRestart"], dry)
    if rc == 0:
        log("[1] DISM cleanup: COMPLETED")
    else:
        log(f"[1] DISM cleanup: EXIT CODE {rc}")
        alert("Admin Cleanup (SYSTEM): DISM Failed",
              f"DISM /StartComponentCleanup exited {rc}. "
              f"Output: {out}", ["cleanup", "dism", "system"], 1005,
              dry)

    log("\n--- [2] DISM ResetBase ---")
    rc, _ = run(["Dism", "/Online", "/Cleanup-Image",
                 "/StartComponentCleanup", "/ResetBase", "/NoRestart"],
                dry)
    log(f"[2] DISM ResetBase: "
        f"{'COMPLETED' if rc == 0 else f'EXIT CODE {rc}'}")

    log("\n--- [3] Windows Update download cache ---")
    wu = Path(r"C:\Windows\SoftwareDistribution\Download")
    if wu.is_dir() or dry:
        size = dir_size(wu) if not dry else 0
        run(["net", "stop", "wuauserv"], dry, echo=False)
        if dry:
            print(f"[dry-run] clear {wu}")
        else:
            clear(wu)
        run(["net", "start", "wuauserv"], dry, echo=False)
        log(f"[3] WU cache cleaned: -{gb(size)} GB")
    else:
        log("[3] WU cache: not found")

    do = Path(os.environ.get("LOCALAPPDATA", "")) / \
        "Microsoft/Windows/DeliveryOptimization"
    try:
        if do.is_dir() or dry:
            size = dir_size(do) if not dry else 0
            log(f"Removing Delivery Optimization cache "
                f"({size / 2**20:.1f} MB)...")
            if dry:
                print(f"[dry-run] rm -rf {do}")
            else:
                shutil.rmtree(do, ignore_errors=True)
            log("[4] Delivery Optimization cache: CLEARED")
        else:
            log("[4] Delivery Optimization cache: not found")
    except OSError as e:
        log(f"[4] Delivery Optimization cache: SKIPPED ({e})")
        alert("Admin Cleanup (SYSTEM): DO Cache Failed", str(e),
              ["cleanup", "delivery-optimization", "system"], 1007,
              dry)

    log("\n--- [5] Shadow Copies (oldest) ---")
    rc, out = run(["vssadmin", "delete", "shadows", "/for=c:",
                   "/oldest", "/quiet"], dry)
    if rc == 0:
        log("[5] Oldest shadow copy: DELETED")
    else:
        log(f"[5] Shadow copy: EXIT CODE {rc}")
        if not any(x in out.lower()
                   for x in ("no items", "no shadows",
                             "nothing to delete")):
            alert("Admin Cleanup (SYSTEM): Shadow Copy Failed",
                  f"vssadmin exited {rc}. Output: {out}",
                  ["cleanup", "vss", "system"], 1006, dry)

    win_old = Path(r"C:\Windows.old")
    log("\n--- [6] Windows.old folder (if present) ---")
    if win_old.is_dir() or dry:
        size = dir_size(win_old) if not dry else 0
        log(f"Found Windows.old ({gb(size)} GB) - removing...")
        run(["takeown", "/f", r"C:\Windows.old", "/r", "/d", "y"],
            dry, echo=False)
        run(["icacls", r"C:\Windows.old", "/grant",
             "administrators:F", "/t", "/c", "/q"], dry, echo=False)
        if not dry:
            shutil.rmtree(win_old, ignore_errors=True)
        log(f"[6] Windows.old removed: -{gb(size)} GB")
    else:
        log("[6] Windows.old: not found")

    log("\n--- [7] Windows Error Reporting (WER) ---")
    wer_paths = [
        r"C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
        r"C:\ProgramData\Microsoft\Windows\WER\ReportQueue"]
    wer_paths += glob.glob(
        r"C:\Users\*\AppData\Local\Microsoft\Windows\WER\ReportArchive")
    wer_paths += glob.glob(
        r"C:\Users\*\AppData\Local\Microsoft\Windows\WER\ReportQueue")
    wer_total = 0
    for wp in wer_paths:
        if Path(wp).is_dir():
            size = dir_size(wp)
            wer_total += size
            if size > 0 and not dry:
                log(f"Clearing {wp} ({size / 2**20:.1f} MB)...")
                clear(wp)
    log(f"[7] WER reports cleaned: -{mb(wer_total)} MB")

    log("\n--- [8] System temp files ---")
    temp_total = 0
    for tp in (r"C:\Windows\Temp", r"C:\Windows\Prefetch"):
        if Path(tp).is_dir():
            size = dir_size(tp)
            temp_total += size
            if size > 0 and not dry:
                log(f"Clearing {tp} ({size / 2**20:.1f} MB)...")
                clear(tp)
    log(f"[8] System temp cleaned: -{mb(temp_total)} MB")

    after = shutil.disk_usage("C:\\").free
    log("\n=== Summary ===")
    log(f"C: free before: {before / 2**30:.2f} GB")
    log(f"C: free after : {after / 2**30:.2f} GB")
    log(f"Freed on C:   : {(after - before) / 2**30:.2f} GB")
    log("Done. A reboot is recommended after DISM operations.")


if __name__ == "__main__":
    main()
