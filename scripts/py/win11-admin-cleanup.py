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

WU = Path(r"C:\Windows\SoftwareDistribution\Download")
DO = Path(r"C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache")
WINOLD = Path(r"C:\Windows.old")


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

    print("=== Windows 11 Admin Cleanup ===")
    sh("Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart",
       args.dry_run)
    clear_dir(WU, args.dry_run)
    clear_dir(DO, args.dry_run)
    if args.dry_run:
        print(f"rd /s /q {WINOLD}")
    elif WINOLD.is_dir():
        subprocess.run(f'cmd /c rd /s /q "{WINOLD}"', shell=True)
    print("Done. A reboot is recommended after DISM operations.")


if __name__ == "__main__":
    main()
