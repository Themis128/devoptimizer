#!/usr/bin/env python3
"""Windows 11 safe cleanup for DevOptimizer (non-admin scope)."""
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from pathlib import Path
from py.cleanup.utils import (
    Colors, mb, gb, fmt_bytes, dir_size, get_free_space,
    write_header, write_done, write_warn, write_info, write_error,
    TEMP, LOCALAPPDATA, SYSTEMROOT, run_command
)

Colors.enable()


def clean_directory(path: Path, label: str) -> int:
    """Clean a directory, return bytes freed."""
    if not path.exists():
        return 0
    
    size = dir_size(path)
    freed = 0
    
    try:
        for entry in path.iterdir():
            try:
                if entry.is_file():
                    entry.unlink(missing_ok=True)
                    freed += entry.stat().st_size
                elif entry.is_dir():
                    shutil.rmtree(entry, ignore_errors=True)
            except (OSError, PermissionError):
                pass
    except (OSError, PermissionError):
        pass
    
    if size > 0:
        print(f"[{label}] cleaned: -{mb(size):.1f} MB")
    return size


def main():
    import shutil
    
    before = get_free_space("C:")
    print(f"{Colors.MAGENTA}=== Windows 11 Safe Cleanup ==={Colors.RESET}")
    print(f"C: free before: {gb(before):.2f} GB\n")
    
    total_freed = 0
    
    # 1. User temp files
    print(f"{Colors.CYAN}[1] User temp{Colors.RESET}")
    size = dir_size(TEMP) if TEMP else 0
    clean_directory(TEMP, "1")
    total_freed += size
    print(f"[1] User temp cleaned          : -{mb(size):.1f} MB")
    
    # 2. Windows temp (best effort without admin)
    print(f"\n{Colors.CYAN}[2] Windows temp (best effort){Colors.RESET}")
    win_temp = SYSTEMROOT / "Temp"
    size = dir_size(win_temp)
    clean_directory(win_temp, "2")
    total_freed += size
    print(f"[2] Windows temp (best effort) : -{mb(size):.1f} MB (locked/admin files skipped)")
    
    # 3. Dev package-manager caches
    print(f"\n{Colors.CYAN}[3] Dev package-manager caches{Colors.RESET}")
    targets = [
        ("npm cache", ["npm", "cache", "clean", "--force"]),
        ("pip cache", ["pip", "cache", "purge"]),
        ("pnpm store", ["pnpm", "store", "prune"]),
        ("yarn cache", ["yarn", "cache", "clean"]),
    ]
    
    for name, cmd in targets:
        try:
            result = run_command(cmd, timeout=120)
            if result.returncode == 0:
                print(f"[3] {name:<22} : cleaned")
            else:
                print(f"[3] {name:<22} : skipped ({result.stderr.split(chr(10))[0] if result.stderr else 'failed'})")
        except Exception as e:
            print(f"[3] {name:<22} : skipped ({e})")
    
    # 4. PowerShell module cache crumbs + error dumps
    print(f"\n{Colors.CYAN}[4] IE cache + CrashDumps{Colors.RESET}")
    for dir_path in [
        safe_path(LOCALAPPDATA, "Microsoft", "Windows", "INetCache", "IE"),
        safe_path(LOCALAPPDATA, "CrashDumps"),
    ]:
        if dir_path and dir_path.exists():
            size = dir_size(dir_path)
            clean_directory(dir_path, "4")
            total_freed += size
            print(f"[4] {dir_path.name:<30}: -{mb(size):.1f} MB")
    
    # 5. Recycle bin
    print(f"\n{Colors.CYAN}[5] Recycle bin{Colors.RESET}")
    try:
        import ctypes
        ctypes.windll.shell32.SHEmptyRecycleBinW(None, None, 0x00000001 | 0x00000002 | 0x00000004)
        print("[5] Recycle bin emptied")
    except Exception as e:
        print(f"[5] Recycle bin: skipped ({e})")
    
    # 6. Docker: build cache + dangling images ONLY
    print(f"\n{Colors.CYAN}--- Docker (safe subset) ---{Colors.RESET}")
    result = run_command(["docker", "system", "df", "--format", "{{.Type}} {{.Size}}"])
    if result.returncode == 0:
        print(f"Before: {result.stdout.strip()}")
    else:
        print("Before: Docker not running")
    
    # Build cache
    result = run_command(["docker", "builder", "prune", "-f"])
    if result.returncode == 0:
        last_line = result.stdout.strip().split('\n')[-1] if result.stdout else "Done"
        print(f"[6] Build cache : {last_line}")
    
    # Dangling images
    result = run_command(["docker", "image", "prune", "-f"])
    if result.returncode == 0:
        last_line = result.stdout.strip().split('\n')[-1] if result.stdout else "Done"
        print(f"[6] Dangling img: {last_line}")
    
    print("Containers/volumes/named images: untouched")
    
    # Summary
    after = get_free_space("C:")
    print(f"\n{Colors.MAGENTA}=== Summary ==={Colors.RESET}")
    print(f"C: free after : {gb(after):.2f} GB")
    print(f"Freed on C:   : {mb(after - before):.1f} MB")
    
    # Admin-required items
    print(f"\n{Colors.YELLOW}Requires Administrator (run DevOptimizer cleanup elevated for these):{Colors.RESET}")
    print("  - DISM component store cleanup : Dism /Online /Cleanup-Image /StartComponentCleanup")
    print("  - Windows Update download cache: Stop wuauserv, clear C:\\Windows\\SoftwareDistribution\\Download")
    print("  - Delivery Optimization cache  : Delete-DeliveryOptimizationCache (elevated PowerShell)")
    print("  - System restore points / shadow copies: vssadmin delete shadows /for=c: /oldest")


if __name__ == "__main__":
    main()