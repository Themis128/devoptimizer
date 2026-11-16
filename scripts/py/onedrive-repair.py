"""Port of scripts/onedrive-repair.ps1 — OneDrive reparse point repair
for 0x80071128/0x80071129 errors. Scans OneDrive folder(s) for broken
reparse points, quarantines them (recreating dir placeholders), and
clears the Files On-Demand cache via `attrib -U -P`.
--preview lists broken items without moving; --quarantine-only skips
the cache clear.
"""
import argparse
import ctypes
import datetime
import os
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: onedrive, reparse, repair

FILE_ATTRIBUTE_REPARSE_POINT = 0x400


def log(msg, log_file=None):
    line = f"[{datetime.datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line)
    if log_file:
        try:
            with open(log_file, "a", encoding="utf-8") as f:
                f.write(line + "\n")
        except OSError:
            pass


def ensure_cloud_files_filter(lf):
    """cldflt service must be running."""
    r = subprocess.run(["sc", "query", "cldflt"], capture_output=True,
                       text=True)
    if "RUNNING" in (r.stdout or ""):
        return True
    log("[WARNING] Cloud Files filter driver not running", lf)
    r2 = subprocess.run(["net", "start", "cldflt"],
                        capture_output=True)
    if r2.returncode == 0:
        log("[SUCCESS] Cloud Files filter driver started", lf)
        return True
    log("[ERROR] Failed to start Cloud Files filter driver", lf)
    return False


def _is_reparse(path):
    try:
        attrs = ctypes.windll.kernel32.GetFileAttributesW(str(path))
        return attrs != -1 and bool(attrs & FILE_ATTRIBUTE_REPARSE_POINT)
    except Exception:
        return False


def scan_broken(root, lf):
    """Reparse points under root that fail basic access."""
    log(f"[INFO] Scanning for reparse points in: {root}", lf)
    reparse, broken = [], []
    try:
        for dirpath, dirnames, filenames in os.walk(root):
            for n in dirnames + filenames:
                p = Path(dirpath) / n
                if _is_reparse(p):
                    reparse.append(p)
    except OSError as e:
        log(f"[ERROR] Failed to scan reparse points: {e}", lf)
    log(f"[INFO] Found {len(reparse)} reparse points", lf)
    for p in reparse:
        try:
            os.stat(p)
            list(p.iterdir()) if p.is_dir() else p.read_bytes()[:0]
        except OSError:
            broken.append(p)
            log(f"[WARNING] Broken reparse point detected: {p}", lf)
    log(f"[RESULT] Total reparse points: {len(reparse)}", lf)
    log(f"[RESULT] Broken reparse points: {len(broken)}", lf)
    return broken


def quarantine(item, qdir, lf):
    qdir.mkdir(parents=True, exist_ok=True)
    dest = qdir / item.name
    i = 1
    while dest.exists():
        dest = qdir / f"{item.stem}-{i}{item.suffix}"
        i += 1
    try:
        shutil.move(str(item), str(dest))
        log(f"[SUCCESS] Quarantined: {item} -> {dest}", lf)
        if item.is_dir() or _is_reparse(item):
            try:
                item.mkdir(parents=True, exist_ok=True)
                log(f"[INFO] Recreated directory placeholder: {item}",
                    lf)
            except OSError:
                pass
        return True
    except OSError as e:
        log(f"[ERROR] Failed to quarantine {item}: {e}", lf)
        return False


def clear_fod_cache(path, lf):
    log(f"[INFO] Clearing Files On-Demand cache for: {path}", lf)
    r = subprocess.run(
        ["cmd", "/c", f'attrib -U -P /S /D "{path}\\*"'],
        capture_output=True)
    if r.returncode == 0:
        log("[SUCCESS] Files On-Demand cache cleared", lf)
    else:
        log(f"[WARNING] Some files may not have been processed "
            f"(exit code: {r.returncode})", lf)


def main():
    ap = argparse.ArgumentParser(
        description="OneDrive reparse point repair")
    ap.add_argument("--target-path", required=True,
                    help="OneDrive root to repair")
    ap.add_argument("--log-file", default="")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--quarantine-only", action="store_true")
    args = ap.parse_args()
    lf = args.log_file or None

    log("[INFO] OneDrive Reparse Point Repair Started", lf)
    if not ensure_cloud_files_filter(lf):
        log("[ERROR] Cannot proceed without Cloud Files filter", lf)
        return 1

    paths = []
    tp = Path(args.target_path)
    if tp.is_dir():
        paths.append(tp)
    for d in sorted(tp.parent.glob("OneDrive - *")):
        if d.is_dir():
            paths.append(d)
    log(f"[INFO] Processing {len(paths)} OneDrive account(s)", lf)

    for path in paths:
        broken = scan_broken(path, lf)
        if args.preview:
            for b in broken:
                print(f"  [preview] would quarantine: {b}")
            continue
        qdir = path / "_OneDrive_ReparseFix_Quarantine"
        for b in broken:
            quarantine(b, qdir, lf)
        if not args.quarantine_only:
            clear_fod_cache(path, lf)

    log("[SUCCESS] OneDrive reparse point repair completed "
        "successfully", lf)
    log("[INFO] Please restart OneDrive to complete the repair", lf)
    return 0


if __name__ == "__main__":
    sys.exit(main())
