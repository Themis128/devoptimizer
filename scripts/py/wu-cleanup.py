"""Windows Update cache and component cleanup (Python port of windows-update-cleanup.ps1).

Python port of windows-update-cleanup.ps1
Windows Update cache and component cleanup.
"""

import argparse
import asyncio
import json
import os
import shutil
import sys
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command, run_elevated  # noqa: E402
from devoptimizer_cli.core import winops  # noqa: E402

# CATEGORY: cleanup
# TAGS: windows-update, cleanup, cache


def log(level: str, message: str) -> None:
    print(f"[{level}] {message}")


def dir_size(path: Path) -> int:
    """Sum of file sizes under path; 0 if missing or unreadable."""
    try:
        if not path.exists():
            return 0
    except OSError:
        return 0
    total = 0
    try:
        for item in path.rglob("*"):
            try:
                if item.is_file():
                    total += item.stat().st_size
            except OSError:
                continue
    except OSError:
        pass
    return total


def rmtree_contents(path: Path) -> int:
    """Delete everything inside path (not the folder itself). Returns bytes freed."""
    freed = 0
    try:
        for item in path.iterdir():
            try:
                if item.is_dir():
                    size = dir_size(item)
                    shutil.rmtree(item, ignore_errors=True)
                else:
                    size = item.stat().st_size
                    item.unlink()
                freed += size
            except OSError:
                continue
    except OSError:
        pass
    return freed


async def service_state(name: str) -> str:
    """Service status via sc.exe query (Running/Stopped/...)."""
    result = await run_command(["sc.exe", "query", name], timeout=15)
    if result.returncode != 0:
        return "NotFound"
    for line in result.stdout.splitlines():
        if "STATE" in line and "RUNNING" in line:
            return "Running"
        if "STATE" in line and "STOPPED" in line:
            return "Stopped"
    return "Unknown"


async def stop_service(name: str) -> bool:
    result = await run_elevated(["net", "stop", name], timeout=60)
    return result.returncode == 0


async def start_service(name: str) -> bool:
    result = await run_elevated(["net", "start", name], timeout=60)
    return result.returncode == 0


WINDIR = Path(os.environ.get("WINDIR", r"C:\Windows"))
CACHE_FOLDER = WINDIR / "SoftwareDistribution"
DOWNLOAD_CACHE = WINDIR / "SoftwareDistribution" / "Download"
BACKUP_FOLDER = WINDIR / "SoftwareDistribution.bak"


async def get_wu_status() -> dict:
    """Report service states, last-check time, cache size, and recent errors."""
    log("INFO", "Checking Windows Update status...")
    out: dict = {"services": {}, "lastCheck": None, "cacheSizeMB": 0.0, "errors": []}

    for svc in ("wuauserv", "BITS", "CryptSvc"):
        state = await service_state(svc)
        out["services"][svc] = state
        log("SUCCESS" if state == "Running" else "WARN", f"{svc}: {state}")

    last = winops.reg_get(
        r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Detect",
        "LastSuccessTime",
    )
    if last:
        out["lastCheck"] = str(last)
        log("INFO", f"Last successful check: {last}")

    size = dir_size(DOWNLOAD_CACHE)
    out["cacheSizeMB"] = round(size / 1048576, 2)
    log("INFO", f"Update cache size: {out['cacheSizeMB']} MB")

    result = await run_command(
        [
            "wevtutil.exe", "qe", "System",
            "/q:*[System[(EventID=7000 or EventID=7001 or EventID=7023 or EventID=7034)]]",
            "/c:50", "/rd:true", "/f:text",
        ],
        timeout=30,
    )
    if result.returncode == 0 and result.stdout:
        text = result.stdout
        recent = [
            ln for ln in text.splitlines()
            if "windows update" in ln.lower() or "wuauserv" in ln.lower() or "bits" in ln.lower()
        ]
        out["errors"] = recent[:20]
        if recent:
            log("WARN", f"Found {len(recent)} Windows Update related log lines (last 50 service events)")
    return out


