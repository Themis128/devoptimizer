"""Port of scripts/Invoke-VhdxCompaction.ps1 — Devin-safe nightly
WSL/Docker vhdx compaction. Gates on Devin.exe + devin-server, growth
threshold >=10GB (state logs\\vhdx-compaction-state.json), graceful DD
quit, wsl --shutdown, exclusive-unlock poll, sparse flag skip,
Optimize-VHD Full, restart DD + distro. Exit: 0 compacted/skipped,
1 failure, 2 deferred.
"""
# REQUIRES: admin
import ctypes
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

DISTRO = "Ubuntu-24.04"
STATE = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs"
             + chr(92) + "vhdx-compaction-state.json")


def docker_exe():
    local = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" \
        / "DockerDesktop" / "Docker Desktop.exe"
    if local.exists():
        return str(local)
    return str(Path(os.environ.get("ProgramFiles", ""))
               / "Docker" / "Docker" / "Docker Desktop.exe")


def wsl(cmd):
    try:
        r = subprocess.run(["wsl.exe", "-d", DISTRO, "--", "bash",
                            "-c", cmd], capture_output=True,
                           text=True)
        return [l for l in re.split(r"\r?\n",
                                    r.stdout.replace("\x00", ""))
                if l]
    except FileNotFoundError:
        return []


def proc_running(name):
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "[bool](Get-Process -Name '" + name
                        + "' -ErrorAction SilentlyContinue)"],
                       capture_output=True, text=True)
    return r.stdout.strip().lower() == "true"


def vhdx_unlocked(path):
    try:
        fd = os.open(path, os.O_RDWR | os.O_EXCL)
        os.close(fd)
        return True
    except OSError:
        return False


def vhdx_targets():
    targets = []
    for root in (Path(os.environ.get("LOCALAPPDATA", "")) / "wsl",
                 Path("C:" + chr(92) + "WSL")):
        if root.exists():
            targets += [str(p) for p in root.rglob("*.vhdx")]
    dd = Path(os.environ.get("LOCALAPPDATA", "")) / "Docker" / "wsl" \
        / "disk" / "docker_data.vhdx"
    if dd.exists():
        targets.append(str(dd))
    return sorted(set(targets))


def is_sparse(path):
    r = subprocess.run(["fsutil", "sparse", "queryflag", path],
                       capture_output=True, text=True)
    return "set as sparse" in r.stdout


