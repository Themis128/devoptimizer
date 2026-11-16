"""Windows 11 admin cleanup run interactively (port of
scripts/admin-cleanup-run-as-admin.bat).

Prompts for a keypress, then runs: DISM component-store cleanup,
Windows Update download-cache cleanup (stops/starts wuauserv),
Delete-DeliveryOptimizationCache, oldest shadow-copy deletion, and
Windows.old removal. Requires Administrator privileges.
"""

import argparse
import ctypes
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: admin, dism, windows-update, shadow-copy
# REQUIRES: admin


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def run(cmd):
    return subprocess.run([str(c) for c in cmd]).returncode


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    print("=" * 60)
    print(" Windows 11 Admin Cleanup - Requires Administrator Rights")
    print("=" * 60)
    print("\nThis script will run:")
    print("  1. DISM Component Store Cleanup")
    print("  2. Windows Update Download Cache Cleanup")
    print("  3. Delivery Optimization Cache Cleanup")
    print("  4. Oldest Shadow Copy Removal")
    print("  5. Windows.old folder (if exists)")
    if not is_admin():
        print("\n[ERROR] This script requires Administrator privileges.")
        sys.exit(1)
    if args.dry_run:
        print("\n[dry-run] would run all 5 cleanup steps")
        return
    input("\nPress Enter to continue...")

    print("\n[1/5] DISM Component Store Cleanup...")
    print("This may take several minutes...")
    rc = run([r"C:\Windows\System32\Dism.exe", "/Online",
              "/Cleanup-Image", "/StartComponentCleanup",
              "/NoRestart"])
    print(f"DISM Exit Code: {rc}")

    print("\n[2/5] Windows Update Download Cache...")
    run(["net", "stop", "wuauserv"])
    wu = Path(r"C:\Windows\SoftwareDistribution\Download")
    if wu.is_dir():
        for c in wu.iterdir():
            try:
                if c.is_dir():
                    shutil.rmtree(c, ignore_errors=True)
                else:
                    c.unlink()
            except OSError:
                pass
        print("Windows Update cache cleared.")
    else:
        print("Windows Update cache folder not found.")
    run(["net", "start", "wuauserv"])

    print("\n[3/5] Delivery Optimization Cache...")
    rc = run(["powershell.exe", "-Command",
              "Delete-DeliveryOptimizationCache"])
    if rc == 0:
        print("Delivery Optimization cache cleared.")
    else:
        print("Delivery Optimization cache: skipped "
              "(may not be available)")

    print("\n[4/5] Oldest Shadow Copy...")
    rc = run(["vssadmin", "delete", "shadows", "/for=c:", "/oldest",
              "/quiet"])
    if rc == 0:
        print("Oldest shadow copy deleted.")
    else:
        print("No shadow copies to delete or access denied.")

    print("\n[5/5] Windows.old folder...")
    wo = Path(r"C:\Windows.old")
    if wo.is_dir():
        print("Found Windows.old - removing (this may take a "
              "while)...")
        run(["takeown", "/f", r"C:\Windows.old", "/r", "/d", "y"])
        run(["icacls", r"C:\Windows.old", "/grant",
             "administrators:F", "/t", "/c", "/q"])
        run(["cmd", "/c", "rd", "/s", "/q", r"C:\Windows.old"])
        print("Windows.old removed." if not wo.is_dir()
              else "Windows.old partially removed (files locked).")
    else:
        print("Windows.old not present.")
    print("\n[OK] Admin cleanup complete!")


if __name__ == "__main__":
    main()
