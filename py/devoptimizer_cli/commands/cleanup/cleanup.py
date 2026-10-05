"""
win11-safe-cleanup migration — Windows 11 safe cleanup for DevOptimizer (non-admin scope)

Cleans user-level temp/caches, dev package-manager caches, Docker build
cache and dangling images. Does NOT touch containers (running or stopped),
volumes, models, or user data. Admin-only items are reported at the end.
"""

from __future__ import annotations

import asyncio
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from devoptimizer_cli.core.executor import run_command, run_elevated
from devoptimizer_cli.core.logging import get_logger
from devoptimizer_cli.models.command import CommandResult

log = get_logger(__name__)


@dataclass
class CleanupParams:
    """Parameters for win11-safe-cleanup (no admin required)."""
    dry_run: bool = False
    skip_docker: bool = False
    skip_recycle_bin: bool = False


async def get_free_space_gb(path: str) -> float:
    """Get free space in GB for a given path."""
    try:
        usage = shutil.disk_usage(path)
        return round(usage.free / (1024 ** 3), 2)
    except Exception as e:
        log.warning(f"Failed to get disk usage for {path}: {e}")
        return 0.0


async def clean_directory(path: Path, description: str) -> int:
    """Clean a directory and return bytes freed."""
    if not path.exists():
        log.info(f"[{description}] Path does not exist: {path}")
        return 0

    total_freed = 0
    try:
        for item in path.rglob("*"):
            if item.is_file():
                try:
                    size = item.stat().st_size
                    item.unlink()
                    total_freed += size
                except (PermissionError, OSError):
                    continue
            elif item.is_dir():
                try:
                    item.rmdir()
                except (PermissionError, OSError):
                    continue
    except Exception as e:
        log.warning(f"[{description}] Error cleaning {path}: {e}")

    return total_freed


async def run_dev_cache_clean(name: str, cmd: list[str]) -> tuple[bool, str]:
    """Run a dev package manager cache clean command."""
    try:
        result = await run_command(cmd, timeout=60)
        if result.returncode == 0:
            return True, "cleaned"
        return False, f"exit {result.returncode}: {result.stderr[:100]}"
    except FileNotFoundError:
        return False, "not installed"


async def clean_recycle_bin() -> tuple[bool, str]:
    """Empty recycle bin using PowerShell."""
    try:
        result = await run_command([
            "powershell", "-NoProfile", "-Command",
            "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"
        ], timeout=30)
        if result.returncode == 0:
            return True, "emptied"
        return False, f"exit {result.returncode}: {result.stderr[:100]}"
    except Exception as e:
        return False, str(e)


async def run_docker_clean() -> list[tuple[str, str]]:
    """Run Docker safe cleanup: build cache + dangling images only."""
    results = []
    
    # Build cache
    try:
        result = await run_command([
            "docker", "builder", "prune", "-f", "--filter", "until=24h"
        ], timeout=120)
        results.append(("Build cache", "cleaned" if result.returncode == 0 else f"failed: {result.stderr[:80]}"))
    except FileNotFoundError:
        results.append(("Build cache", "docker not found"))
    
    # Dangling images
    try:
        result = await run_command([
            "docker", "image", "prune", "-f", "--filter", "dangling=true"
        ], timeout=120)
        results.append(("Dangling img", "cleaned" if result.returncode == 0 else f"failed: {result.stderr[:80]}"))
    except FileNotFoundError:
        results.append(("Dangling img", "docker not found"))
    
    return results