WU_SERVICES = ("wuauserv", "cryptSvc", "bits", "msiserver")
PROBLEMATIC_VALUES = ("UseWUServer", "WUServer", "WUStatusServer", "NoAutoUpdate")
POLICY_PATHS = (
    r"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",
    r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
)
WU_DLLS = (
    "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
    "jscript.dll", "vbscript.dll", "scrrun.dll" if False else "scrrun.dll", "msxml.dll", "msxml3.dll",
    "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll",
    "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll",
    "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", "wuapi.dll",
    "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll",
    "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll", "wuwebv.dll",
)


async def reset_wu_components(dry_run: bool = False) -> bool:
    """Stop WU services, rename cache folder, clear policies, re-register DLLs, reset winsock, restart."""
    log("INFO", "Resetting actions: services, cache rename, policies, DLLs, winsock, restart.")
    if dry_run:
        log("INFO", f"[DRY RUN] Would stop services: {', '.join(WU_SERVICES)}")
        log("INFO", f"[DRY RUN] Would rename {CACHE_FOLDER} to {BACKUP_FOLDER.name}")
        log("INFO", f"[DRY RUN] Would remove registry values: {', '.join(PROBLEMATIC_VALUES)}")
        log("INFO", f"[DRY RUN] Would re-register {len(WU_DLLS)} WU DLLs and reset Winsock")
        log("INFO", f"[DRY RUN] Would restart services: {', '.join(WU_SERVICES)}")
        return True

    for svc in WU_SERVICES:
        if await service_state(svc) == "Running":
            if await stop_service(svc):
                log("SUCCESS", f"Stopped service: {svc}")
            else:
                log("WARN", f"Could not stop service: {svc}")
    await asyncio.sleep(3)

    try:
        if BACKUP_FOLDER.exists():
            shutil.rmtree(BACKUP_FOLDER, ignore_errors=True)
        CACHE_FOLDER.rename(BACKUP_FOLDER)
        log("SUCCESS", "Windows Update cache backed up and cleared")
    except OSError as e:
        log("WARN", f"Could not clear Windows Update cache: {e}")

    for path in POLICY_PATHS:
        for value in PROBLEMATIC_VALUES:
            if winops.reg_delete(path, value):
                log("SUCCESS", f"Removed registry value: {value}")

    registered = 0
    for dll in WU_DLLS:
        result = await run_elevated(["regsvr32.exe", "/s", dll], timeout=30)
        if result.returncode == 0:
            registered += 1
    log("SUCCESS", f"Re-registered {registered} Windows Update DLLs")

    result = await run_elevated(["netsh", "winsock", "reset"], timeout=60)
    log("SUCCESS" if result.returncode == 0 else "WARN", "Winsock reset" + ("" if result.returncode == 0 else " failed"))

    for svc in WU_SERVICES:
        if await start_service(svc):
            log("SUCCESS", f"Started service: {svc}")
        else:
            log("WARN", f"Service may not have started properly: {svc}")

    log("SUCCESS", "Windows Update components reset completed!")
    log("INFO", "RECOMMENDATION: Restart your computer and then check for updates")
    return True


async def clear_wu_cache(include_history: bool = False, dry_run: bool = False) -> int:
    """Clear the WU download cache, WU logs, optional history, and CBS logs older than 30 days."""
    log("INFO", "Clearing Windows Update cache...")
    was_running = await service_state("wuauserv") == "Running"
    total = 0

    targets: list[Path] = build_targets(include_history)
    if dry_run:
        for t in targets:
            log("INFO", f"[DRY RUN] Would clear {t} ({round(dir_size(t) / 1048576, 2)} MB)")
        return 0

    if was_running:
        await stop_service("wuauserv")
        await asyncio.sleep(2)

    for t in targets:
        if t.is_file():
            size = t.stat().st_size
            try:
                t.unlink()
                total += size
            except OSError:
                pass
        else:
            total += rmtree_contents(t)
            log("SUCCESS", f"Cleared {t.name}: {round(total / 1048576, 2)} MB cumulative")

    cbs = WINDIR / "Logs" / "CBS"
    if cbs.exists():
        cutoff = time.time() - 30 * 86400
        for item in cbs.iterdir():
            try:
                if item.is_file() and item.stat().st_mtime < cutoff:
                    size = item.stat().st_size
                    item.unlink()
                    total += size
            except OSError:
                continue

    if was_running:
        await start_service("wuauserv")

    log("SUCCESS", f"Windows Update cache cleanup completed: {round(total / 1048576, 2)} MB freed")
    return total


