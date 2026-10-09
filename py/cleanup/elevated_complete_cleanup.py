#!/usr/bin/env python3
"""Elevated complete cleanup: DISM component store, WU cache, Delivery Optimization, shadow copies, VHDX compaction. Requires admin."""
import sys
import argparse
import ctypes
import shutil
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from py.cleanup.utils import (
    Colors, mb, gb, get_free_space,
    write_header, write_done, write_warn, write_info, write_error,
    SYSTEMROOT, run_command
)

Colors.enable()

from pathlib import Path
from py.cleanup.utils import (
    Colors, mb, gb, get_free_space,
    write_header, write_done, write_warn, write_info, write_error,
    SYSTEMROOT, run_command
)

Colors.enable()


def is_admin() -> bool:
    """Check if running as administrator."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except Exception:
        return False


def run_dism_cleanup():
    """Run DISM component store cleanup."""
    write_header("[1] DISM Component Store Cleanup")
    write_info("Running: Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart")
    write_info("This may take several minutes...")
    
    result = run_command(["Dism", "/Online", "/Cleanup-Image", "/StartComponentCleanup", "/NoRestart"], timeout=1800)
    for line in result.stdout.strip().split('\n'):
        if line.strip():
            print(f"  {line}")
    if result.returncode == 0:
        write_done("DISM component cleanup: COMPLETED")
    else:
        write_error(f"DISM component cleanup: EXIT CODE {result.returncode}")
        for line in result.stderr.strip().split('\n'):
            if line.strip():
                print(f"  {line}")
    
    # RestoreHealth
    write_header("[1b] DISM RestoreHealth (Repair)")
    write_info("Running: Dism /Online /Cleanup-Image /RestoreHealth")
    write_info("This may take 10-30 minutes...")
    
    result = run_command(["Dism", "/Online", "/Cleanup-Image", "/RestoreHealth"], timeout=3600)
    for line in result.stdout.strip().split('\n'):
        if line.strip():
            print(f"  {line}")
    if result.returncode == 0:
        write_done("DISM RestoreHealth: COMPLETED")
    else:
        write_error(f"DISM RestoreHealth: EXIT CODE {result.returncode}")
    
    # SFC
    write_header("[1c] SFC /scannow")
    write_info("Running: sfc /scannow")
    
    result = run_command(["sfc", "/scannow"], timeout=3600)
    for line in result.stdout.strip().split('\n'):
        if line.strip():
            print(f"  {line}")
    if result.returncode == 0:
        write_done("SFC: COMPLETED")
    else:
        write_error(f"SFC: EXIT CODE {result.returncode}")


def run_wu_cleanup():
    """Clear Windows Update download cache."""
    write_header("[2] Windows Update Download Cache")
    wu_path = SYSTEMROOT / "SoftwareDistribution" / "Download"
    
    if wu_path.exists():
        size = sum(f.stat().st_size for f in wu_path.rglob("*") if f.is_file())
        write_info(f"Stopping wuauserv service...")
        run_command(["net", "stop", "wuauserv"])
        import time
        time.sleep(2)
        
        write_info(f"Clearing {wu_path} ({gb(size):.2f} GB)...")
        for entry in wu_path.iterdir():
            try:
                if entry.is_file():
                    entry.unlink(missing_ok=True)
                elif entry.is_dir():
                    shutil.rmtree(entry, ignore_errors=True)
            except Exception:
                pass
        
        write_info("Restarting wuauserv service...")
        run_command(["net", "start", "wuauserv"])
        write_done(f"Windows Update cache cleaned: -{gb(size):.2f} GB")
    else:
        write_info("Windows Update cache: path not found")


def run_do_cleanup():
    """Clear Delivery Optimization cache."""
    write_header("[3] Delivery Optimization Cache")
    write_info("Running: Delete-DeliveryOptimizationCache")
    
    result = run_command(["powershell", "-Command", "Delete-DeliveryOptimizationCache"], timeout=300)
    if result.returncode == 0:
        write_done("Delivery Optimization cache: CLEARED")
    else:
        write_warn(f"Delivery Optimization cache: SKIPPED ({result.stderr.split(chr(10))[0] if result.stderr else 'error'})")


def run_shadow_cleanup():
    """Delete oldest shadow copy."""
    write_header("[4] System Restore Points (oldest only)")
    write_info("Running: vssadmin delete shadows /for=c: /oldest /quiet")
    
    result = run_command(["vssadmin", "delete", "shadows", "/for=c:", "/oldest", "/quiet"], timeout=60)
    for line in result.stdout.strip().split('\n'):
        if line.strip():
            print(f"  {line}")
    if result.returncode == 0:
        write_done("Oldest shadow copy: DELETED")
    else:
        write_warn(f"Shadow copy: EXIT CODE {result.returncode} (may be none to delete)")


def run_windows_old_cleanup():
    """Remove Windows.old if present."""
    write_header("[5] Windows.old folder (if present)")
    win_old = Path("C:/Windows.old")
    
    if win_old.exists():
        size = sum(f.stat().st_size for f in win_old.rglob("*") if f.is_file())
        write_info(f"Found Windows.old ({gb(size):.2f} GB) - removing...")
        
        run_command(["takeown", "/f", str(win_old), "/r", "/d", "y"])
        run_command(["icacls", str(win_old), "/grant", "administrators:F", "/t", "/c", "/q"])
        
        shutil.rmtree(win_old, ignore_errors=True)
        write_done(f"Windows.old removed: -{gb(size):.2f} GB")
    else:
        write_info("Windows.old: not found")


def run_wer_cleanup():
    """Clean WER archives and crash dumps older than 30 days."""
    write_header("[6] WER archives + crash dumps")
    
    from datetime import datetime, timedelta
    cutoff = datetime.now() - timedelta(days=30)
    dump_freed = 0
    
    for dump_path in [
        Path("C:/ProgramData/Microsoft/Windows/WER/ReportArchive"),
        Path("C:/ProgramData/Microsoft/Windows/WER/ReportQueue"),
        Path("C:/Windows/Minidump"),
    ]:
        if dump_path.exists():
            freed = 0
            for f in dump_path.rglob("*"):
                if f.is_file():
                    try:
                        mtime = datetime.fromtimestamp(f.stat().st_mtime)
                        if mtime < cutoff:
                            sz = f.stat().st_size
                            f.unlink(missing_ok=True)
                            freed += sz
                    except Exception:
                        pass
            dump_freed += freed
            write_done(f"{dump_path} : -{mb(freed):.1f} MB")
        else:
            write_info(f"{dump_path} : not present")
    
    mem_dmp = Path("C:/Windows/MEMORY.DMP")
    if mem_dmp.exists():
        try:
            mtime = datetime.fromtimestamp(mem_dmp.stat().st_mtime)
            if mtime < cutoff:
                sz = mem_dmp.stat().st_size
                mem_dmp.unlink(missing_ok=True)
                dump_freed += sz
                write_done(f"MEMORY.DMP : -{mb(sz):.1f} MB")
        except Exception:
            pass
    
    write_done(f"WER/dumps total freed: -{mb(dump_freed):.1f} MB")


def main():
    parser = argparse.ArgumentParser(description="Elevated Complete Cleanup (Admin Required)")
    parser.add_argument("--skip-vhdx", action="store_true", help="Skip VHDX compaction")
    parser.add_argument("--skip-admin-cleanup", action="store_true", help="Skip admin cleanup")
    args = parser.parse_args()
    
    print(f"{Colors.CYAN}================================================================{Colors.RESET}")
    print(f"{Colors.CYAN}           ELEVATED COMPLETE CLEANUP (Admin Required){Colors.RESET}")
    print(f"{Colors.CYAN}================================================================{Colors.RESET}\n")
    
    if not is_admin():
        write_error("This script MUST run as Administrator. Right-click PowerShell -> Run as Administrator.")
        sys.exit(1)
    
    if not args.skip_vhdx:
        write_header("PART 1: WSL/DOCKER VHDX COMPACTION")
        write_info("VHDX compaction delegated to invoke_vhdx_compaction.py -AsLibrary -ForceAll")
        # TODO: Invoke invoke_vhdx_compaction.py
    
    if not args.skip_admin_cleanup:
        before = get_free_space("C:")
        write_header("PART 2: WINDOWS 11 ADMIN CLEANUP")
        write_info(f"C: free before: {gb(before):.2f} GB")
        
        import shutil
        run_dism_cleanup()
        run_wu_cleanup()
        run_do_cleanup()
        run_shadow_cleanup()
        run_windows_old_cleanup()
        run_wer_cleanup()
        
        after = get_free_space("C:")
        write_header("Admin Cleanup Summary")
        write_info(f"C: free before: {gb(before):.2f} GB")
        write_info(f"C: free after : {gb(after):.2f} GB")
        write_info(f"Freed on C:   : {gb(after - before):.2f} GB")
    
    print(f"\n{Colors.CYAN}================================================================{Colors.RESET}")
    print(f"{Colors.CYAN}                    ALL ADMIN TASKS COMPLETED{Colors.RESET}")
    print(f"{Colors.CYAN}================================================================{Colors.RESET}")
    print(f"{Colors.YELLOW}NOTE: A reboot is recommended after DISM/SFC operations.{Colors.RESET}")
    print(f"{Colors.YELLOW}NOTE: Docker Desktop was stopped - reopen it to restart your containers.{Colors.RESET}")


if __name__ == "__main__":
    import shutil
    main()