async def run(params: dict[str, Any]) -> CommandResult:
    """Main entry point for win11-safe-cleanup."""
    p = CleanupParams(
        dry_run=params.get("dry_run", False),
        skip_docker=params.get("skip_docker", False),
        skip_recycle_bin=params.get("skip_recycle_bin", False),
    )

    log.info("Starting win11-safe-cleanup", extra={"params": params})
    
    before_free = await get_free_space_gb("C:\\")
    freed_bytes = 0
    output_lines = ["=== win11-safe-cleanup (non-admin) ==="]
    warnings = []

    if p.dry_run:
        output_lines.append("[DRY RUN] No files will be deleted")

    # 1. User temp
    output_lines.append("\n--- User Temp ---")
    temp_path = Path(os.environ.get("TEMP", "C:\\Windows\\Temp"))
    if p.dry_run:
        size = sum(f.stat().st_size for f in temp_path.rglob("*") if f.is_file()) if temp_path.exists() else 0
        output_lines.append(f"[1] {temp_path.name:<30}: would free {round(size / 1_048_576, 1)} MB")
    else:
        size = await clean_directory(temp_path, "User Temp")
        freed_bytes += size
        output_lines.append(f"[1] {temp_path.name:<30}: -{round(size / 1_048_576, 1)} MB")

    # 2. User cache
    output_lines.append("\n--- User Cache ---")
    cache_dirs = [
        (Path.home() / "AppData" / "Local" / "Temp", "Local Temp"),
        (Path.home() / "AppData" / "Local" / "Microsoft" / "Windows" / "INetCache", "INetCache"),
    ]
    for path, desc in cache_dirs:
        if p.dry_run:
            size = sum(f.stat().st_size for f in path.rglob("*") if f.is_file()) if path.exists() else 0
            output_lines.append(f"[2] {desc:<30}: would free {round(size / 1_048_576, 1)} MB")
        else:
            size = await clean_directory(path, desc)
            freed_bytes += size
            output_lines.append(f"[2] {desc:<30}: -{round(size / 1_048_576, 1)} MB")

    # 3. Dev package manager caches
    output_lines.append("\n--- Dev Package Caches ---")
    dev_caches = [
        ("pip", ["pip", "cache", "purge"]),
        ("npm", ["npm", "cache", "clean", "--force"]),
        ("yarn", ["yarn", "cache", "clean"]),
        ("pnpm", ["pnpm", "store", "prune"]),
        ("cargo", ["cargo", "clean"]),
        ("go", ["go", "clean", "-cache"]),
        ("gradle", ["./gradlew", "--stop"]),
        ("maven", ["mvn", "dependency:purge-local-repository"]),
    ]
    
    for name, cmd in dev_caches:
        if p.dry_run:
            output_lines.append(f"[3] {name:<12}: would run {' '.join(cmd)}")
        else:
            success, msg = await run_dev_cache_clean(name, cmd)
            status = "cleaned" if success else f"skipped ({msg})"
            output_lines.append(f"[3] {name:<12}: {status}")
            if not success and "not installed" not in msg:
                warnings.append(f"{name}: {msg}")

    # 4. Browser caches (Edge/Chrome/Firefox)
    output_lines.append("\n--- Browser Caches ---")
    browser_caches = [
        (Path.home() / "AppData" / "Local" / "Microsoft" / "Edge" / "User Data" / "Default" / "Cache", "Edge"),
        (Path.home() / "AppData" / "Local" / "Google" / "Chrome" / "User Data" / "Default" / "Cache", "Chrome"),
        (Path.home() / "AppData" / "Local" / "Mozilla" / "Firefox" / "Profiles", "Firefox"),
    ]
    for path, desc in browser_caches:
        if path.exists():
            if p.dry_run:
                size = sum(f.stat().st_size for f in path.rglob("*") if f.is_file())
                output_lines.append(f"[4] {desc:<30}: would free {round(size / 1_048_576, 1)} MB")
            else:
                size = await clean_directory(path, f"Cache: {desc}")
                freed_bytes += size
                output_lines.append(f"[4] {desc:<30}: -{round(size / 1_048_576, 1)} MB")
        else:
            output_lines.append(f"[4] {desc:<30}: not found")

    # 5. Recycle bin
    if not p.skip_recycle_bin:
        success, msg = await clean_recycle_bin()
        if success:
            output_lines.append("[5] Recycle bin emptied")
        else:
            output_lines.append(f"[5] Recycle bin: skipped ({msg})")
            warnings.append(f"Recycle bin: {msg}")
    else:
        output_lines.append("[5] Recycle bin: skipped (--skip-recycle-bin)")

    # 6. Docker: build cache + dangling images ONLY
    if not p.skip_docker:
        output_lines.append("\n--- Docker (safe subset) ---")
        docker_results = await run_docker_clean()
        for name, msg in docker_results:
            output_lines.append(f"[6] {name:<12}: {msg}")
        output_lines.append("Containers/volumes/named images: untouched")
    else:
        output_lines.append("\n--- Docker (safe subset) ---")
        output_lines.append("[6] Docker: skipped (--skip-docker)")

    # Summary
    after_free = await get_free_space_gb("C:\\")
    freed_mb = round(freed_bytes / 1_048_576, 1)
    actual_freed = round((after_free - before_free) * 1024, 1)

    output_lines.append("\n=== Summary ===")
    output_lines.append(f"C: free after : {after_free:.2f} GB")
    output_lines.append(f"Freed on C:   : {actual_freed:.2f} MB (measured)")
    output_lines.append(f"Calculated freed: {freed_mb:.1f} MB")

    # Admin-required items
    output_lines.append("\nRequires Administrator (run DevOptimizer cleanup elevated for these):")
    output_lines.append("  - DISM component store cleanup : Dism /Online /Cleanup-Image /StartComponentCleanup")
    output_lines.append("  - Windows Update download cache: Stop wuauserv, clear C:\\Windows\\SoftwareDistribution\\Download")
    output_lines.append("  - Delivery Optimization cache  : Delete-DeliveryOptimizationCache (elevated PowerShell)")
    output_lines.append("  - System restore points / shadow copies: vssadmin delete shadows /for=c: /oldest")

    stdout = "\n".join(output_lines)
    stderr = "\n".join(warnings) if warnings else ""

    log.info("win11-safe-cleanup completed", extra={
        "before_gb": before_free,
        "after_gb": after_free,
        "freed_mb": actual_freed,
        "warnings": warnings
    })

    return CommandResult(
        exit_code=0,
        stdout=stdout,
        stderr=stderr,
        data={
            "before_free_gb": before_free,
            "after_free_gb": after_free,
            "freed_mb": actual_freed,
            "warnings": warnings
        }
    )


