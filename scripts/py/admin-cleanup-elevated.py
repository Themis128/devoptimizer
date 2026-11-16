"""Elevated admin cleanup + VHDX compaction (port of
scripts/admin-cleanup-elevated.ps1).

Sections: [0] docker-backend firewall rule, [1] DISM component-store,
[2] WU download cache (service-stopped), [3] Delivery Optimization
cache, [4] oldest shadow copy, [5] Windows.old, [6] VHDX compaction -
docker_data.vhdx (terminates only docker-desktop, Ubuntu keeps
running); --shutdown-wsl also compacts Ubuntu ext4.vhdx after a full
wsl --shutdown. --skip-vhdx runs 0-5 only (safe any time). [7]
sshd-repair -RegisterTask. Transcript to logs\\admin-cleanup-elevated.log;
ntfy on failures. Requires admin. Mutating; --dry-run.
"""

import argparse
import io
import asyncio
import ctypes
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: cleanup
# TAGS: cleanup, elevated, vhdx, dism, windows-update, docker-desktop
# REQUIRES: admin

DOCKER_DATA = (Path(os.environ.get("LOCALAPPDATA", ""))
               / "Docker" / "wsl" / "disk" / "docker_data.vhdx")
UBUNTU_VHDX = Path(r"C:\WSL\Ubuntu-24.04\ext4.vhdx")


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def free_c():
    try:
        return shutil.disk_usage("C:\\").free
    except OSError:
        return 0


def gb(b):
    return round(b / 2**30, 2)


def dir_size(p):
    return sum(f.stat().st_size for f in Path(p).rglob("*")
               if f.is_file()) if Path(p).exists() else 0


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


def vhdx_locked(path):
    try:
        with open(path, "ab"):
            pass
        return False
    except OSError:
        return True


