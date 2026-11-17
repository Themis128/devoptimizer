# REQUIRES: admin
"""Port of scripts/compact-vhdx-elevated.ps1.

Hardcoded-target WSL VHDX compaction (must run
elevated): wsl --shutdown, Optimize-VHD -Mode Full on
the localappdata wsl ext4.vhdx, Mount-VHD fallback.
"""

import ctypes
import subprocess
import sys
import time
from pathlib import Path

VHDX = Path(
    r"C:\Users\tbaltzakis\AppData\Local\wsl"
    r"\{12c19879-cec8-4dd1-9fe4-7049940b6a2f}"
    r"\ext4.vhdx")


def run_ps(cmd, timeout=3600):
    try:
        return subprocess.run(
            ["powershell", "-NoProfile", "-Command", cmd],
            capture_output=True, text=True,
            timeout=timeout)
    except Exception:
        return None


def main():
    try:
        if not ctypes.windll.shell32.IsUserAnAdmin():
            print("Requires Administrator. Re-run "
                  "elevated.")
            return 1
    except Exception:
        return 1

    print("=== WSL VHDX Compaction ===")
    print(f"VHDX: {VHDX}")
    if not VHDX.exists():
        print("VHDX not found!")
        if sys.stdin.isatty():
            input("Press Enter to exit")
        return 1
    before = VHDX.stat().st_size
    print(f"Before: {before/2**30:.2f} GB")

    print("\nStopping WSL...")
    subprocess.run(["wsl", "--shutdown"],
                   capture_output=True)
    time.sleep(5)
    run_ps("Get-Process -Name 'vmmemWSL','vmmem' "
           "-ErrorAction SilentlyContinue | "
           "Stop-Process -Force")
    time.sleep(3)

    r = run_ps(f"Optimize-VHD -Path '{VHDX}' "
               "-Mode Full -ErrorAction Stop")
    if r and r.returncode == 0:
        after = VHDX.stat().st_size
        print("\nSUCCESS!")
        print(f"After:  {after/2**30:.2f} GB")
        print(f"Freed:  {(before-after)/2**30:.2f} GB")
    else:
        e = (r.stderr if r else "timeout")
        print(f"\nFAILED: {e[:300]}")
        print("\nTrying Mount-VHD approach...")
        r = run_ps(
            f"Mount-VHD -Path '{VHDX}' -ReadOnly "
            "-ErrorAction Stop; Optimize-VHD -Path "
            f"'{VHDX}' -Mode Full -ErrorAction Stop; "
            f"Dismount-VHD -Path '{VHDX}' "
            "-ErrorAction Stop")
        if r and r.returncode == 0:
            after = VHDX.stat().st_size
            print("SUCCESS (alt)!")
            print(f"After:  {after/2**30:.2f} GB")
            print(f"Freed:  {(before-after)/2**30:.2f} "
                  "GB")
        else:
            print(f"FAILED (alt): "
                  f"{(r.stderr if r else 'timeout')[:300]}")

    if sys.stdin.isatty():
        input("\nPress Enter to exit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
