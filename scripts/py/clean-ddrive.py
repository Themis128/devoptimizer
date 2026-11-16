"""D: drive cleanup (port of scripts/Clean-DDrive.ps1).

Deletes stale target folders (> --months-inactive since last write):
D:\\gdrive, D:\\tabby\\models\\TabbyML, D:\\eset,
D:\\AomeiDateBackupper11213, plus stale D:\\Nuxt Projects\\*
subfolders (--force or y-prompt). Logs to
D:\\DevOptimizer\\logs\\d-drive-cleanup-*.log. --dry-run; exit 2 on
errors.
"""

import argparse
import datetime
import os
import shutil
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: d-drive, stale-folders, nuxt

DEFAULT_TARGETS = {
    r"D:\gdrive": "Google Takeout ZIPs",
    r"D:\tabby\models\TabbyML": "Local LLM models",
    r"D:\eset": "ESET installer",
    r"D:\AomeiDateBackupper11213": "Aomei Backupper",
}
NUXT_ROOT = r"D:\Nuxt Projects"


def folder_size(path):
    total = 0
    for f in Path(path).rglob("*"):
        try:
            if f.is_file():
                total += f.stat().st_size
        except OSError:
            pass
    return round(total / 2**30, 2)


def last_write(path):
    try:
        return datetime.datetime.fromtimestamp(
            Path(path).stat().st_mtime)
    except OSError:
        return datetime.datetime.min


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--months-inactive", type=int, default=2)
    ap.add_argument("--target", action="append", default=[],
                    help="extra path=description pairs")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--log", default="")
    args = ap.parse_args()
    dry = args.dry_run

    targets = dict(DEFAULT_TARGETS)
    for t in args.target:
        k, _, v = t.partition("=")
        targets[k] = v or "custom folder"

    logp = Path(args.log or
                rf"D:\DevOptimizer\logs\d-drive-cleanup-"
                f"{datetime.datetime.now():%Y%m%d-%H%M%S}.log")

    def log(msg):
        line = f"[{datetime.datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
        print(line)
        if not dry:
            logp.parent.mkdir(parents=True, exist_ok=True)
            with open(logp, "a") as fh:
                fh.write(line + "\n")

    log("=== D: Drive Cleanup Started ===")
    log(f"Threshold: {args.months_inactive} months inactive; "
        f"DryRun: {dry}; Log: {logp}")

    cutoff = datetime.datetime.now() - datetime.timedelta(
        days=30 * args.months_inactive)
    freed = 0.0
    deleted, skipped, stale_nuxt = [], [], []

    for path, desc in targets.items():
        p = Path(path)
        if not p.exists():
            log(f"SKIP: {path} (not found) - {desc}")
            skipped.append(f"{path} (not found)")
            continue
        size = folder_size(p)
        lw = last_write(p)
        stale = lw < cutoff
        log(f"CHECK: {path} ({size} GB) - LastWrite: {lw:%Y-%m-%d} "
            f"- Stale: {stale} - {desc}")
        if stale and size > 0:
            if dry:
                log(f"DRY-RUN: Would delete {path} ({size} GB) - {desc}")
            else:
                log(f"DELETING: {path} ({size} GB) - {desc}")
                try:
                    shutil.rmtree(p)
                    freed += size
                    deleted.append(f"{path} ({size} GB) - {desc}")
                    log("  Deleted successfully")
                except OSError as e:
                    log(f"  ERROR: {e}")
                    skipped.append(f"{path} (error: {e})")
        else:
            skipped.append(f"{path} ({size} GB) - active or empty")

    log("\n=== Analyzing Nuxt Projects subfolders ===")
    nroot = Path(NUXT_ROOT)
    subs = [d for d in nroot.iterdir() if d.is_dir()] \
        if nroot.is_dir() else []
    for sub in subs:
        size = folder_size(sub)
        lw = last_write(sub)
        stale = lw < cutoff
        log(f"CHECK: {sub.name} ({size} GB) - LastWrite: {lw:%Y-%m-%d} "
            f"- Stale: {stale}")
        if stale and size > 0:
            stale_nuxt.append((sub, size))
    if stale_nuxt:
        log(f"=== Stale Nuxt Projects found ({len(stale_nuxt)}) ===")
        for sub, size in stale_nuxt:
            log(f"  {sub.name} - {size} GB")
        if dry:
            for sub, size in stale_nuxt:
                log(f"DRY-RUN: Would delete {sub.name} ({size} GB)")
        else:
            ok = args.force or (
                sys.stdin.isatty() and
                input(f"Delete {len(stale_nuxt)} stale Nuxt Projects? "
                      "(y/N) ").lower() == "y")
            for sub, size in stale_nuxt:
                if ok:
                    log(f"DELETING: {sub.name} ({size} GB)...")
                    try:
                        shutil.rmtree(sub)
                        freed += size
                        deleted.append(
                            f"{sub} ({size} GB) - Nuxt project")
                        log("  Deleted successfully")
                    except OSError as e:
                        log(f"  ERROR: {e}")
                        skipped.append(f"{sub} (error: {e})")
                else:
                    skipped.append(f"{sub} ({size} GB) - skipped by user")
            if not ok:
                log("Nuxt Projects deletion skipped by user")
    else:
        log("No stale Nuxt Projects found" if subs else
            "No Nuxt Projects found or not accessible")

    log("\n=== CLEANUP SUMMARY ===")
    log(f"Total freed: {round(freed, 2)} GB")
    log(f"Deleted ({len(deleted)}):")
    for d in deleted:
        log(f"  {d}")
    log(f"Skipped ({len(skipped)}):")
    for s in skipped:
        log(f"  {s}")
    try:
        du = shutil.disk_usage("D:\\")
        log(f"D: Final - Free: {du.free / 2**30:.2f} GB, "
            f"Used: {du.used / 2**30:.2f} GB")
    except OSError:
        pass
    log("=== D: Drive Cleanup Completed ===")
    sys.exit(2 if any("(error:" in s for s in skipped) else 0)


if __name__ == "__main__":
    main()
