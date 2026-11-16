"""Port of scripts/wsl-gpu-rebind.ps1 — bounce WSL to rebind the GPU-P
channel after an NVIDIA driver install/hot-swap left the VM with
"GPU access blocked by the operating system" (dmesg:
dxgvmb_send_create_process failed -75).

Runs Windows-side so it survives the WSL death. After the bounce it
prewarms Ubuntu-24.04 and runs the in-VM verify script (nvidia-smi +
comfyui torch.cuda + recreate). --dry-run prints only.
"""
import argparse
import datetime
import subprocess
import sys
import time
from pathlib import Path

# CATEGORY: maintenance
# TAGS: wsl, gpu, nvidia

LOG_FILE = Path(r"D:\DevOptimizer\logs\wsl-gpu-rebind.log")
DISTRO = "Ubuntu-24.04"
VERIFY = ("/home/tbaltzakis/cu130-slim/.devin/skills/windows-host-ops/"
          "scripts/wsl-gpu-verify.sh")


def log(msg):
    line = f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {msg}"
    print(line)
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def run_log(cmd, dry):
    if dry:
        log("[dry-run] " + " ".join(map(str, cmd)))
        return 0
    try:
        r = subprocess.run([str(c) for c in cmd], capture_output=True,
                           text=True)
        for ln in (r.stdout or "").splitlines() + \
                  (r.stderr or "").splitlines():
            log(ln)
        return r.returncode
    except OSError as e:
        log(f"{cmd[0]} failed: {e}")
        return 1


def main():
    ap = argparse.ArgumentParser(description="WSL GPU rebind")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    log("=== WSL GPU rebind starting ===")
    log("wsl --shutdown")
    run_log(["wsl.exe", "--shutdown"], args.dry_run)
    if not args.dry_run:
        time.sleep(15)
    log(f"prewarming {DISTRO}")
    run_log(["wsl.exe", "-d", DISTRO, "--exec", "true"], args.dry_run)
    if not args.dry_run:
        time.sleep(10)
    log("running in-VM gpu verify")
    run_log(["wsl.exe", "-d", DISTRO, "-e", "bash", VERIFY],
            args.dry_run)
    log("=== WSL GPU rebind finished ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