import typer
from rich.console import Console

app = typer.Typer(
    name="cleanup",
    help="System cleanup commands",
    add_completion=False,
    rich_markup_mode="rich"
)

console = Console()


@app.command("win11-safe-cleanup")
def win11_safe_cleanup_cmd(
    dry_run: bool = typer.Option(False, "--dry-run", help="Show what would be cleaned without deleting"),
    skip_docker: bool = typer.Option(False, "--skip-docker", help="Skip Docker cleanup"),
    skip_recycle_bin: bool = typer.Option(False, "--skip-recycle-bin", help="Skip recycle bin emptying"),
    json_output: bool = typer.Option(False, "--json", help="Output results as JSON"),
):
    """Windows 11 safe cleanup (non-admin scope)."""
    result = asyncio.run(run({
        "dry_run": dry_run,
        "skip_docker": skip_docker,
        "skip_recycle_bin": skip_recycle_bin,
    }))

    if json_output:
        import json
        console.print_json(json.dumps(result.to_dict()))
    else:
        console.print(result.stdout)
        if result.stderr:
            console.print(result.stderr, style="yellow")

    raise typer.Exit(result.exit_code)


@dataclass
class AdminCleanupParams:
    """Parameters for win11-admin-cleanup (requires elevation)."""
    dry_run: bool = False
    skip_dism: bool = False
    skip_sfc: bool = False
    skip_wu_cache: bool = False
    skip_do_cache: bool = False
    skip_shadow: bool = False
    skip_windows_old: bool = False


