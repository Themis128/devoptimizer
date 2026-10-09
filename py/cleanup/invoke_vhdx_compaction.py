#!/usr/bin/env python3
"""VHDX compaction for WSL/Docker disks. Can run as library (-AsLibrary) or standalone."""
import sys
import argparse
sys.path.insert(0, str(Path(__file__).parent.parent))

from pathlib import Path
from py.cleanup.utils import (
    Colors, gb, get_free_space,
    write_header, write_done, write_warn, write_info, write_error,
    LOCALAPPDATA, run_command
)

Colors.enable()


# Global for library mode
LAST_VHDX_COMPACTION = {"status": "not_run", "before_gb": 0, "after_gb": 0, "freed_gb": 0}


def find_docker_vhdx() -> Path:
    """Find docker_data.vhdx."""
    candidates = [
        LOCALAPPDATA / "Docker" / "wsl" / "disk" / "docker_data.vhdx",
        LOCALAPPDATA / "Docker" / "wsl" / "data" / "docker_data.vhdx",
    ]
    for p in candidates:
        if p.exists():
            return p
    return None


def find_wsl_vhdx() -> list:
    """Find WSL distro VHDX files."""
    wsl_dir = LOCALAPPDATA / "wsl"
    if not wsl_dir.exists():
        return []
    return list(wsl_dir.rglob("ext4.vhdx"))


def compact_vhdx(vhdx_path: Path) -> bool:
    """Compact a single VHDX using diskpart."""
    if not vhdx_path.exists():
        return False
    
    before_size = vhdx_path.stat().st_size
    
    # Create diskpart script
    dp_script = f'''select vdisk file="{vhdx_path}"
attach vdisk readonly
compact vdisk
detach vdisk
'''
    dp_file = Path.cwd() / "compact_vhdx.txt"
    dp_file.write_text(dp_script)
    
    try:
        result = run_command(["diskpart", "/s", str(dp_file)], timeout=600)
        if result.returncode == 0:
            after_size = vhdx_path.stat().st_size
            freed = before_size - after_size
            write_done(f"{vhdx_path.name}: {gb(before_size):.2f} -> {gb(after_size):.2f} GB (freed {gb(freed):.2f} GB)")
            return True
        else:
            write_error(f"{vhdx_path.name}: diskpart failed")
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    print(f"  diskpart: {line}")
            return False
    except Exception as e:
        write_error(f"{vhdx_path.name}: {e}")
        return False
    finally:
        dp_file.unlink(missing_ok=True)


def main():
    global LAST_VHDX_COMPACTION
    
    parser = argparse.ArgumentParser(description="VHDX Compaction for WSL/Docker")
    parser.add_argument("--as-library", action="store_true", help="Run as library (no output, sets LAST_VHDX_COMPACTION)")
    parser.add_argument("--force-all", action="store_true", help="Force compaction regardless of thresholds")
    args = parser.parse_args()
    
    if not args.as_library:
        write_header("WSL/DOCKER VHDX COMPACTION")
    
    vhdx_files = []
    
    # Docker VHDX
    docker_vhdx = find_docker_vhdx()
    if docker_vhdx:
        vhdx_files.append(("Docker", docker_vhdx))
    
    # WSL VHDXs
    for vhdx in find_wsl_vhdx():
        distro = vhdx.parent.name
        vhdx_files.append((f"WSL ({distro})", vhdx))
    
    if not vhdx_files:
        write_warn("No VHDX files found")
        if args.as_library:
            LAST_VHDX_COMPACTION = {"status": "no_vhdx_found", "before_gb": 0, "after_gb": 0, "freed_gb": 0}
        return
    
    total_before = sum(v.stat().st_size for _, v in vhdx_files)
    
    if not args.as_library:
        write_info(f"Found {len(vhdx_files)} VHDX file(s), total: {gb(total_before):.2f} GB")
    
    # Stop Docker Desktop if running (for docker_data.vhdx)
    docker_running = False
    result = run_command(["docker", "version", "--format", "{{.Server.Version}}"])
    if result.returncode == 0:
        docker_running = True
        if not args.as_library:
            write_info("Stopping Docker Desktop...")
        run_command(["C:/Program Files/Docker/Docker/DockerCli.exe", "-Quit"])
        import time
        time.sleep(5)
        run_command(["taskkill", "/F", "/IM", "Docker Desktop.exe"], capture=False)
        run_command(["taskkill", "/F", "/IM", "com.docker.backend.exe"], capture=False)
        time.sleep(2)
        
        write_info("Shutting down WSL...")
        run_command(["wsl", "--shutdown"])
        time.sleep(5)
    
    # Compact each VHDX
    success_count = 0
    for label, vhdx in vhdx_files:
        if not args.as_library:
            write_info(f"Compacting {label} ({vhdx.name})...")
        if compact_vhdx(vhdx):
            success_count += 1
    
    # Restart Docker Desktop if it was running
    if docker_running:
        if not args.as_library:
            write_info("Restarting Docker Desktop...")
        run_command(["start", "", "C:/Program Files/Docker/Docker/Docker Desktop.exe"], capture=False, shell=True)
        
        # Wait for engine
        import time
        deadline = time.time() + 360
        while time.time() < deadline:
            result = run_command(["docker", "version", "--format", "{{.Server.Version}}"])
            if result.returncode == 0:
                if not args.as_library:
                    write_done(f"Docker engine after restart: {result.stdout.strip()}")
                break
            time.sleep(10)
        
        # Test WSL
        result = run_command(["wsl", "-d", "Ubuntu-26.04", "--", "echo", "wsl-ok"])
        if not args.as_library:
            write_info(f"WSL exec after restart: {result.stdout.strip()}")
    
    total_after = sum(v.stat().st_size for _, v in vhdx_files)
    freed = total_before - total_after
    
    if not args.as_library:
        write_header("Compaction Summary")
        write_info(f"Total before: {gb(total_before):.2f} GB")
        write_info(f"Total after : {gb(total_after):.2f} GB")
        write_info(f"Freed       : {gb(freed):.2f} GB")
        write_info(f"Success     : {success_count}/{len(vhdx_files)}")
    
    LAST_VHDX_COMPACTION = {
        "status": "completed" if success_count == len(vhdx_files) else "partial",
        "before_gb": gb(total_before),
        "after_gb": gb(total_after),
        "freed_gb": gb(freed)
    }
    
    if args.as_library:
        sys.exit(0)


if __name__ == "__main__":
    main()