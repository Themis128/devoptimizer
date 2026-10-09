#!/usr/bin/env python3
"""Read-only Win11 cleanup status assessment: drives, temp, dev caches, browser data, VHDX sizes, Docker usage."""
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from pathlib import Path
from py.cleanup.utils import (
    Colors, mb, gb, fmt_bytes, dir_size, get_free_space, get_used_space,
    get_chromium_cache_dirs, write_header, write_info, write_done, write_warn, write_error,
    TEMP, LOCALAPPDATA, APPDATA, USERPROFILE, SYSTEMROOT, safe_path, run_command
)

Colors.enable()

cleanable_bytes = 0


def add_clean(bytes_val: int):
    global cleanable_bytes
    cleanable_bytes += bytes_val


def row(label: str, path: Optional[Path]) -> int:
    """Print a row and return size in bytes."""
    global cleanable_bytes
    if not path or not path.exists():
        print(f"{label:<44} : (not present)")
        return 0
    
    size = dir_size(path)
    if size >= 1024**3:
        print(f"{label:<44} : {gb(size):>8.2f} GB")
    else:
        print(f"{label:<44} : {mb(size):>8.1f} MB")
    return size


def chromium_cache_size(root: Optional[Path]) -> int:
    """Calculate precise Chromium cache size."""
    if not root or not root.exists():
        return 0
    total = 0
    for d in get_chromium_cache_dirs(root):
        total += dir_size(d)
    return total