async def run_admin_cleanup(params: dict[str, Any]) -> CommandResult:
    """Main entry point for win11-admin-cleanup (requires elevation)."""
    p = AdminCleanupParams(
        dry_run=params.get("dry_run", False),
        skip_dism=params.get("skip_dism", False),
        skip_sfc=params.get("skip_sfc", False),
        skip_wu_cache=params.get("skip_wu_cache", False),
        skip_do_cache=params.get("skip_do_cache", False),
        skip_shadow=params.get("skip_shadow", False),
        skip_windows_old=params.get("skip_windows_old", False),
    )

    log.info("Starting win11-admin-cleanup", extra={"params": params})

    before_free = await get_free_space_gb("C:\\")
    output_lines = ["=== Windows 11 Admin Cleanup (elevated) ==="]
    warnings = []

    if p.dry_run:
        output_lines.append("[DRY RUN] No commands will be executed")

    # Helper to run elevated commands
    async def run_elevated_cmd(cmd: list[str], description: str, timeout: int = 600) -> tuple[bool, str]:
        """Run a command with elevation and return success, output."""
        if p.dry_run:
            output_lines.append(f"  [DRY RUN] Would run: {' '.join(cmd)}")
            return True, "dry-run"
        
        try:
            result = await run_elevated(cmd, timeout=timeout)
            output = result.stdout + result.stderr
            for line in output.strip().split('\n'):
                if line.strip():
                    output_lines.append(f"  {line.strip()}")
            return result.returncode == 0, output
        except Exception as e:
            return False, str(e)

    # 1. DISM Component Store Cleanup
    if not p.skip_dism:
        output_lines.append("\n--- [1] DISM Component Store Cleanup ---")
        success, output = await run_elevated_cmd(
            ["Dism", "/Online", "/Cleanup-Image", "/StartComponentCleanup", "/NoRestart"],
            "DISM Component Cleanup",
            timeout=300
        )
        status = "COMPLETED" if success else f"EXIT CODE != 0"
        output_lines.append(f"[1] DISM component cleanup: {status}")
        if not success:
            warnings.append(f"DISM component cleanup failed: {output[:200]}")
    else:
        output_lines.append("\n--- [1] DISM Component Store Cleanup ---")
        output_lines.append("[1] DISM component cleanup: skipped (--skip-dism)")

    # 2. DISM RestoreHealth
    if not p.skip_dism:
        output_lines.append("\n--- [2] DISM RestoreHealth (Repair) ---")
        output_lines.append("  This may take 10-30 minutes...")
        success, output = await run_elevated_cmd(
            ["Dism", "/Online", "/Cleanup-Image", "/RestoreHealth"],
            "DISM RestoreHealth",
            timeout=1800
        )
        status = "COMPLETED" if success else f"EXIT CODE != 0"
        output_lines.append(f"[2] DISM RestoreHealth: {status}")
        if not success:
            warnings.append(f"DISM RestoreHealth failed: {output[:200]}")
    else:
        output_lines.append("\n--- [2] DISM RestoreHealth (Repair) ---")
        output_lines.append("[2] DISM RestoreHealth: skipped (--skip-dism)")

    # 3. SFC /scannow
    if not p.skip_sfc:
        output_lines.append("\n--- [3] SFC /scannow ---")
        success, output = await run_elevated_cmd(
            ["sfc", "/scannow"],
            "SFC Scan",
            timeout=600
        )
        status = "COMPLETED" if success else f"EXIT CODE != 0"
        output_lines.append(f"[3] SFC: {status}")
        if not success:
            warnings.append(f"SFC failed: {output[:200]}")
    else:
        output_lines.append("\n--- [3] SFC /scannow ---")
        output_lines.append("[3] SFC: skipped (--skip-sfc)")

    # 4. Windows Update Download Cache
    if not p.skip_wu_cache:
        output_lines.append("\n--- [4] Windows Update Download Cache ---")
        wu_path = Path("C:/Windows/SoftwareDistribution/Download")
        if wu_path.exists():
            if p.dry_run:
                size = sum(f.stat().st_size for f in wu_path.rglob("*") if f.is_file())
                output_lines.append(f"  Would clear {wu_path} ({round(size / (1024**3), 2)} GB)")
            else:
                size = sum(f.stat().st_size for f in wu_path.rglob("*") if f.is_file())
                output_lines.append(f"  Stopping wuauserv...")
                await run_elevated_cmd(["net", "stop", "wuauserv"], "Stop wuauserv", timeout=30)
                await asyncio.sleep(2)
                output_lines.append(f"  Clearing {wu_path} ({round(size / (1024**3), 2)} GB)...")
                for item in wu_path.rglob("*"):
                    if item.is_file():
                        try:
                            item.unlink()
                        except (PermissionError, OSError):
                            pass
                await run_elevated_cmd(["net", "start", "wuauserv"], "Start wuauserv", timeout=30)
                output_lines.append(f"[4] Windows Update cache cleaned: -{round(size / (1024**3), 2)} GB")
        else:
            output_lines.append("[4] Windows Update cache: not found")
    else:
        output_lines.append("\n--- [4] Windows Update Download Cache ---")
        output_lines.append("[4] Windows Update cache: skipped (--skip-wu-cache)")

    # 5. Delivery Optimization Cache
    if not p.skip_do_cache:
        output_lines.append("\n--- [5] Delivery Optimization Cache ---")
        if p.dry_run:
            output_lines.append("  Would run: Delete-DeliveryOptimizationCache")
        else:
            try:
                result = await run_elevated([
                    "powershell", "-NoProfile", "-Command",
                    "Delete-DeliveryOptimizationCache -Confirm:$false -ErrorAction Stop"
                ], timeout=60)
                if result.returncode == 0:
                    output_lines.append("[5] Delivery Optimization cache: CLEARED")
                else:
                    output_lines.append(f"[5] Delivery Optimization cache: SKIPPED ({result.stderr[:100]})")
                    warnings.append(f"Delivery Optimization cache: {result.stderr[:200]}")
            except Exception as e:
                output_lines.append(f"[5] Delivery Optimization cache: SKIPPED ({e})")
                warnings.append(f"Delivery Optimization cache: {e}")
    else:
        output_lines.append("\n--- [5] Delivery Optimization Cache ---")
        output_lines.append("[5] Delivery Optimization cache: skipped (--skip-do-cache)")

    # 6. Shadow Copies (oldest)
    if not p.skip_shadow:
        output_lines.append("\n--- [6] Shadow Copies (oldest) ---")
        if p.dry_run:
            output_lines.append("  Would run: vssadmin delete shadows /for=c: /oldest /quiet")
        else:
            success, output = await run_elevated_cmd(
                ["vssadmin", "delete", "shadows", "/for=c:", "/oldest", "/quiet"],
                "VSS Admin Delete Shadows",
                timeout=60
            )
            status = "DELETED" if success else f"EXIT CODE != 0 (may be none)"
            output_lines.append(f"[6] Oldest shadow copy: {status}")
            if not success and "may be none" not in status.lower():
                warnings.append(f"Shadow copy deletion: {output[:200]}")
    else:
        output_lines.append("\n--- [6] Shadow Copies (oldest) ---")
        output_lines.append("[6] Shadow copy: skipped (--skip-shadow)")

    # 7. Windows.old
    if not p.skip_windows_old:
        output_lines.append("\n--- [7] Windows.old (if present) ---")
        win_old = Path("C:/Windows.old")
        if win_old.exists():
            if p.dry_run:
                size = sum(f.stat().st_size for f in win_old.rglob("*") if f.is_file())
                output_lines.append(f"  Found Windows.old ({round(size / (1024**3), 2)} GB) - would remove")
            else:
                size = sum(f.stat().st_size for f in win_old.rglob("*") if f.is_file())
                output_lines.append(f"  Found Windows.old ({round(size / (1024**3), 2)} GB) - removing...")
                await run_elevated_cmd(["takeown", "/f", str(win_old), "/r", "/d", "y"], "Take ownership", timeout=60)
                await run_elevated_cmd(["icacls", str(win_old), "/grant", "administrators:F", "/t", "/c", "/q"], "Grant permissions", timeout=60)
                for item in win_old.rglob("*"):
                    if item.is_file():
                        try:
                            item.unlink()
                        except (PermissionError, OSError):
                            pass
                    elif item.is_dir():
                        try:
                            item.rmdir()
                        except (PermissionError, OSError):
                            pass
                output_lines.append(f"[7] Windows.old removed: -{round(size / (1024**3), 2)} GB")
        else:
            output_lines.append("[7] Windows.old: not found")
    else:
        output_lines.append("\n--- [7] Windows.old (if present) ---")
        output_lines.append("[7] Windows.old: skipped (--skip-windows-old)")

    # Summary
    after_free = await get_free_space_gb("C:\\")
    
    output_lines.append("\n=== Summary ===")
    output_lines.append(f"C: free before: {before_free:.2f} GB")
    output_lines.append(f"C: free after : {after_free:.2f} GB")
    output_lines.append(f"Freed on C:   : {round((after_free - before_free) * 1024, 2)} MB")
    output_lines.append("\nDone. Reboot recommended after DISM/SFC." if not p.dry_run else "\n[DRY RUN] No changes made.")

    stdout = "\n".join(output_lines)
    stderr = "\n".join(warnings) if warnings else ""

    log.info("win11-admin-cleanup completed", extra={
        "before_gb": before_free,
        "after_gb": after_free,
        "freed_mb": round((after_free - before_free) * 1024, 2),
        "warnings": warnings
    })

    return CommandResult(
        exit_code=0,
        stdout=stdout,
        stderr=stderr,
        data={
            "before_free_gb": before_free,
            "after_free_gb": after_free,
            "freed_mb": round((after_free - before_free) * 1024, 2),
            "warnings": warnings
        }
    )


