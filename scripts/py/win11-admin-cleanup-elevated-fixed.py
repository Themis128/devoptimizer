"""Elevated Win11 admin cleanup (port of
scripts/win11-admin-cleanup-elevated-fixed.ps1).

DISM StartComponentCleanup + RestoreHealth, SFC /scannow, WU download
cache (service-stopped), Delivery Optimization cache, oldest shadow
copy, Windows.old. Requires admin. Mutating; --dry-run.
"""

import argparse
import ctypes
import os
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: windows11, admin, dism, sfc, wu, shadow-copies


def gb(b):
    return round(b / 2**30, 2)


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def free_c():
    return shutil.disk_usage("C:\\").free


def run(cmd, dry, echo=True):
    if dry:
        print(f"[dry-run] {' '.join(str(c) for c in cmd)}")
        return 0
    r = subprocess.run([str(c) for c in cmd], capture_output=True,
                       text=True, errors="replace")
    if echo:
        for ln in (r.stdout + r.stderr).splitlines():
            if ln.strip():
                print(f"  {ln.strip()}")
    return r.returncode


def dir_size(path):
    total = 0
    for f in Path(path).rglob("*"):
        try:
            if f.is_file():
                total += f.stat().st_size
        except OSError:
            pass
    return total


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--admin", action="store_true",
                   help="assert elevation (original hard-requires it)")
    args = p.parse_args()
    dry = args.dry_run
    if args.admin and not (is_admin() or dry):
        print("[ERROR] Must run as Administrator!", file=sys.stderr)
        sys.exit(1)

    before = free_c()
    print("=== Windows 11 Admin Cleanup ===")
    print(f"C: free before: {gb(before)} GB")

    print("\n--- [1] DISM Component Store Cleanup ---")
    rc = run(["Dism", "/Online", "/Cleanup-Image",
              "/StartComponentCleanup", "/NoRestart"], dry)
    print(f"[1] DISM component cleanup: "
          f"{'COMPLETED' if rc == 0 else f'EXIT CODE {rc}'}")

    print("\n--- [2] DISM RestoreHealth (Repair) ---")
    print("This may take 10-30 minutes...")
    rc = run(["Dism", "/Online", "/Cleanup-Image", "/RestoreHealth"],
             dry)
    print(f"[2] DISM RestoreHealth: "
          f"{'COMPLETED' if rc == 0 else f'EXIT CODE {rc}'}")

    print("\n--- [3] SFC /scannow ---")
    rc = run(["sfc", "/scannow"], dry)
    print(f"[3] SFC: {'COMPLETED' if rc == 0 else f'EXIT CODE {rc}'}")

    print("\n--- [4] Windows Update Download Cache ---")
    wu = Path(r"C:\Windows\SoftwareDistribution\Download")
    if wu.is_dir() or dry:
        size = dir_size(wu) if not dry else 0
        run(["net", "stop", "wuauserv"], dry, echo=False)
        if dry:
            print(f"[dry-run] clear {wu} ({gb(size)} GB)")
        else:
            for f in wu.iterdir():
                try:
                    if f.is_dir():
                        shutil.rmtree(f, ignore_errors=True)
                    else:
                        f.unlink()
                except OSError:
                    pass
        run(["net", "start", "wuauserv"], dry, echo=False)
        print(f"[4] Windows Update cache cleaned: -{gb(size)} GB")
    else:
        print("[4] Windows Update cache: not found")

    print("\n--- [5] Delivery Optimization Cache ---")
    do = Path(os.environ.get("LOCALAPPDATA", "")) / \
        "Microsoft/Windows/DeliveryOptimization"
    if do.is_dir() or dry:
        size = dir_size(do) if not dry else 0
        if dry:
            print(f"[dry-run] clear {do} ({size / 2**20:.1f} MB)")
        else:
            shutil.rmtree(do, ignore_errors=True)
        print("[5] Delivery Optimization cache: CLEARED")
    else:
        print("[5] Delivery Optimization cache: not found")

    print("\n--- [6] Shadow Copies (oldest) ---")
    rc = run(["vssadmin", "delete", "shadows", "/for=c:", "/oldest",
              "/quiet"], dry)
    print(f"[6] Oldest shadow copy: "
          f"{'DELETED' if rc == 0 else f'EXIT CODE {rc} (may be none)'}")

    print("\n--- [7] Windows.old (if present) ---")
    win_old = Path(r"C:\Windows.old")
    if win_old.is_dir() or dry:
        size = dir_size(win_old) if not dry else 0
        print(f"Found Windows.old ({gb(size)} GB) - removing...")
        run(["takeown", "/f", r"C:\Windows.old", "/r", "/d", "y"], dry,
            echo=False)
        run(["icacls", r"C:\Windows.old", "/grant",
             "administrators:F", "/t", "/c", "/q"], dry, echo=False)
        run(["cmd", "/c", "rd", "/s", "/q", r"C:\Windows.old"], dry,
            echo=False)
        print(f"[7] Windows.old removed: -{gb(size)} GB")
    else:
        print("[7] Windows.old: not found")

    after = free_c()
    print("\n=== Summary ===")
    print(f"C: free before: {gb(before)} GB")
    print(f"C: free after : {gb(after)} GB")
    print(f"Freed on C:   : {gb(after - before)} GB")
    print("Done. Reboot recommended after DISM/SFC.")


if __name__ == "__main__":
    main()
