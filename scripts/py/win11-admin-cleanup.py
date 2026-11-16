"""Windows 11 admin cleanup (port of scripts/win11-admin-cleanup.ps1).

DISM component cleanup, Windows Update download cache, Delivery
Optimization cache, C:\\Windows.old. Elevated; --dry-run.
"""

import argparse
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: cleanup, dism, elevated, windows-update
# REQUIRES: admin

WU = Path(r"C:\Windows\SoftwareDistribution\Download")
# Monitored by check-cleanup-status.ps1 under the NetworkService
# profile (ProgramData\... is a different, mostly-empty location).
DO = Path(r"C:\Windows\ServiceProfiles\NetworkService\AppData\Local"
          r"\Microsoft\Windows\DeliveryOptimization\Cache")
WINOLD = Path(r"C:\Windows.old")


def is_admin():
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def sh(cmd: str, dry: bool):
    print(cmd if dry else "", end="")
    if dry:
        print()
        return 0
    return subprocess.run(cmd, shell=True).returncode


def clear_dir(path: Path, dry: bool):
    if dry:
        print(f"clear {path}")
        return
    for item in path.iterdir() if path.is_dir() else []:
        try:
            if item.is_dir():
                import shutil
                shutil.rmtree(item, ignore_errors=True)
            else:
                item.unlink(missing_ok=True)
        except OSError:
            pass


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    if not args.dry_run and not is_admin():
        sys.exit("This script MUST be run as Administrator.")

    print("=== Windows 11 Admin Cleanup ===")
    sh("Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart",
       args.dry_run)
    clear_dir(WU, args.dry_run)
    if args.dry_run:
        print("[dry-run] Delete-DeliveryOptimizationCache "
              f"(cache dir {DO})")
    else:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "try { Delete-DeliveryOptimizationCache -ErrorAction "
             "Stop } catch { try { Remove-Item -LiteralPath "
             f"'{DO}' -Recurse -Force -ErrorAction Stop }} "
             "catch {} }"], capture_output=True, text=True,
            errors="replace")
        print(r.stdout.strip() or "DO cache cleared")
    if args.dry_run:
        print(f"rd /s /q {WINOLD}")
    elif WINOLD.is_dir():
        subprocess.run(f'cmd /c rd /s /q "{WINOLD}"', shell=True)
    print("Done. A reboot is recommended after DISM operations.")


if __name__ == "__main__":
    main()
