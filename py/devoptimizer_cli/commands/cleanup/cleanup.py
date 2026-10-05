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