"""Daily full cleanup (port of scripts/daily-full-cleanup.ps1).

Chain: swap-orphan reaper -> safe cleanup -> recycle bin -> docker
prune (volumes kept) -> E:\\AdaptivaCache. Logs C: free before/after
to logs/daily-full-cleanup.log. Mutating; --dry-run.
"""

import argparse
import datetime
import subprocess
from pathlib import Path

# CATEGORY: cleanup
# TAGS: cleanup, docker, recycle-bin, scheduled

LOG_FILE = Path(r"D:\DevOptimizer\logs\daily-full-cleanup.log")
SCRIPTS_DIR = Path(__file__).resolve().parent.parent


def log(msg: str):
    line = (f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {msg}")
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "a") as fh:
        fh.write(line + "\n")
    print(line)


def run_ps(script: str, label: str, dry: bool):
    if dry:
        log(f"[dry-run] {label}: {script}")
        return
    r = subprocess.run(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-File", str(script)], capture_output=True, text=True)
    for line in (r.stdout + r.stderr).splitlines():
        if line.strip():
            log(f"{label}: {line}")


def c_free_gb() -> float:
    try:
        import ctypes
        free = ctypes.c_ulonglong()
        ctypes.windll.kernel32.GetDiskFreeSpaceExW(
            "C:\\", None, None, ctypes.byref(free))
        return round(free.value / (1 << 30), 1)
    except Exception:
        return 0.0


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    log("=== daily-full-cleanup start ===")
    before = c_free_gb()
    log(f"C: free before: {before} GB")

    run_ps(SCRIPTS_DIR / "cleanup-wsl-swap-orphans.ps1",
           "swap-reaper", args.dry_run)
    run_ps(SCRIPTS_DIR / "win11-safe-cleanup.ps1",
           "safe-cleanup", args.dry_run)

    if args.dry_run:
        log("[dry-run] Clear-RecycleBin")
        for c in ("docker builder prune -af",
                  "docker container prune -f",
                  "docker image prune -f"):
            log(f"[dry-run] {c}")
        log("[dry-run] clear E:\\AdaptivaCache")
    else:
        r = subprocess.run(["powershell.exe", "-NoProfile", "-Command",
                            "Clear-RecycleBin -Force"],
                           capture_output=True, text=True)
        log("recycle bin: emptied" if r.returncode == 0
            else f"recycle bin: {r.stderr.strip()}")
        # Dangling-only image prune: tagged-but-unused images survive so
        # compose recreations reuse them locally instead of re-pulling
        # ~50GB/day into docker_data.vhdx between compactions.
        r = subprocess.run(["docker", "builder", "prune", "-af"],
                           capture_output=True, text=True)
        last = (r.stdout.strip().splitlines() or [""])[-1]
        log(f"docker builder: {last}")
        r = subprocess.run(["docker", "container", "prune", "-f"],
                           capture_output=True, text=True)
        last = (r.stdout.strip().splitlines() or [""])[-1]
        log(f"docker containers: {last}")
        r = subprocess.run(["docker", "image", "prune", "-f"],
                           capture_output=True, text=True)
        last = (r.stdout.strip().splitlines() or [""])[-1]
        log(f"docker dangling imgs: {last}")
        shader = Path(r"E:\AdaptivaCache")
        if shader.is_dir():
            for item in shader.iterdir():
                try:
                    if item.is_dir():
                        import shutil
                        shutil.rmtree(item, ignore_errors=True)
                    else:
                        item.unlink(missing_ok=True)
                except OSError:
                    pass
            log("E: AdaptivaCache cleared")

    after = c_free_gb()
    log(f"C: free after: {after} GB "
        f"(delta {round(after - before, 1)} GB)")
    log("=== daily-full-cleanup done ===")


if __name__ == "__main__":
    main()
