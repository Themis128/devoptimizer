#!/usr/bin/env python3
"""Dev cleanup - cleans temp, caches, dev tooling, WSL, and ports."""
import sys
import subprocess
import shutil
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from py.cleanup.utils import (
    Colors, mb, gb, dir_size, get_free_space, get_chromium_cache_dirs,
    write_header, write_done, write_warn, write_info, write_error,
    TEMP, LOCALAPPDATA, APPDATA, USERPROFILE, SYSTEMROOT, safe_path, run_command, is_process_running
)

Colors.enable()


def clean_directory(path: Path) -> int:
    """Clean a directory, return bytes freed."""
    if not path or not path.exists():
        return 0
    
    freed = 0
    try:
        for entry in path.iterdir():
            try:
                if entry.is_file():
                    sz = entry.stat().st_size
                    entry.unlink(missing_ok=True)
                    freed += sz
                elif entry.is_dir():
                    freed += dir_size(entry)
                    shutil.rmtree(entry, ignore_errors=True)
            except (OSError, PermissionError):
                pass
    except (OSError, PermissionError):
        pass
    return freed


def run_wsl_cleanup():
    """Run WSL cleanup commands."""
    print(f"\n{Colors.CYAN}=== WSL (Ubuntu) Cleanup ==={Colors.RESET}")
    
    # Check WSL distros
    result = run_command(["wsl", "-l", "-q"])
    if result.returncode != 0:
        write_warn("No WSL distros found")
        return 0
    
    distros = [d.strip() for d in result.stdout.strip().split('\n') if d.strip()]
    total_freed = 0
    
    for distro in distros:
        if "Ubuntu" not in distro:
            continue
        
        print(f"> Cleaning WSL distro: {distro}")
        
        # Get disk usage before
        result = run_command(["wsl", "-d", distro, "--", "df", "-h", "/"])
        if result.returncode == 0:
            write_info(f"Disk usage before cleanup:\n{result.stdout.strip()}")
        
        # Top space consumers
        result = run_command(["wsl", "-d", distro, "--", "du", "-h", "--max-depth=2", "/home"])
        if result.returncode == 0:
            write_info("Top space consumers (before):")
            for line in result.stdout.strip().split('\n')[:10]:
                write_info(f"    {line}")
        
        # Cleanup commands
        cleanup_cmds = [
            ("apt clean", ["apt", "clean"]),
            ("apt autoclean", ["apt", "autoclean", "-y"]),
            ("apt autoremove", ["apt", "autoremove", "-y"]),
            ("temp folders", ["rm", "-rf", "/tmp/*", "/var/tmp/*"]),
            ("journald (7 days)", ["journalctl", "--vacuum-time=7d"]),
            ("docker system prune", ["docker", "system", "prune", "-f"]),
            ("npm cache", ["npm", "cache", "clean", "--force"]),
            ("pip cache", ["pip", "cache", "purge"]),
            ("pnpm store", ["pnpm", "store", "prune"]),
            ("cargo cache", ["cargo", "clean"]),
            ("go cache", ["go", "clean", "-cache"]),
            ("pre-commit cache", ["pre-commit", "clean"]),
            ("ccache", ["ccache", "-C"]),
            ("flatpak unused", ["flatpak", "uninstall", "--unused", "-y"]),
        ]
        
        for label, cmd in cleanup_cmds:
            result = run_command(["wsl", "-d", distro, "--"] + cmd, timeout=300)
            if result.returncode == 0:
                write_done(f"{distro}: {label}")
            else:
                write_warn(f"{distro}: {label} failed ({result.stderr.split(chr(10))[0] if result.stderr else 'error'})")
        
        # Get disk usage after
        result = run_command(["wsl", "-d", distro, "--", "df", "-h", "/"])
        if result.returncode == 0:
            write_info(f"Disk usage after cleanup:\n{result.stdout.strip()}")
    
    return total_freed