def main():
    global cleanable_bytes
    
    print(f"{Colors.MAGENTA}=== Win11 Cleanup Assessment - {datetime.now().strftime('%Y-%m-%d %H:%M')} ==={Colors.RESET}")
    
    # ─── Drives ───
    write_header("Drives")
    for drive_letter in ["C:", "D:", "E:"]:
        try:
            drive_path = Path(drive_letter)
            if drive_path.exists():
                free = get_free_space(drive_path)
                total = get_total_space(drive_path)
                used = total - free
                pct = round(100 * free / total) if total > 0 else 0
                print(f"{drive_letter}: free {gb(free):>8.1f} GB  ({pct}%)  used {gb(used):>8.1f} GB")
        except Exception:
            pass
    
    # ─── Temp & crash data ───
    write_header("Temp & crash data (user-level)")
    add_clean(row("User temp", TEMP))
    add_clean(row("Windows temp", SYSTEMROOT / "Temp"))
    add_clean(row("CrashDumps", safe_path(LOCALAPPDATA, "CrashDumps")))
    add_clean(row("WER archives (user)", safe_path(LOCALAPPDATA, "Microsoft", "Windows", "WER")))
    
    # ─── Dev caches ───
    write_header("Dev caches (user-level)")
    add_clean(row("npm cache", safe_path(LOCALAPPDATA, "npm-cache")))
    add_clean(row("pip cache", safe_path(LOCALAPPDATA, "pip", "cache")))
    add_clean(row("pnpm store", safe_path(LOCALAPPDATA, "pnpm", "store")))
    add_clean(row("Cargo registry", safe_path(USERPROFILE, ".cargo", "registry")))
    add_clean(row("NuGet packages", safe_path(USERPROFILE, ".nuget", "packages")))
    add_clean(row("Go module cache", safe_path(USERPROFILE, "go", "pkg")))
    add_clean(row("HuggingFace cache", safe_path(USERPROFILE, ".cache", "huggingface")))
    
    # Ollama - report only
    ollama_path = safe_path(USERPROFILE, ".ollama", "models")
    if ollama_path and ollama_path.exists():
        sz = dir_size(ollama_path)
        print(f"{'Ollama models (report-only, not auto-cleaned)':<44} : {gb(sz):>8.2f} GB")
    
    # ─── Browser caches ───
    write_header("Browser caches (Chrome/Edge)")
    chrome_root = safe_path(LOCALAPPDATA, "Google", "Chrome", "User Data")
    edge_root = safe_path(LOCALAPPDATA, "Microsoft", "Edge", "User Data")
    
    chrome_full = row("Chrome cache dirs", chrome_root)
    edge_full = row("Edge cache dirs", edge_root)
    
    chrome_cache = chromium_cache_size(chrome_root)
    edge_cache = chromium_cache_size(edge_root)
    
    print(f"{'Chrome cache subset':<44} : {mb(chrome_cache):>8.1f} MB (precise, cleanable subset)")
    print(f"{'Edge cache subset':<44} : {mb(edge_cache):>8.1f} MB (precise, cleanable subset)")
    
    # Adjust cleanable: replace full with precise
    cleanable_bytes = cleanable_bytes - chrome_full - edge_full + chrome_cache + edge_cache
    
    # ─── VS Code / Electron ───
    write_header("VS Code / Electron")
    for name, path in [
        ("VS Code stable caches", safe_path(APPDATA, "Code")),
        ("VS Code Insiders caches", safe_path(APPDATA, "Code - Insiders")),
    ]:
        total = 0
        if path and path.exists():
            for sub in ["Cache", "CachedData", "Code Cache", "GPUCache", "CachedExtensionVSIXs", "logs", "workspaceStorage"]:
                total += dir_size(path / sub)
        if total >= 100 * 1024**2:
            print(f"{name:<44} : {mb(total):>8.1f} MB")
        else:
            print(f"{name:<44} : {mb(total):>8.1f} MB")
        add_clean(total)
    
    for name, path, extra_subs in [
        ("Discord", safe_path(APPDATA, "discord"), ["Storage"]),
        ("Slack", safe_path(APPDATA, "Slack"), []),
        ("Spotify", safe_path(APPDATA, "Spotify"), ["Storage"]),
    ]:
        total = 0
        if path and path.exists():
            for sub in ["Cache", "Code Cache", "GPUCache"] + extra_subs:
                total += dir_size(path / sub)
        if total > 0:
            print(f"{name:<44} : {mb(total):>8.1f} MB")
            add_clean(total)
    
    # ─── Recycle bin ───
    write_header("Recycle bin")
    rb_size = row("C:\\$Recycle.Bin", Path("C:/$Recycle.Bin"))
    print(" (readable subset)")
    add_clean(rb_size)
    
    # ─── System caches ───
    write_header("System caches (best effort without admin)")
    row("Windows Update download cache", SYSTEMROOT / "SoftwareDistribution" / "Download")
    row("Delivery Optimization cache", safe_path(SYSTEMROOT, "ServiceProfiles", "NetworkService", "AppData", "Local", "Microsoft", "Windows", "DeliveryOptimization", "Cache"))
    
    # ─── VHDX backing disks ───
    write_header("VHDX backing disks")
    for base in [safe_path(LOCALAPPDATA, "wsl"), safe_path(LOCALAPPDATA, "Docker")]:
        if base and base.exists():
            for vhdx in base.rglob("*.vhdx"):
                try:
                    rel = vhdx.relative_to(LOCALAPPDATA).as_posix().replace("AppData/Local", "~AppData\\Local")
                    print(f"{rel:<44} : {gb(vhdx.stat().st_size):>8.2f} GB")
                except Exception:
                    pass
    
    # ─── Big system files ───
    write_header("Big system files")
    for f in ["pagefile.sys", "hiberfil.sys", "swapfile.sys"]:
        p = SYSTEMROOT / f
        if p.exists():
            print(f"{f:<44} : {gb(p.stat().st_size):>8.2f} GB")
    
    # ─── Docker ───
    write_header("Docker (if running)")
    result = run_command(["docker", "version", "--format", "{{.Server.Version}}"])
    if result.returncode == 0:
        df_result = run_command(["docker", "system", "df"])
        if df_result.returncode == 0:
            print(df_result.stdout.strip())
    else:
        write_info("Docker daemon not running - skipped")
    
    # ─── Verdict ───
    write_header("Verdict")
    if cleanable_bytes >= 5 * 1024**3:
        print(f"{Colors.RED}YES - ~{gb(cleanable_bytes):.1f} GB cleanable at user level right now.{Colors.RESET}")
    elif cleanable_bytes >= 500 * 1024**2:
        print(f"{Colors.YELLOW}MODERATE - ~{mb(cleanable_bytes):.0f} MB cleanable at user level right now.{Colors.RESET}")
    else:
        print(f"{Colors.GREEN}NO - only ~{mb(cleanable_bytes):.0f} MB cleanable at user level; system is tidy.{Colors.RESET}")
    
    print(f"{Colors.GRAY}Run extended-cleanup.py / win11-safe-cleanup.py for user-level, elevated-complete-cleanup.py for admin items.{Colors.RESET}")


if __name__ == "__main__":
    from datetime import datetime
    main()