@app.command("win11-admin-cleanup")
def win11_admin_cleanup_cmd(
    dry_run: bool = typer.Option(False, "--dry-run", help="Show what would be cleaned without executing"),
    skip_dism: bool = typer.Option(False, "--skip-dism", help="Skip DISM component cleanup and RestoreHealth"),
    skip_sfc: bool = typer.Option(False, "--skip-sfc", help="Skip SFC /scannow"),
    skip_wu_cache: bool = typer.Option(False, "--skip-wu-cache", help="Skip Windows Update cache"),
    skip_do_cache: bool = typer.Option(False, "--skip-do-cache", help="Skip Delivery Optimization cache"),
    skip_shadow: bool = typer.Option(False, "--skip-shadow", help="Skip shadow copy deletion"),
    skip_windows_old: bool = typer.Option(False, "--skip-windows-old", help="Skip Windows.old removal"),
    json_output: bool = typer.Option(False, "--json", help="Output results as JSON"),
):
    """Windows 11 admin cleanup (elevated): DISM, SFC, update cache, Delivery Optimization, shadow copies, Windows.old.
    
    REQUIRES ADMINISTRATOR PRIVILEGES. Use --dry-run first to preview.
    """
    result = asyncio.run(run_admin_cleanup({
        "dry_run": dry_run,
        "skip_dism": skip_dism,
        "skip_sfc": skip_sfc,
        "skip_wu_cache": skip_wu_cache,
        "skip_do_cache": skip_do_cache,
        "skip_shadow": skip_shadow,
        "skip_windows_old": skip_windows_old,
    }))

    if json_output:
        import json
        console.print_json(json.dumps(result.to_dict()))
    else:
        console.print(result.stdout)
        if result.stderr:
            console.print(result.stderr, style="yellow")

    raise typer.Exit(result.exit_code)


