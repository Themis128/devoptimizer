"""Elevated complete cleanup (port of
scripts/elevated-complete-cleanup.ps1).

Part 1: WSL/Docker VHDX compaction via Invoke-VhdxCompaction.ps1
-AsLibrary -ForceAll (Devin-safe, gated) — skip with --skip-vhdx.
Part 2: admin cleanup — DISM cleanup + RestoreHealth, SFC, WU cache
(service-stopped), Delete-DeliveryOptimizationCache, oldest shadow
copy, Windows.old — skip with --skip-admin-cleanup. Requires
elevation. Mutating; --dry-run.
"""

import argparse
import asyncio
import ctypes
import shutil
import time
import subprocess
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# REQUIRES: admin
# CATEGORY: cleanup
# TAGS: windows11, elevated, vhdx, dism, sfc, orchestrator


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def gb(b):
    return round(b / 2**30, 2)


def free_c():
    return shutil.disk_usage("C:\\").free


def dir_size(path):
    total = 0
    for f in Path(path).rglob("*"):
        try:
            if f.is_file():
                total += f.stat().st_size
        except OSError:
            pass
    return total


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


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--skip-vhdx", action="store_true")
    ap.add_argument("--skip-admin-cleanup", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run

    print("=" * 64)
    print("           ELEVATED COMPLETE CLEANUP (Admin Required)")
    print("=" * 64)
    if not is_admin() and not dry:
        print("[ERROR] This script MUST run as Administrator.",
              file=sys.stderr)
        sys.exit(1)

    if not args.skip_vhdx:
        print("\n=== PART 1: WSL/DOCKER VHDX COMPACTION ===")
        if dry:
            print("[dry-run] Invoke-VhdxCompaction.ps1 -AsLibrary "
                  "-ForceAll")
        else:
            r = asyncio.run(run_ps_command(
                "& 'D:\\DevOptimizer\\scripts"
                "\\Invoke-VhdxCompaction.ps1' -AsLibrary -ForceAll; "
                "Write-Host (\"PART 1 result: \" + "
                "$global:LAST_VHDX_COMPACTION.status)",
                timeout=3600))
            if r.stdout.strip():
                print(r.stdout.strip())

    if not args.skip_admin_cleanup:
        print("\n=== PART 2: WINDOWS 11 ADMIN CLEANUP ===")
        before = free_c()
        print(f"C: free before: {gb(before)} GB")

        print("\n--- [1] DISM Component Store Cleanup ---")
        rc = run(["Dism", "/Online", "/Cleanup-Image",
                  "/StartComponentCleanup", "/NoRestart"], dry)
        print(f"[1] DISM component cleanup: "
              f"{'COMPLETED' if rc == 0 else f'EXIT CODE {rc}'}")

        print("\n--- [1b] DISM RestoreHealth (Repair) ---")
        print("This may take 10-30 minutes...")
        rc = run(["Dism", "/Online", "/Cleanup-Image",
                  "/RestoreHealth"], dry)
        print(f"[1b] DISM RestoreHealth: "
              f"{'COMPLETED' if rc == 0 else f'EXIT CODE {rc}'}")

        print("\n--- [1c] SFC /scannow ---")
        rc = run(["sfc", "/scannow"], dry)
        print(f"[1c] SFC: "
              f"{'COMPLETED' if rc == 0 else f'EXIT CODE {rc}'}")

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
            print("[2] Windows Update cache: not found")

        print("\n--- [3] Delivery Optimization Cache ---")
        if dry:
            print("[dry-run] Delete-DeliveryOptimizationCache")
        else:
            r = asyncio.run(run_ps_command(
                "try { Delete-DeliveryOptimizationCache -Force "
                "-ErrorAction Stop; '[3] CLEARED' } "
                "catch { '[3] SKIPPED (' + "
                "$_.Exception.Message.Split([char]10)[0] + ')' }",
                timeout=600))
            print(r.stdout.strip() or "[3] (no output)")

        print("\n--- [4] Shadow Copies (oldest) ---")
        rc = run(["vssadmin", "delete", "shadows", "/for=c:", "/oldest",
                  "/quiet"], dry)
        shadow_status = ("DELETED" if rc == 0
                         else f"EXIT CODE {rc} (may be none)")
        print(f"[4] Oldest shadow copy: {shadow_status}")

        print("\n--- [5] Windows.old folder (if present) ---")
        win_old = Path(r"C:\Windows.old")
        if win_old.is_dir() or dry:
            size = dir_size(win_old) if not dry else 0
            print(f"Found Windows.old ({gb(size)} GB) - removing...")
            run(["takeown", "/f", r"C:\Windows.old", "/r", "/d", "y"],
                dry, echo=False)
            run(["icacls", r"C:\Windows.old", "/grant",
                 "administrators:F", "/t", "/c", "/q"], dry, echo=False)
            if not dry:
                shutil.rmtree(win_old, ignore_errors=True)
            print(f"[5] Windows.old removed: -{gb(size)} GB")
        else:
            print("[5] Windows.old: not found")

        print("\n--- [6] WER archives + crash dumps ---")
        cutoff = time.time() - 30 * 86400
        freed = 0
        for dp in (r"C:\ProgramData\Microsoft\Windows\WER"
                   r"\ReportArchive",
                   r"C:\ProgramData\Microsoft\Windows\WER"
                   r"\ReportQueue",
                   r"C:\Windows\Minidump",
                   r"C:\Windows\MEMORY.DMP"):
            p = Path(dp)
            if dry:
                print(f"[dry-run] sweep {dp} (>30d)")
                continue
            if not p.exists():
                continue
            items = [p] if p.is_file() else [
                f for f in p.rglob("*") if f.is_file()]
            for f in items:
                try:
                    if f.stat().st_mtime < cutoff:
                        freed += f.stat().st_size
                        f.unlink()
                except OSError:
                    pass
        print(f"[6] Crash dumps cleared: -{gb(freed)} GB")

        after = free_c()
        print("\n=== Admin Cleanup Summary ===")
        print(f"C: free before: {gb(before)} GB")
        print(f"C: free after : {gb(after)} GB")
        print(f"Freed on C:   : {gb(after - before)} GB")


if __name__ == "__main__":
    main()
