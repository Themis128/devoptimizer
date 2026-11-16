"""Port of scripts/run-elevated-maintenance.ps1 — elevated maintenance:
quit Docker Desktop, wsl --shutdown, compact docker_data.vhdx via
diskpart, restart DD + wait for engine, DISM StartComponentCleanup,
WU download cache, Delivery Optimization cache, winget Git.Git,
final sizes. Transcript + .done marker. Requires admin.
"""
# REQUIRES: admin

import datetime
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# CATEGORY: maintenance
# TAGS: elevated, cleanup, vhdx, docker

LOG_DIR = Path(r"D:\DevOptimizer\logs")
LOG_FILE = LOG_DIR / "elevated-20260906.log"
DONE_FILE = LOG_DIR / "elevated-20260906.done"
VHDX = (r"C:\Users\tbaltzakis\AppData\Local\Docker\wsl\disk"
        r"\docker_data.vhdx")
DOCKER_CLI = r"C:\Program Files\Docker\Docker\DockerCli.exe"
DOCKER_EXE = r"C:\Program Files\Docker\Docker\Docker Desktop.exe"
WU_DIR = r"C:\Windows\SoftwareDistribution\Download"


def log(msg):
    line = f"[{datetime.datetime.now():%H:%M:%S}] {msg}"
    print(line)
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def run(cmd, timeout=300, capture=True):
    try:
        r = subprocess.run(cmd, capture_output=capture, text=True,
                           timeout=timeout)
        if capture:
            for ln in (r.stdout or "").splitlines():
                log(ln)
        return r.returncode, (r.stdout or "")
    except (OSError, subprocess.TimeoutExpired) as e:
        log(f"{cmd[0]} failed: {e}")
        return 1, ""


def c_free_gb():
    import shutil
    return shutil.disk_usage("C:\\").free / (1 << 30)


def vhdx_gb():
    try:
        return Path(VHDX).stat().st_size / (1 << 30)
    except OSError:
        return 0.0


def main():
    log(f"START. C: free before: {c_free_gb():.2f} GB. "
        f"vhdx before: {vhdx_gb():.2f} GB")

    log("Quitting Docker Desktop...")
    run([DOCKER_CLI, "-Quit"])
    time.sleep(5)
    for p in ("Docker Desktop", "com.docker.backend",
              "wsl", "wslhost"):
        run(["taskkill", "/f", "/im", f"{p}.exe"], capture=False)
    time.sleep(2)
    log("Shutting down WSL...")
    run(["wsl", "--shutdown"])
    time.sleep(5)

    log("Compacting docker_data.vhdx (diskpart: attach readonly -> "
        "compact -> detach)...")
    with tempfile.NamedTemporaryFile(
            "w", suffix=".txt", delete=False) as f:
        f.write(f'select vdisk file="{VHDX}"\nattach vdisk readonly\n'
                "compact vdisk\ndetach vdisk\n")
        dp_file = f.name
    run(["diskpart", "/s", dp_file], timeout=3600)
    log(f"vhdx after compaction: {vhdx_gb():.2f} GB")

    log("Restarting Docker Desktop...")
    try:
        subprocess.Popen([DOCKER_EXE])
    except OSError as e:
        log(f"failed to start Docker Desktop: {e}")
    deadline = time.time() + 360
    eng = ""
    while not eng and time.time() < deadline:
        time.sleep(10)
        r = subprocess.run(
            ["docker", "version", "--format", "{{.Server.Version}}"],
            capture_output=True, text=True)
        eng = r.stdout.strip() if r.returncode == 0 else ""
    log("Docker engine after restart: "
        + (eng or "NOT UP (will check later)"))
    rc, out = run(["wsl", "-d", "Ubuntu-24.04", "--", "echo",
                   "wsl-ok"])
    log(f"WSL exec after restart: {out.strip()}")

    log("Running DISM StartComponentCleanup (10-30 minutes)...")
    rc, _ = run(["dism", "/Online", "/Cleanup-Image",
                 "/StartComponentCleanup"], timeout=3600,
                capture=False)
    log(f"DISM exit code: {rc}")

    log("Clearing Windows Update download cache...")
    for svc in ("wuauserv", "bits"):
        run(["net", "stop", svc], capture=False)
    wu_before = sum(p.stat().st_size
                    for p in Path(WU_DIR).rglob("*")
                    if p.is_file()) if Path(WU_DIR).is_dir() else 0
    for p in Path(WU_DIR).iterdir() if Path(WU_DIR).is_dir() else []:
        try:
            if p.is_dir():
                import shutil as sh
                sh.rmtree(p, ignore_errors=True)
            else:
                p.unlink()
        except OSError:
            pass
    for svc in ("bits", "wuauserv"):
        run(["net", "start", svc], capture=False)
    log(f"WU cache cleared: freed ~{wu_before / (1 << 20):.0f} MB")

    log("Clearing Delivery Optimization cache...")
    rc, _ = run(["powershell", "-NoProfile", "-Command",
                 "Delete-DeliveryOptimizationCache -Force"],
                timeout=120, capture=False)
    log("Delivery Optimization cache cleared" if rc == 0
        else "Delivery Optimization: delete failed")

    log("Installing Git.Git (full, with GCM)...")
    run(["winget", "install", "--id", "Git.Git", "-e",
         "--source", "winget", "--accept-package-agreements",
         "--accept-source-agreements", "--silent", "--override",
         "/VERYSILENT /NORESTART /SUPPRESSMSGBOXES"], timeout=1800)

    log(f"DONE. C: free after: {c_free_gb():.2f} GB. "
        f"vhdx after: {vhdx_gb():.2f} GB")
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        DONE_FILE.write_text(datetime.datetime.now().isoformat(),
                             encoding="utf-8")
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
