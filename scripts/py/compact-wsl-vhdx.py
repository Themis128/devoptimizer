# REQUIRES: admin
"""Port of scripts/compact-wsl-vhdx.ps1.

Stops Docker Desktop + shuts down WSL, Optimize-VHD -Mode Full on
docker_data.vhdx and the Ubuntu ext4.vhdx, then restarts Docker
Desktop. -DryRun reports sizes; -Force skips the y/N confirm;
-SkipWSL/-SkipDocker narrow the scope.
"""

import argparse
import ctypes
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

LOG = Path("D:/DevOptimizer/logs/compact-wsl-vhdx.log")
DOCKER_VHDX = (Path(os.environ.get("LOCALAPPDATA", ""))
               / "Docker" / "wsl" / "disk"
               / "docker_data.vhdx")
WSL_DISTRO = "Ubuntu-24.04"
WSL_VHDX = Path(r"E:\WSL\Ubuntu-24.04\ext4.vhdx")


def log(msg):
    try:
        LOG.parent.mkdir(exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} "
                    f"{msg}\n")
    except OSError:
        pass


def out(msg):
    print(msg)
    log(msg)


def warn(msg):
    print(f"WARN: {msg}")
    log(f"WARN: {msg}")


def err(msg):
    print(f"ERROR: {msg}")
    log(f"ERROR: {msg}")


def run(cmd, timeout=120):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=timeout)
    except Exception:
        return None


def is_admin():
    try:
        return bool(
            ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def vhdx_gb(path):
    try:
        return round(Path(path).stat().st_size / 2**30, 2)
    except OSError:
        return 0


def proc_alive(name):
    r = run(["tasklist", "/FI", f"IMAGENAME eq {name}"])
    return bool(r and name in r.stdout)


def wait_exit(name, secs):
    deadline = time.time() + secs
    while time.time() < deadline:
        if not proc_alive(name):
            return True
        time.sleep(2)
    return False


def compact(path, before):
    r = run(["powershell", "-NoProfile", "-Command",
             f"Optimize-VHD -Path '{path}' -Mode Full "
             "-ErrorAction Stop"], timeout=3600)
    if r and r.returncode == 0:
        out(f"  {Path(path).name} compacted successfully")
        return
    warn(f"  Optimize-VHD failed for {Path(path).name}: "
         f"{(r.stderr if r else 'timeout')[:200]}")
    warn("  Trying fallback: optimize-vhd via cmd...")
    r = run(["cmd.exe", "/c",
             f'optimize-vhd -Path "{path}" -Mode Full'],
            timeout=3600)
    for line in ((r.stdout if r else "")
                 .splitlines()):
        out(f"  {line}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-SkipWSL", action="store_true")
    ap.add_argument("-SkipDocker", action="store_true")
    ap.add_argument("-DryRun", action="store_true")
    ap.add_argument("-Force", action="store_true")
    ap.add_argument("-TimeoutMinutes", type=int,
                    default=10)
    a = ap.parse_args()

    if not is_admin():
        err("This script requires Administrator "
            "privileges. Re-run from elevated PowerShell.")
        return 1

    wsl_vhdx = WSL_VHDX if WSL_VHDX.exists() else None
    out("=== WSL VHDX Compaction Tool ===\n")
    docker_before = vhdx_gb(DOCKER_VHDX)
    wsl_before = vhdx_gb(wsl_vhdx) if wsl_vhdx else 0
    out("Current VHDX sizes:")
    out(f"  docker_data.vhdx : {docker_before} GB")
    if wsl_vhdx:
        out(f"  Ubuntu ext4.vhdx  : {wsl_before} GB")
    else:
        out("  Ubuntu ext4.vhdx  : NOT FOUND")
    out("")
    if a.DryRun:
        out("DRY RUN - no changes will be made")
        return 0
    if not a.Force:
        warn("This will:")
        warn("  1. Stop Docker Desktop")
        warn(f"  2. Shutdown WSL ({WSL_DISTRO})")
        warn("  3. Compact VHDX files (can take several "
             "minutes)")
        warn("  4. Restart Docker Desktop")
        if not sys.stdin.isatty():
            out("Cancelled (no interactive console; "
                "pass -Force)")
            return 0
        if input("Continue? (y/N) ").strip() != "y":
            out("Cancelled")
            return 0

    out("[1/6] Stopping Docker Desktop...")
    run([r"C:\Program Files\Docker\Docker\DockerCli.exe",
         "-Shutdown"])
    time.sleep(3)
    run(["powershell", "-Command",
         "Get-Process 'Docker Desktop',"
         "'com.docker.backend','vmmemWSL' -ErrorAction "
         "SilentlyContinue | Stop-Process -Force "
         "-ErrorAction SilentlyContinue"])
    if not wait_exit("vmmemWSL", 60):
        warn("vmmemWSL still running after 60s, "
             "continuing anyway...")

    if not a.SkipWSL:
        out(f"[2/6] Shutting down WSL ({WSL_DISTRO})...")
        run(["wsl.exe", "--terminate", WSL_DISTRO])
        time.sleep(3)
        run(["wsl.exe", "--shutdown"])
        time.sleep(5)
        attempts = 0
        while proc_alive("vmmemWSL") and attempts < 30:
            time.sleep(2)
            attempts += 1
        if proc_alive("vmmemWSL"):
            err("WSL did not shut down completely "
                "(vmmemWSL still running)")
            return 1
        out("WSL shut down confirmed")
    else:
        out("[2/6] Skipping WSL shutdown (SkipWSL)")

    if not a.SkipDocker and DOCKER_VHDX.exists():
        out(f"[3/6] Compacting docker_data.vhdx "
            f"({docker_before} GB)...")
        compact(DOCKER_VHDX, docker_before)
    else:
        out("[3/6] Skipping docker_data.vhdx")

    if not a.SkipWSL and wsl_vhdx and wsl_vhdx.exists():
        out(f"[4/6] Compacting Ubuntu ext4.vhdx "
            f"({wsl_before} GB)...")
        compact(wsl_vhdx, wsl_before)
    else:
        out("[4/6] Skipping WSL VHDX")

    out("[5/6] Starting Docker Desktop...")
    run(["powershell", "-Command",
         "Start-Process 'C:\\Program Files\\Docker"
         "\\Docker\\Docker Desktop.exe'"])

    out("[6/6] Waiting for WSL to come back...")
    deadline = time.time() + a.TimeoutMinutes * 60
    while time.time() < deadline:
        if proc_alive("vmmemWSL"):
            out("vmmemWSL is running again")
            break
        time.sleep(5)
    else:
        warn("vmmemWSL did not come back within "
             f"{a.TimeoutMinutes} min")
    out("Done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