@dataclass
class ExtendedCleanupParams:
    """Parameters for extended-cleanup (weekly, user-level, age-gated)."""
    dry_run: bool = False
    shader_days: int = 30
    model_days: int = 60
    browser_days: int = 7
    code_days: int = 30
    electron_days: int = 14
    wer_days: int = 30
    log_days: int = 30
    archive_days: int = 180


def _mb(bytes_val: int) -> float:
    """Convert bytes to MB."""
    return round(bytes_val / (1024 ** 2), 1)


def _gb(bytes_val: int) -> float:
    """Convert bytes to GB."""
    return round(bytes_val / (1024 ** 3), 2)


async def is_process_running(names: list[str]) -> bool:
    """Check if any of the given processes are running."""
    try:
        result = await run_command(["tasklist", "/FI", f"IMAGENAME eq {names[0]}"], timeout=10)
        for name in names[1:]:
            result2 = await run_command(["tasklist", "/FI", f"IMAGENAME eq {name}"], timeout=10)
            if name.lower() in result2.stdout.lower():
                return True
        return name.lower() in result.stdout.lower()
    except Exception:
        return False


async def prune_files(path: Path, days: int, dry_run: bool = False) -> int:
    """Delete files under path older than days; return bytes freed."""
    if not path.exists():
        return 0
    
    cutoff = datetime.now() - timedelta(days=days)
    total_freed = 0
    
    try:
        for item in path.rglob("*"):
            if item.is_file():
                try:
                    mtime = datetime.fromtimestamp(item.stat().st_mtime)
                    if mtime < cutoff:
                        size = item.stat().st_size
                        if not dry_run:
                            item.unlink()
                        total_freed += size
                except (PermissionError, OSError):
                    continue
    except Exception as e:
        log.warning(f"Error pruning {path}: {e}")
    
    return total_freed


async def get_chromium_cache_dirs(user_data_root: Path) -> list[Path]:
    """Get Chromium cache directories for all profiles."""
    dirs = []
    if not user_data_root.exists():
        return dirs
    
    # Default profile
    profiles = ["Default"]
    # Additional profiles
    try:
        for item in user_data_root.iterdir():
            if item.is_dir() and item.name.startswith("Profile "):
                profiles.append(item.name)
    except (PermissionError, OSError):
        pass
    
    subdirs = [
        "Cache",
        "Code Cache",
        "GPUCache",
        "Service Worker/CacheStorage",
        "Service Worker/ScriptCache",
    ]
    
    for profile in profiles:
        profile_dir = user_data_root / profile
        for sub in subdirs:
            p = profile_dir / sub
            if p.exists():
                dirs.append(p)
    
    return dirs