def main():
    args = sys.argv
    min_growth, force_all, as_lib = 10, "--force-all" in args, \
        "--as-library" in args
    for i, a in enumerate(args):
        if a == "--min-growth-gb" and i + 1 < len(args):
            min_growth = int(args[i + 1])
    details = []

    def log(m):
        print(m)
        details.append(m)

    status = "unknown"
    if not ctypes.windll.shell32.IsUserAnAdmin():
        status = "not-admin"
        log("[FAIL] not elevated - Optimize-VHD requires admin."
            " Nothing was touched.")
        return status, details, 0, 0

    if proc_running("Devin"):
        status = "deferred"
        log("[DEFERRED] Devin is active - WSL untouched. Will retry"
            " on the next scheduled run.")
        return status, details, 0, 0
    server = wsl("pgrep -f 'server-mai[n]' || true")
    if any(re.search(r"\d", l) for l in server):
        status = "deferred"
        log("[DEFERRED] devin-server still alive in Ubuntu-24.04 -"
            " WSL untouched. Its auto-shutdown clears this gate"
            " shortly after Devin closes.")
        return status, details, 0, 0
    log("[ OK ] Devin gates passed (no app, no server)")

    targets = vhdx_targets()
    if not targets:
        log("[FAIL] no vhdx files found - nothing to do")
        return "no-targets", details, 0, 0

    try:
        state = json.loads(STATE.read_text(encoding="utf-8")) \
            if STATE.exists() else {}
    except ValueError:
        state = {}
    to_compact = []
    for t in targets:
        size_gb = round(Path(t).stat().st_size / 1e9, 2)
        prev = state.get(t)
        if force_all or not prev \
                or (size_gb - prev.get("lastSizeAfterGB", 0)) \
                >= min_growth:
            reason = ("forced" if force_all else "first run"
                      if not prev else
                      f"grew {round(size_gb - prev.get('lastSizeAfterGB', 0), 2)} GB")
            log(f"[ OK ] {t} ({size_gb} GB) qualifies: {reason}")
            to_compact.append(t)
        else:
            log(f"[SKIP] {t}: grew only"
                f" {round(size_gb - prev.get('lastSizeAfterGB', 0), 2)}"
                f" GB since last compaction (threshold"
                f" {min_growth} GB)")
    if not to_compact:
        log("[SKIP] no vhdx grew enough to justify a compaction")
        return "skipped", details, 0, 0

    if proc_running("Docker Desktop"):
        log("[ .. ] quitting Docker Desktop gracefully...")
        subprocess.run(["powershell", "-NoProfile", "-Command",
                        "Get-Process -Name 'Docker Desktop'"
                        " -ErrorAction SilentlyContinue |"
                        " ForEach-Object { [void]$_.CloseMainWindow() }"],
                       capture_output=True)
        waited = 0
        while proc_running("com.docker.backend") and waited < 90:
            time.sleep(3)
            waited += 3
        for n in ("com.docker.backend", "Docker Desktop"):
            subprocess.run(["powershell", "-NoProfile", "-Command",
                            "Get-Process -Name '" + n + "'"
                            " -ErrorAction SilentlyContinue |"
                            " Stop-Process -Force -ErrorAction"
                            " SilentlyContinue"], capture_output=True)
        log(f"[ OK ] Docker Desktop stopped (waited {waited} s)")

    log("[ .. ] wsl --shutdown")
    subprocess.run(["wsl", "--shutdown"], capture_output=True)
    deadline = time.time() + 120
    vm_gone = all_unlocked = False
    while time.time() < deadline:
        time.sleep(3)
        vm_gone = not proc_running("vmmemWSL")
        all_unlocked = all(vhdx_unlocked(t) for t in to_compact)
        if not (vm_gone and all_unlocked):
            log(f"[ .. ] waiting for WSL disks to release"
                f" (vmmemWSL gone: {vm_gone}, vhdx unlocked:"
                f" {all_unlocked})...")
        else:
            break
    if not (vm_gone and all_unlocked):
        log("[FAIL] WSL disks still locked after 120 s - restoring"
            " WSL/Docker and aborting compaction.")
        subprocess.Popen([docker_exe()])
        wsl("echo ok")
        return "failed-locked", details, 0, 0
    log("[ OK ] WSL fully stopped, vhdx files unlocked")

    for d in ("docker-desktop", "Ubuntu-24.04"):
        log(f"[ .. ] set-sparse {d}")
        subprocess.run(["wsl", "--manage", d, "--set-sparse", "true"],
                       capture_output=True)

    compacted = freed_total = 0
    for t in to_compact:
        if not vhdx_unlocked(t):
            log(f"[FAIL] {t} re-locked - skipping")
            continue
        if is_sparse(t):
            log(f"[SKIP] {t} is sparse - auto-reclaims, no"
                " Optimize-VHD needed")
            continue
        before = Path(t).stat().st_size
        log(f"[ .. ] Optimize-VHD: {t} ({round(before / 1e9, 2)} GB)...")
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "Optimize-VHD -Path '" + t + "' -Mode Full"],
            capture_output=True, text=True)
        if r.returncode == 0 and not r.stderr:
            after = Path(t).stat().st_size
            freed = round((before - after) / 1e9, 2)
            freed_total += freed
            compacted += 1
            log(f"[ OK ] {t}: {round(before / 1e9, 2)} GB ->"
                f" {round(after / 1e9, 2)} GB (freed {freed} GB)")
            state[t] = {"lastSizeAfterGB": round(after / 1e9, 2),
                        "lastRun": time.strftime("%Y-%m-%dT%H:%M:%S")}
        else:
            log(f"[FAIL] Optimize-VHD on {t}:"
                f" {r.stderr.strip()[:200]}")
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2), encoding="utf-8")

    log("[ .. ] restarting Ubuntu-24.04 and Docker Desktop...")
    wsl("echo ok")
    if Path(docker_exe()).exists():
        subprocess.Popen([docker_exe()])
    log(f"[ OK ] done: {compacted} vhdx compacted,"
        f" {freed_total} GB freed. Devin will reconnect cleanly on"
        " next open.")
    return "compacted", details, compacted, freed_total


if __name__ == "__main__":
    status, details, compacted, freed = main()
    if "--as-library" not in sys.argv:
        sys.exit(0 if status in ("compacted", "skipped",
                                 "no-targets")
                 else 2 if status == "deferred" else 1)