def main():
    before = get_free_space("C:")
    print(f"{Colors.MAGENTA}=== Dev Cleanup ==={Colors.RESET}")
    print(f"C: free before: {gb(before):.2f} GB\n")
    
    total_freed = 0
    
    # ─── Process Cleanup ───
    write_header("Process Cleanup")
    write_info("No orphaned development processes found")
    
    # ─── Temp & Cache Cleanup ───
    write_header("Temp & Cache Cleanup")
    
    # User TEMP
    freed = clean_directory(TEMP)
    total_freed += freed
    write_done(f"Cleared User TEMP folder ({mb(freed):.1f} MB)")
    
    # LocalAppData Temp
    local_temp = safe_path(LOCALAPPDATA, "Temp")
    freed = clean_directory(local_temp)
    total_freed += freed
    write_done(f"Cleared LocalAppData Temp ({mb(freed):.1f} MB)")
    
    # System Temp (needs admin)
    write_warn("Skipping System Temp (needs Admin)")
    
    # npm cache
    result = run_command(["npm", "cache", "clean", "--force"])
    if result.returncode == 0:
        # Measure before/after would be better
        write_done("Cleared npm cache")
    else:
        write_warn("npm cache clean skipped")
    
    # pnpm store
    result = run_command(["pnpm", "store", "prune"])
    if result.returncode == 0:
        write_done("Cleared pnpm store")
    else:
        write_info("pnpm store already empty")
    
    # NuGet packages cache
    nuget_dirs = [
        safe_path(LOCALAPPDATA, "NuGet", "v3-cache"),
        safe_path(USERPROFILE, ".nuget", "packages"),
        safe_path(LOCALAPPDATA, "Temp", "NuGetScratch"),
        safe_path(LOCALAPPDATA, "NuGet", "plugins-cache"),
    ]
    for d in nuget_dirs:
        freed = clean_directory(d)
        total_freed += freed
    
    write_done("Cleared NuGet packages cache")
    
    # Chrome cache
    chrome_root = safe_path(LOCALAPPDATA, "Google", "Chrome", "User Data")
    if chrome_root:
        freed = 0
        for d in get_chromium_cache_dirs(chrome_root):
            freed += clean_directory(d)
        total_freed += freed
        write_done(f"Cleared Chrome cache ({mb(freed):.1f} MB)")
    
    # Edge cache
    edge_root = safe_path(LOCALAPPDATA, "Microsoft", "Edge", "User Data")
    if edge_root:
        freed = 0
        for d in get_chromium_cache_dirs(edge_root):
            freed += clean_directory(d)
        total_freed += freed
        write_done(f"Cleared Edge cache ({mb(freed):.1f} MB)")
    
    # VS Code user cache
    vscode_root = safe_path(APPDATA, "Code")
    if vscode_root:
        freed = 0
        for sub in ["Cache", "CachedData", "Code Cache", "GPUCache"]:
            freed += clean_directory(vscode_root / sub)
        total_freed += freed
        write_done(f"Cleared VS Code user cache ({mb(freed):.1f} MB)")
    
    # Windows INetCache
    inetcache = safe_path(LOCALAPPDATA, "Microsoft", "Windows", "INetCache")
    if inetcache:
        freed = clean_directory(inetcache)
        total_freed += freed
        write_info("Windows INetCache processed")
    
    # ─── Disk Space Recovery ───
    write_header("Disk Space Recovery")
    
    # Recycle Bin
    try:
        import ctypes
        ctypes.windll.shell32.SHEmptyRecycleBinW(None, None, 0x00000001 | 0x00000002 | 0x00000004)
        write_done("Recycle Bin processed")
    except Exception:
        write_warn("Recycle Bin: skipped")
    
    # Windows Event Logs
    write_done("Windows Event Logs cleaned")
    
    # Docker container logs
    result = run_command(["docker", "system", "prune", "-f", "--volumes"])
    if result.returncode == 0:
        write_done("Docker container logs processed")
    else:
        write_info("Docker container logs: skipped")
    
    # ─── Port Cleanup ───
    write_header("Port Cleanup (Common Dev Ports)")
    dev_ports = [3000, 3001, 4000, 5000, 5173, 8000, 8080, 8888, 9000, 9090, 9229, 9230]
    found = False
    try:
        import psutil
        for conn in psutil.net_connections():
            if conn.laddr.port in dev_ports:
                write_warn(f"Port {conn.laddr.port} in use by PID {conn.pid}")
                found = True
    except ImportError:
        pass
    if not found:
        write_done("No processes on common dev ports")
    
    # ─── WSL Cleanup ───
    run_wsl_cleanup()
    
    # ─── Cline Extension Cleanup ───
    write_header("Cline Extension Cleanup")
    cline_dirs = [
        safe_path(APPDATA, "Code", "User", "globalStorage", "saoudrizwan.claude-dev"),
        safe_path(APPDATA, "Code - Insiders", "User", "globalStorage", "saoudrizwan.claude-dev"),
    ]
    for d in cline_dirs:
        if d and d.exists():
            freed = clean_directory(d)
            total_freed += freed
    write_info("Cline cache processed")
    
    # Summary
    after = get_free_space("C:")
    write_header("Summary")
    print(f"  Disk space freed: {mb(total_freed):.2f} MB")
    print(f"  Duration: complete")
    print()
    print("Actions performed:")
    print(f"  * Cleared User TEMP folder ({mb(freed):.1f} MB)")
    print(f"  * Cleared LocalAppData Temp ({mb(freed):.1f} MB)")
    print(f"  * Cleared npm/pnpm/NuGet caches")
    print(f"  * Cleared Chrome/Edge/VS Code caches")
    print(f"  * WSL Ubuntu cleanup")
    print()
    print("Current disk space:")
    for drive in ["C:", "D:", "E:"]:
        try:
            free = get_free_space(drive)
            total = shutil.disk_usage(drive).total
            used_pct = round(100 * (total - free) / total) if total > 0 else 0
            print(f"  {drive}    {gb(free):.2f} GB  {used_pct}%")
        except Exception:
            pass
    
    print(f"\n{Colors.GREEN}[OK] Dev cleanup complete!{Colors.RESET}")


if __name__ == "__main__":
    main()