async def run_extended_cleanup(params: dict[str, Any]) -> CommandResult:
    """Main entry point for extended-cleanup (weekly, user-level, age-gated)."""
    from datetime import datetime, timedelta
    
    p = ExtendedCleanupParams(
        dry_run=params.get("dry_run", False),
        shader_days=params.get("shader_days", 30),
        model_days=params.get("model_days", 60),
        browser_days=params.get("browser_days", 7),
        code_days=params.get("code_days", 30),
        electron_days=params.get("electron_days", 14),
        wer_days=params.get("wer_days", 30),
        log_days=params.get("log_days", 30),
        archive_days=params.get("archive_days", 180),
    )

    log.info("Starting extended-cleanup", extra={"params": params})

    before_free = await get_free_space_gb("C:\\")
    total_freed = 0
    output_lines = ["=== Extended Win11 Cleanup" + (" (DRY RUN)" if p.dry_run else "") + " ==="]
    output_lines.append(f"C: free before: {before_free:.2f} GB\n")

    # [1] GPU shader caches
    output_lines.append("=== [1] GPU shader caches ===")
    shader_dirs = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "NVIDIA" / "DXCache",
        Path(os.environ.get("LOCALAPPDATA", "")) / "NVIDIA" / "GLCache",
        Path(os.environ.get("LOCALAPPDATA", "")) / "NVIDIA Corporation" / "NV_Cache",
        Path(os.environ.get("LOCALAPPDATA", "")) / "D3DSCache",
    ]
    
    for dir_path in shader_dirs:
        if dir_path.exists():
            size = await prune_files(dir_path, p.shader_days, p.dry_run)
            total_freed += size
            output_lines.append(f"  {dir_path.name:<40}: -{_mb(size)} MB")
        else:
            output_lines.append(f"  {dir_path.name:<40}: not found")

    # [2] HuggingFace model blobs (Ollama models: report only)
    output_lines.append("\n=== [2] AI model caches ===")
    hf_path = Path.home() / ".cache" / "huggingface"
    if hf_path.exists():
        size = await prune_files(hf_path, p.model_days, p.dry_run)
        total_freed += size
        output_lines.append(f"  HuggingFace blobs >{p.model_days}d      : -{_mb(size)} MB")
    else:
        output_lines.append(f"  HuggingFace blobs: not found")
    
    ollama_path = Path.home() / ".ollama" / "models"
    if ollama_path.exists():
        try:
            sz = sum(f.stat().st_size for f in ollama_path.rglob("*") if f.is_file())
            output_lines.append(f"  Ollama models: {_gb(sz)} GB - NOT touched (delete manually via 'ollama rm')")
        except Exception:
            output_lines.append(f"  Ollama models: present - NOT touched")

    # [3] Browser caches (skip if browser is running)
    output_lines.append("\n=== [3] Browser caches ===")
    browser_roots = [
        ("Chrome", Path(os.environ.get("LOCALAPPDATA", "")) / "Google" / "Chrome" / "User Data", ["chrome"]),
        ("Edge", Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "Edge" / "User Data", ["msedge"]),
    ]
    
    for name, root, procs in browser_roots:
        if not root.exists():
            continue
        
        running = await is_process_running(procs)
        if running:
            output_lines.append(f"  {name}: running - skipped")
            continue
        
        b_freed = 0
        cache_dirs = await get_chromium_cache_dirs(root)
        for cache_dir in cache_dirs:
            size = await prune_files(cache_dir, p.browser_days, p.dry_run)
            b_freed += size
        
        total_freed += b_freed
        output_lines.append(f"  {name:<40}: -{_mb(b_freed)} MB")

    # [4] VS Code stable caches (skip if running)
    output_lines.append("\n=== [4] VS Code caches ===")
    code_root = Path(os.environ.get("APPDATA", "")) / "Code"
    if code_root.exists():
        running = await is_process_running(["Code"])
        if running:
            output_lines.append("  VS Code: running - skipped")
        else:
            c_freed = 0
            code_subdirs = ["Cache", "CachedData", "Code Cache", "GPUCache", "CachedExtensionVSIXs", "logs"]
            for sub in code_subdirs:
                size = await prune_files(code_root / sub, p.code_days, p.dry_run)
                c_freed += size
            
            # workspaceStorage: drop whole subdirs not touched in $CodeDays
            ws_root = code_root / "workspaceStorage"
            if ws_root.exists():
                cutoff = datetime.now() - timedelta(days=p.code_days)
                try:
                    for item in ws_root.iterdir():
                        if item.is_dir():
                            mtime = datetime.fromtimestamp(item.stat().st_mtime)
                            if mtime < cutoff:
                                sz = sum(f.stat().st_size for f in item.rglob("*") if f.is_file())
                                if not p.dry_run:
                                    shutil.rmtree(item, ignore_errors=True)
                                c_freed += sz
                except Exception as e:
                    log.warning(f"Error pruning workspaceStorage: {e}")
            
            total_freed += c_freed
            output_lines.append(f"  VS Code (>{p.code_days}d, incl. workspaceStorage) : -{_mb(c_freed)} MB")
    else:
        output_lines.append("  VS Code not installed - skipped")

    # [5] Electron app caches
    output_lines.append("\n=== [5] Electron app caches ===")
    electron_apps = [
        ("Discord", Path(os.environ.get("APPDATA", "")) / "discord", ["Cache", "Code Cache", "GPUCache"]),
        ("Slack", Path(os.environ.get("APPDATA", "")) / "Slack", ["Cache", "Code Cache", "GPUCache"]),
        ("Spotify", Path(os.environ.get("APPDATA", "")) / "Spotify", ["Cache", "Code Cache", "GPUCache", "Storage"]),
    ]
    
    for name, root, subs in electron_apps:
        if not root.exists():
            continue
        a_freed = 0
        for sub in subs:
            size = await prune_files(root / sub, p.electron_days, p.dry_run)
            a_freed += size
        total_freed += a_freed
        output_lines.append(f"  {name:<40}: -{_mb(a_freed)} MB")

    # [6] User-side WER archives
    output_lines.append("\n=== [6] WER archives (user) ===")
    w_freed = 0
    wer_dirs = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "Windows" / "WER" / "ReportArchive",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "Windows" / "WER" / "ReportQueue",
    ]
    for wer_dir in wer_dirs:
        size = await prune_files(wer_dir, p.wer_days, p.dry_run)
        w_freed += size
    total_freed += w_freed
    output_lines.append(f"  WER reports >{p.wer_days}d                     : -{_mb(w_freed)} MB")

    # [7] DevOptimizer log rotation
    output_lines.append("\n=== [7] DevOptimizer log rotation ===")
    log_dir = get_logs_dir()
    if log_dir.exists():
        archive_dir = log_dir / "archive"
        archive_dir.mkdir(exist_ok=True)
        
        cutoff = datetime.now() - timedelta(days=p.log_days)
        l_freed = 0
        moved_count = 0
        
        try:
            for item in log_dir.rglob("*"):
                if item.is_file() and "archive" not in item.parts:
                    mtime = datetime.fromtimestamp(item.stat().st_mtime)
                    if mtime < cutoff:
                        size = item.stat().st_size
                        if not p.dry_run:
                            dest = archive_dir / item.relative_to(log_dir)
                            dest.parent.mkdir(parents=True, exist_ok=True)
                            shutil.move(str(item), str(dest))
                        l_freed += size
                        moved_count += 1
        except Exception as e:
            log.warning(f"Error archiving logs: {e}")
        
        # Purge old archive
        a_cutoff = datetime.now() - timedelta(days=p.archive_days)
        a_freed = 0
        try:
            for item in archive_dir.rglob("*"):
                if item.is_file():
                    mtime = datetime.fromtimestamp(item.stat().st_mtime)
                    if mtime < a_cutoff:
                        size = item.stat().st_size
                        if not p.dry_run:
                            item.unlink()
                        a_freed += size
        except Exception as e:
            log.warning(f"Error purging archive: {e}")
        
        total_freed += l_freed + a_freed
        output_lines.append(f"  Logs >{p.log_days}d moved to archive\\          : {moved_count} file(s), {_mb(l_freed)} MB")
        output_lines.append(f"  Archive >{p.archive_days}d purged                  : -{_mb(a_freed)} MB")
    else:
        output_lines.append(f"  {log_dir} not found - skipped")

    # Summary
    after_free = await get_free_space_gb("C:\\")
    
    output_lines.append("\n=== Summary ===")
    output_lines.append(f"C: free after : {after_free:.2f} GB")
    output_lines.append(f"Freed (files) : {_mb(total_freed)} MB")
    if p.dry_run:
        output_lines.append("DRY RUN - nothing was deleted")

    stdout = "\n".join(output_lines)
    stderr = ""

    log.info("extended-cleanup completed", extra={
        "before_gb": before_free,
        "after_gb": after_free,
        "freed_mb": _mb(total_freed),
        "warnings": []
    })

    return CommandResult(
        exit_code=0,
        stdout=stdout,
        stderr=stderr,
        data={
            "before_free_gb": before_free,
            "after_free_gb": after_free,
            "freed_mb": _mb(total_freed),
            "warnings": []
        }
    )