def build_targets(include_history: bool) -> list[Path]:
    targets: list[Path] = []
    if DOWNLOAD_CACHE.exists():
        targets.append(DOWNLOAD_CACHE)
    if (WINDIR / "WindowsUpdate.log").exists():
        targets.append(WINDIR / "WindowsUpdate.log")
    if (WINDIR / "Logs" / "WindowsUpdate").exists():
        targets.append(WINDIR / "Logs" / "WindowsUpdate")
    if include_history and (CACHE_FOLDER / "DataStore").exists():
        targets.append(CACHE_FOLDER / "DataStore")
    return targets


async def fix_wu_errors(dry_run: bool = False) -> bool:
    """SFC + DISM check/scan/repair sequence (elevated)."""
    log("INFO", "Running Windows Update troubleshooter and fixes...")
    if dry_run:
        log("INFO", "[DRY RUN] Would run: sfc /scannow")
        log("INFO", "[DRY RUN] Would run: DISM /Online /Cleanup-Image /CheckHealth")
        log("INFO", "[DRY RUN] Would run: DISM /Online /Cleanup-Image /ScanHealth")
        log("INFO", "[DRY RUN] Would run DISM /RestoreHealth only if scan reports corruption")
        return True

    log("INFO", "Running System File Checker (SFC)...")
    sfc = await run_elevated(["sfc", "/scannow"], timeout=1200)
    log("SUCCESS" if sfc.returncode == 0 else "WARN", f"SFC scan exit code {sfc.returncode}")

    log("INFO", "Running DISM to check Windows image health...")
    await run_elevated(["Dism.exe", "/Online", "/Cleanup-Image", "/CheckHealth"], timeout=300)
    log("INFO", "Scanning Windows image health (this may take several minutes)...")
    scan = await run_elevated(["Dism.exe", "/Online", "/Cleanup-Image", "/ScanHealth"], timeout=1800)
    combined = (scan.stdout + scan.stderr).lower()
    if "corrupt" in combined:
        log("WARN", "DISM found corruption - attempting repair...")
        restore = await run_elevated(["Dism.exe", "/Online", "/Cleanup-Image", "/RestoreHealth"], timeout=3600)
        log("SUCCESS" if restore.returncode == 0 else "ERROR",
            "DISM repair " + ("completed successfully" if restore.returncode == 0 else "may have failed - manual intervention may be required"))
    else:
        log("SUCCESS", "DISM scan completed - Windows image is healthy")
    return True


async def main_async() -> int:
    parser = argparse.ArgumentParser(description="Windows Update cache and component cleanup")
    parser.add_argument("action", choices=["status", "reset", "clear-cache", "fix", "report"], nargs="?", default="report")
    parser.add_argument("--dry-run", action="store_true", help="Show planned actions without executing")
    parser.add_argument("--include-history", action="store_true", help="clear-cache: also clear update history (DataStore)")
    parser.add_argument("--json", action="store_true", help="Emit JSON output (status/report only)")
    args = parser.parse_args()

    if args.action in ("status", "report"):
        data = await get_wu_status()
        if args.json:
            print(json.dumps(data, indent=2))
        else:
            healthy = data["services"].get("wuauserv") == "Running"
            print(f"Verdict: {'HEALTHY' if healthy else 'WU SERVICE NOT RUNNING'}")
    elif args.action == "reset":
        await reset_wu_components(dry_run=args.dry_run)
    elif args.action == "clear-cache":
        await clear_wu_cache(include_history=args.include_history, dry_run=args.dry_run)
    elif args.action == "fix":
        await fix_wu_errors(dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main_async()))
