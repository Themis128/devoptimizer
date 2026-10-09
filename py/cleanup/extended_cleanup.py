#!/usr/bin/env python3
"""Extended cleanup (weekly): deeper user-level sweeps beyond the daily safe cleanup."""
import sys
import argparse
import shutil
from pathlib import Path
from datetime import datetime, timedelta
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from py.cleanup.utils import (
    Colors, mb, gb, dir_size, get_free_space, get_chromium_cache_dirs, prune_files,
    write_header, write_done, write_warn, write_info, write_error,
    TEMP, LOCALAPPDATA, APPDATA, USERPROFILE, safe_path, run_command, is_process_running
)

Colors.enable()


def main():
    parser = argparse.ArgumentParser(description="Extended Win11 Cleanup")
    parser.add_argument("--shader-days", type=int, default=30, help="GPU shader caches age (days)")
    parser.add_argument("--model-days", type=int, default=60, help="HuggingFace blobs age (days)")
    parser.add_argument("--browser-days", type=int, default=7, help="Browser caches age (days)")
    parser.add_argument("--code-days", type=int, default=30, help="VS Code caches age (days)")
    parser.add_argument("--electron-days", type=int, default=14, help="Electron app caches age (days)")
    parser.add_argument("--wer-days", type=int, default=30, help="WER archives age (days)")
    parser.add_argument("--log-days", type=int, default=30, help="DevOptimizer logs age (days)")
    parser.add_argument("--archive-days", type=int, default=180, help="Archived logs age (days)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be deleted")
    args = parser.parse_args()
    
    total_freed = 0
    before = get_free_space("C:")
    
    dry_run_str = " (DRY RUN)" if args.dry_run else ""
    print(f"{Colors.MAGENTA}=== Extended Win11 Cleanup{dry_run_str} ==={Colors.RESET}")
    print(f"C: free before: {gb(before):.2f} GB\n")
    
    log_dir = Path("D:/DevOptimizer/logs")
    
    # ─── [1] GPU shader caches ───
    write_header("[1] GPU shader caches")
    for dir_path in [
        safe_path(LOCALAPPDATA, "NVIDIA", "DXCache"),
        safe_path(LOCALAPPDATA, "NVIDIA", "GLCache"),
        safe_path(LOCALAPPDATA, "NVIDIA Corporation", "NV_Cache"),
        safe_path(LOCALAPPDATA, "D3DSCache"),
    ]:
        if dir_path:
            freed = prune_files(dir_path, args.shader_days, args.dry_run)
            total_freed += freed
            write_done(f"{dir_path.name:<40}: -{mb(freed):.1f} MB")
    
    # ─── [2] HuggingFace model blobs ───
    write_header("[2] AI model caches")
    hf = safe_path(USERPROFILE, ".cache", "huggingface")
    if hf:
        freed = prune_files(hf, args.model_days, args.dry_run)
        total_freed += freed
        write_done(f"HuggingFace blobs >{args.model_days}d            : -{mb(freed):.1f} MB")
    
    ollama = safe_path(USERPROFILE, ".ollama", "models")
    if ollama and ollama.exists():
        sz = dir_size(ollama)
        write_info(f"Ollama models: {gb(sz):.2f} GB - NOT touched (delete manually via 'ollama rm')")
    
    # ─── [3] Browser caches ───
    write_header("[3] Browser caches")
    browser_roots = [
        ("Chrome", safe_path(LOCALAPPDATA, "Google", "Chrome", "User Data"), ["chrome"]),
        ("Edge", safe_path(LOCALAPPDATA, "Microsoft", "Edge", "User Data"), ["msedge"]),
    ]
    
    for name, root, proc_names in browser_roots:
        if not root or not root.exists():
            continue
        if is_process_running(proc_names):
            write_warn(f"{name}: running - skipped")
            continue
        
        b_freed = 0
        for d in get_chromium_cache_dirs(root):
            b_freed += prune_files(d, args.browser_days, args.dry_run)
        total_freed += b_freed
        write_done(f"{name:<40}: -{mb(b_freed):.1f} MB")
    
    # ─── [4] VS Code caches ───
    write_header("[4] VS Code caches")
    code_root = safe_path(APPDATA, "Code")
    if code_root and code_root.exists():
        if is_process_running(["Code"]):
            write_warn("VS Code: running - skipped")
        else:
            c_freed = 0
            for sub in ["Cache", "CachedData", "Code Cache", "GPUCache", "CachedExtensionVSIXs", "logs"]:
                c_freed += prune_files(code_root / sub, args.code_days, args.dry_run)
            
            # workspaceStorage: drop whole subdirs not touched in $CodeDays
            ws_root = code_root / "workspaceStorage"
            if ws_root.exists():
                cutoff = datetime.now() - timedelta(days=args.code_days)
                try:
                    for entry in ws_root.iterdir():
                        if entry.is_dir():
                            mtime = datetime.fromtimestamp(entry.stat().st_mtime)
                            if mtime < cutoff:
                                sz = dir_size(entry)
                                if not args.dry_run:
                                    shutil.rmtree(entry, ignore_errors=True)
                                c_freed += sz
                except (OSError, PermissionError):
                    pass
            
            total_freed += c_freed
            write_done(f"VS Code (>{args.code_days}d, incl. workspaceStorage) : -{mb(c_freed):.1f} MB")
    else:
        write_info("VS Code not installed - skipped")
    
    # ─── [5] Electron app caches ───
    write_header("[5] Electron app caches")
    electron_apps = [
        ("Discord", safe_path(APPDATA, "discord"), []),
        ("Slack", safe_path(APPDATA, "Slack"), []),
        ("Spotify", safe_path(APPDATA, "Spotify"), ["Storage"]),
    ]
    
    for name, root, extra_subs in electron_apps:
        if not root or not root.exists():
            continue
        a_freed = 0
        subs = ["Cache", "Code Cache", "GPUCache"] + extra_subs
        for sub in subs:
            a_freed += prune_files(root / sub, args.electron_days, args.dry_run)
        total_freed += a_freed
        write_done(f"{name:<40}: -{mb(a_freed):.1f} MB")
    
    # ─── [6] User-side WER archives ───
    write_header("[6] WER archives (user)")
    w_freed = 0
    for dir_path in [
        safe_path(LOCALAPPDATA, "Microsoft", "Windows", "WER", "ReportArchive"),
        safe_path(LOCALAPPDATA, "Microsoft", "Windows", "WER", "ReportQueue"),
    ]:
        if dir_path:
            w_freed += prune_files(dir_path, args.wer_days, args.dry_run)
    total_freed += w_freed
    write_done(f"WER reports >{args.wer_days}d                     : -{mb(w_freed):.1f} MB")
    
    # ─── [7] DevOptimizer log rotation ───
    write_header("[7] DevOptimizer log rotation")
    if log_dir.exists():
        archive = log_dir / "archive"
        archive.mkdir(exist_ok=True)
        
        cutoff = datetime.now() - timedelta(days=args.log_days)
        stale_logs = []
        try:
            for entry in log_dir.rglob("*"):
                if entry.is_file() and "archive" not in entry.parts:
                    mtime = datetime.fromtimestamp(entry.stat().st_mtime)
                    if mtime < cutoff:
                        stale_logs.append(entry)
        except (OSError, PermissionError):
            pass
        
        l_freed = sum(f.stat().st_size for f in stale_logs)
        if not args.dry_run and stale_logs:
            for f in stale_logs:
                try:
                    rel = f.relative_to(log_dir)
                    dest = archive / rel
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    f.rename(dest)
                except (OSError, PermissionError):
                    pass
        
        write_done(f"Logs >{args.log_days}d moved to archive\          : {len(stale_logs)} file(s), {mb(l_freed):.1f} MB")
        
        # purge old archive
        a_cutoff = datetime.now() - timedelta(days=args.archive_days)
        dead = []
        try:
            for entry in archive.rglob("*"):
                if entry.is_file():
                    mtime = datetime.fromtimestamp(entry.stat().st_mtime)
                    if mtime < a_cutoff:
                        dead.append(entry)
        except (OSError, PermissionError):
            pass
        
        a_sz = sum(f.stat().st_size for f in dead)
        if not args.dry_run and dead:
            for f in dead:
                try:
                    f.unlink(missing_ok=True)
                except (OSError, PermissionError):
                    pass
        
        write_done(f"Archive >{args.archive_days}d purged                  : -{mb(a_sz):.1f} MB")
        total_freed += l_freed + a_sz
    else:
        write_info(f"{log_dir} not found - skipped")
    
    # Summary
    after = get_free_space("C:")
    write_header("Summary")
    print(f"C: free after : {gb(after):.2f} GB")
    print(f"Freed (files) : {mb(total_freed):.1f} MB")
    if args.dry_run:
        write_warn("DRY RUN - nothing was deleted")


if __name__ == "__main__":
    import shutil
    main()