#!/usr/bin/env python3
"""Dev cache cleaner - admin-level cache cleaning (DISM, WU, Delivery Optimization, etc.)."""
import sys
import ctypes
import shutil
import time
from pathlib import Path
from datetime import datetime, timedelta
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

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


def main():
    print(f"{Colors.CYAN}================================================================{Colors.RESET}")
    print(f"{Colors.CYAN}           DEV CACHE CLEANER (Admin Required){Colors.RESET}")
    print(f"{Colors.CYAN}================================================================{Colors.RESET}\n")
    
    if not is_admin():
        write_error("This script MUST run as Administrator. Right-click PowerShell -> Run as Administrator.")
        sys.exit(1)
    
    before = get_free_space("C:")
    write_info(f"C: free before: {gb(before):.2f} GB")
    
    import shutil
    
    # 1. DISM Component Store Cleanup
    write_header("[1] DISM Component Store Cleanup")
    write_info("Running: Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart")
    result = run_command(["Dism", "/Online", "/Cleanup-Image", "/StartComponentCleanup", "/NoRestart"], timeout=1800)
    for line in result.stdout.strip().split('\n'):
        if line.strip():
            print(f"  {line}")
    if result.returncode == 0:
        write_done("DISM component cleanup: COMPLETED")
    else:
        write_error(f"DISM component cleanup: EXIT CODE {result.returncode}")
    
    # 2. Windows Update Download Cache
    write_header("[2] Windows Update Download Cache")
    wu_path = SYSTEMROOT / "SoftwareDistribution" / "Download"
    if wu_path.exists():
        size = sum(f.stat().st_size for f in wu_path.rglob("*") if f.is_file())
        write_info("Stopping wuauserv service...")
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
    
    # 3. Delivery Optimization Cache
    write_header("[3] Delivery Optimization Cache")
    result = run_command(["powershell", "-Command", "Delete-DeliveryOptimizationCache"], timeout=300)
    if result.returncode == 0:
        write_done("Delivery Optimization cache: CLEARED")
    else:
        write_warn(f"Delivery Optimization cache: SKIPPED ({result.stderr.split(chr(10))[0] if result.stderr else 'error'})")
    
    # 4. System Restore Points (oldest)
    write_header("[4] System Restore Points (oldest only)")
    result = run_command(["vssadmin", "delete", "shadows", "/for=c:", "/oldest", "/quiet"], timeout=60)
    for line in result.stdout.strip().split('\n'):
        if line.strip():
            print(f"  {line}")
    if result.returncode == 0:
        write_done("Oldest shadow copy: DELETED")
    else:
        write_warn(f"Shadow copy: EXIT CODE {result.returncode} (may be none to delete)")
    
    # 5. Windows.old
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
    
    # 6. WER + crash dumps
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
    
    # 7. Driver Store (optional - careful)
    write_header("[7] Driver Store (old drivers)")
    write_info("Scanning for old driver packages...")
    result = run_command(["pnputil", "/enum-drivers"], timeout=60)
    if result.returncode == 0:
        # Just report, don't auto-delete
        write_info("Run 'pnputil /enum-drivers' manually to review and remove old drivers")
    
    # Summary
    after = get_free_space("C:")
    write_header("Summary")
    write_info(f"C: free before: {gb(before):.2f} GB")
    write_info(f"C: free after : {gb(after):.2f} GB")
    write_info(f"Freed on C:   : {gb(after - before):.2f} GB")
    
    print(f"\n{Colors.YELLOW}NOTE: A reboot is recommended after DISM operations.{Colors.RESET}")


if __name__ == "__main__":
    main()