@app.command("extended-cleanup")
def extended_cleanup_cmd(
    dry_run: bool = typer.Option(False, "--dry-run", help="Show what would be cleaned without executing"),
    shader_days: int = typer.Option(30, "--shader-days", help="GPU shader cache age threshold (days)"),
    model_days: int = typer.Option(60, "--model-days", help="HuggingFace model cache age threshold (days)"),
    browser_days: int = typer.Option(7, "--browser-days", help="Browser cache age threshold (days)"),
    code_days: int = typer.Option(30, "--code-days", help="VS Code cache age threshold (days)"),
    electron_days: int = typer.Option(14, "--electron-days", help="Electron app cache age threshold (days)"),
    wer_days: int = typer.Option(30, "--wer-days", help="WER archive age threshold (days)"),
    log_days: int = typer.Option(30, "--log-days", help="DevOptimizer log age threshold before archiving (days)"),
    archive_days: int = typer.Option(180, "--archive-days", help="Archived log purge age threshold (days)"),
    json_output: bool = typer.Option(False, "--json", help="Output results as JSON"),
):
    """Extended cleanup (weekly): deeper user-level sweeps beyond the daily safe cleanup.
    
    Covers: GPU shader caches, HuggingFace model blobs, browser caches,
    VS Code stable caches, Electron app caches, user-side WER archives,
    and rotation of DevOptimizer's own logs.
    """
    result = asyncio.run(run_extended_cleanup({
        "dry_run": dry_run,
        "shader_days": shader_days,
        "model_days": model_days,
        "browser_days": browser_days,
        "code_days": code_days,
        "electron_days": electron_days,
        "wer_days": wer_days,
        "log_days": log_days,
        "archive_days": archive_days,
    }))

    if json_output:
        import json
        console.print_json(json.dumps(result.to_dict()))
    else:
        console.print(result.stdout)
        if result.stderr:
            console.print(result.stderr, style="yellow")

    raise typer.Exit(result.exit_code)