def compact_vhdx(path, label, dry):
    if not Path(path).is_file():
        return
    if vhdx_locked(path):
        print(f"  {label}: still in use, skipped")
        return
    print(f"  {label}: compacting (Optimize-VHD -Mode Full)...")
    if dry:
        print(f"[dry-run] Optimize-VHD {path}")
        return
    r = asyncio.run(run_ps_command(
        f"Optimize-VHD -Path '{path}' -Mode Full "
        "-ErrorAction Stop", timeout=3600))
    if r.returncode != 0:
        asyncio.run(run_ps_command(
            ". 'D:\\DevOptimizer\\scripts\\lib\\Notify.ps1'; "
            "Send-DevOptAlert -Severity Warning -Title "
            f"'VHDX Compact Failed: {label}' -Message "
            f"'{r.stderr[:200].replace(chr(39), '')}' "
            "-Tags 'cleanup','vhdx','admin' -EventId 1007",
            timeout=60))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--shutdown-wsl", action="store_true")
    ap.add_argument("--skip-vhdx", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run

    class _Tee(io.TextIOBase):
        def __init__(self, *streams):
            self._streams = streams

        def write(self, data):
            for s in self._streams:
                if s is not None:
                    s.write(data)
            return len(data)

        def flush(self):
            for s in self._streams:
                if s is not None:
                    s.flush()

    logs_dir = Path(__file__).resolve().parents[2] / "logs"
    logs_dir.mkdir(exist_ok=True)
    log_path = logs_dir / "admin-cleanup-elevated.log"
    log_file = open(log_path, "a", encoding="utf-8")
    sys.stdout = _Tee(sys.__stdout__, log_file)

    print("=" * 64)
    print("           ADMIN CLEANUP (Elevated)")
    print("=" * 64)
    if not is_admin() and not dry:
        sys.exit("Must run as Administrator!")
    before = free_c()

    # [0] firewall rule for the Docker backend port
    print("\n--- [0] Docker backend firewall rule ---")
    if dry:
        print("[dry-run] New-NetFirewallRule docker backend")
    else:
        asyncio.run(run_ps_command(
            "$b = \"$env:LOCALAPPDATA\\Programs\\DockerDesktop\\"
            "resources\\com.docker.backend.exe\"; "
            "if ((Test-Path $b) -and -not (Get-NetFirewallRule "
            "-DisplayName 'Docker Desktop Backend (user path)' "
            "-ErrorAction SilentlyContinue)) { New-NetFirewallRule "
            "-DisplayName 'Docker Desktop Backend (user path)' "
            "-Direction Inbound -Action Allow -Program $b "
            "-Profile Any -Enabled True | Out-Null; 'created' } "
            "else { 'exists-or-missing' }",
            timeout=60))

    print("\n--- [1] DISM Component Store Cleanup ---")
    rc = run(["Dism", "/Online", "/Cleanup-Image",
              "/StartComponentCleanup", "/NoRestart"], dry)
    print(f"[1] {'COMPLETED' if rc == 0 else f'EXIT CODE {rc}'}")

    print("\n--- [2] Windows Update Download Cache ---")
    wu = Path(r"C:\Windows\SoftwareDistribution\Download")
    if wu.is_dir() or dry:
        size = dir_size(wu) if not dry else 0
        run(["net", "stop", "wuauserv"], dry, echo=False)
        if not dry:
            for f in wu.iterdir():
                try:
                    if f.is_dir():
                        shutil.rmtree(f, ignore_errors=True)
                    else:
                        f.unlink()
                except OSError:
                    pass
        run(["net", "start", "wuauserv"], dry, echo=False)
        print(f"[2] Windows Update cache cleaned: -{gb(size)} GB")
    else:
        print("[2] Windows Update cache: path not found")

    print("\n--- [3] Delivery Optimization Cache ---")
    do_dir = Path(os.environ.get("LOCALAPPDATA", "")) / \
        "Microsoft" / "Windows" / "DeliveryOptimization"
    if dry:
        print("[dry-run] Remove-Item DO cache folder")
    elif do_dir.is_dir():
        size = dir_size(do_dir)
        shutil.rmtree(do_dir, ignore_errors=True)
        print(f"[3] Delivery Optimization cache: CLEARED "
              f"(-{gb(size)} GB)")
    else:
        print("[3] Delivery Optimization cache: not found")

    print("\n--- [4] System Restore Points (oldest only) ---")
    run(["vssadmin", "delete", "shadows", "/for=c:", "/oldest",
         "/quiet"], dry)

    print("\n--- [5] Windows.old ---")
    win_old = Path(r"C:\Windows.old")
    if win_old.is_dir() or dry:
        run(["takeown", "/f", r"C:\Windows.old", "/r", "/d", "y"],
            dry, echo=False)
        run(["icacls", r"C:\Windows.old", "/grant",
             "administrators:F", "/t", "/c", "/q"], dry, echo=False)
        if not dry:
            shutil.rmtree(win_old, ignore_errors=True)
        print("[5] Windows.old removed")
    else:
        print("[5] Windows.old: not found")

    if args.skip_vhdx:
        print("\n  [6] skipped via --skip-vhdx (Docker Desktop / WSL "
              "untouched)")
    else:
        print("\n--- [6] WSL VHDX compaction ---")
        wsl = "wsl.exe"
        if args.shutdown_wsl:
            print("  --shutdown-wsl: wsl --shutdown "
                  "(ALL distros stop)...")
            run([wsl, "--shutdown"], dry, echo=False)
            for d in ("docker-desktop", "Ubuntu-24.04"):
                run([wsl, "--manage", d, "--set-sparse", "true"],
                    dry, echo=False)
            compact_vhdx(DOCKER_DATA,
                         "docker_data.vhdx (post-shutdown)", dry)
            compact_vhdx(UBUNTU_VHDX, "Ubuntu ext4.vhdx", dry)
        else:
            run([wsl, "--manage", "docker-desktop",
                 "--set-sparse", "true"], dry, echo=False)
            run([wsl, "--terminate", "docker-desktop"], dry,
                echo=False)
            waited = 0
            while (DOCKER_DATA.is_file() and vhdx_locked(DOCKER_DATA)
                   and waited < 60):
                time.sleep(5)
                waited += 5
            if DOCKER_DATA.is_file() and not vhdx_locked(DOCKER_DATA):
                compact_vhdx(DOCKER_DATA, "docker_data.vhdx", dry)
            elif not dry:
                print(f"  docker_data.vhdx: still locked after "
                      f"{waited}s, skipped")
            if UBUNTU_VHDX.is_file():
                print("  Ubuntu ext4.vhdx: skipped (needs "
                      "--shutdown-wsl for full wsl --shutdown)")

    # [7] sshd repair + watch task
    sshd_repair = Path(r"D:\DevOptimizer\scripts\sshd-repair.ps1")
    if sshd_repair.is_file() and not dry:
        run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
             "-File", str(sshd_repair), "-RegisterTask"], dry)
        print("[7] sshd-repair ran")

    after = free_c()
    print(f"\n=== Summary ===")
    print(f"C: free before: {gb(before)} GB")
    print(f"C: free after : {gb(after)} GB")
    print(f"Freed on C:   : {gb(after - before)} GB")
    print("\nDone. A reboot is recommended after DISM operations.")


if __name__ == "__main__":
    main()
