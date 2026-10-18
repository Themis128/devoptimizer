#!/usr/bin/env python3
r"""
WSL & system fine-tune status -- one-shot health view of the WSL stack and this host.

Read-only consolidation of the 2026-10-02 fine-tune work:
  1. WSL memory limits in effect (RAM / swap inside the VM) -- the 20GB/16GB wedge fix
  2. Swap pressure + vmmemWSL working set (the wedge precondition that killed Devin sessions)
  3. On-demand container set state (containers converted from always-restart to restart=no)
  4. Host RAM and Docker disk usage summary
  5. Optional: -ApplySafeCleanup runs scripts\win11-safe-cleanup.ps1 (user-level safe set)
Safe to run any time; never starts the WSL VM if it is shut down.
"""

import argparse
import subprocess
import sys
import os
from datetime import datetime
import re

def run_powershell(command):
    """Run a PowerShell command and return the output."""
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", command],
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',
            check=False
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), 1

def run_wsl(command):
    """Run a WSL command and return the output."""
    try:
        result = subprocess.run(
            ["wsl.exe", "-e", "bash", "-c", command],
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',
            check=False
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), 1

def run_docker(command):
    """Run a Docker command and return the output."""
    try:
        import shlex
        result = subprocess.run(
            ["docker.exe"] + shlex.split(command),
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',
            check=False
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), 1

def get_host_memory_info():
    """Get host memory information."""
    try:
        # Get total and free memory using PowerShell
        stdout, stderr, rc = run_powershell("Get-CimInstance Win32_OperatingSystem | Select-Object -Property TotalVisibleMemorySize,FreePhysicalMemory | ConvertTo-Json")
        if rc == 0 and stdout:
            import json
            mem_info = json.loads(stdout)
            total_mb = int(mem_info.get('TotalVisibleMemorySize', 0))
            free_mb = int(mem_info.get('FreePhysicalMemory', 0))
            return total_mb, free_mb
    except:
        pass
    return 0, 0

def get_vmmem_process():
    """Get vmmemWSL process information."""
    try:
        stdout, stderr, rc = run_powershell("Get-Process vmmemWSL -ErrorAction SilentlyContinue | Select-Object -First 1 | ConvertTo-Json")
        if rc == 0 and stdout:
            import json
            proc_info = json.loads(stdout)
            if proc_info:
                working_set = proc_info.get('WorkingSet64', 0)  # WorkingSet64 is in bytes
                return working_set // (1024*1024)  # Convert to MB
    except:
        pass
    return None

def get_wsl_memory_limits():
    """Get WSL memory limits from inside the VM."""
    stdout, stderr, rc = run_wsl("free -m")
    if rc != 0:
        return None, None
    
    lines = stdout.split('\n')
    mem_total = None
    mem_used = None
    swap_total = None
    swap_used = None
    
    for line in lines:
        if line.startswith('Mem:'):
            parts = line.split()
            if len(parts) >= 3:
                mem_total = int(parts[1])
                mem_used = int(parts[2])
        elif line.startswith('Swap:'):
            parts = line.split()
            if len(parts) >= 3:
                swap_total = int(parts[1])
                swap_used = int(parts[2])
    
    return (mem_total, mem_used), (swap_total, swap_used)

def get_disk_info():
    """Get Docker disk usage information."""
    stdout, stderr, rc = run_docker("system df --format \"{{.Type}}|{{.Size}}|{{.Reclaimable}}\"")
    if rc != 0:
        return []
    
    lines = []
    for line in stdout.split('\n'):
        if line.strip():
            parts = line.split('|')
            if len(parts) >= 3:
                lines.append((parts[0], parts[1], parts[2]))
    return lines

def get_running_containers():
    """Get list of running container names."""
    stdout, stderr, rc = run_docker("ps --format \"{{.Names}}\"")
    if rc != 0:
        return []
    
    containers = []
    for line in stdout.split('\n'):
        if line.strip():
            containers.append(line.strip())
    return containers

def run_safe_cleanup():
    """Run the safe cleanup script."""
    script_path = os.path.join(os.path.dirname(__file__), 'win11-safe-cleanup.ps1')
    if os.path.exists(script_path):
        stdout, stderr, rc = run_powershell(f"& '{script_path}'")
        return rc == 0, stdout, stderr
    else:
        return False, "", "Safe cleanup script not found"

def main():
    parser = argparse.ArgumentParser(description='WSL & system fine-tune status')
    parser.add_argument('-ApplySafeCleanup', action='store_true', 
                        help='Also run the user-level safe cleanup after the status report')
    args = parser.parse_args()
    
    stamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"=== WSL & System Fine-Tune Status -- {stamp} ===")
    print()
    
    # Check host RAM and vmmemWSL process
    print("Checking host RAM and vmmemWSL process...")
    total_mb, free_mb = get_host_memory_info()
    vmmem_mb = get_vmmem_process()
    
    host_total_gb = total_mb // 1024
    host_free_gb = free_mb // 1024
    
    print(f"Host RAM free : {host_free_gb} GB of {host_total_gb} GB")
    if vmmem_mb is not None:
        print(f"vmmemWSL      : {vmmem_mb} GB working set (WSL running)")
    else:
        print("vmmemWSL      : not running (skipping in-VM checks)")
    print()
    
    # Check WSL memory limits and swap pressure
    print("Checking WSL memory limits and swap pressure...")
    vmmem_running = vmmem_mb is not None
    if vmmem_running:
        mem_info, swap_info = get_wsl_memory_limits()
        if mem_info and swap_info:
            mem_total, mem_used = mem_info
            swap_total, swap_used = swap_info
            
            print(f"WSL RAM limit : {mem_total} MB total, {mem_used} MB used (cap from .wslconfig memory=)")
            
            if swap_total > 0:
                swap_pct = (swap_used * 100) // swap_total
                flag = ""
                if swap_pct >= 80:
                    flag = "  [WEDGE RISK - event 1003 threshold]"
                elif swap_pct >= 60:
                    flag = "  [elevated]"
                print(f"WSL swap      : {swap_used}/{swap_total} MB ({swap_pct}%){flag}")
                print(f"WSL swap cap  : 16384 MB expected from .wslconfig swap= (16GB fix live 2026-10-02)")
            else:
                print("WSL swap      : 0/0 MB (0%)")
                print("WSL swap cap  : 16384 MB expected from .wslconfig swap= (16GB fix live 2026-10-02)")
        else:
            print("WSL limits    : Unable to retrieve memory information")
    else:
        print("WSL limits    : n/a (VM down; .wslconfig memory=20GB swap=16GB applies at next start)")
    print()
    
    # Check on-demand containers
    print("Checking on-demand containers...")
    on_demand = ['local-diffusers', 'browser-novnc', 'facebook-browser-sidecar', 'languagetool', 'metabase', 'social-media-comfyui-gpu']
    running_containers = get_running_containers()
    total_up = len(running_containers)
    
    print(f"Docker        : {total_up} containers running")
    for name in on_demand:
        state = "RUNNING (on-demand, started manually)" if name in running_containers else "down (restart=no)"
        print(f"  on-demand   : {name:<28} {state}")
    print()
    
    # Check Docker disk usage
    print("Checking Docker disk usage...")
    disk_info = get_disk_info()
    if disk_info:
        print("Docker disk usage:")
        for typ, size, reclaimable in disk_info:
            print(f"  {typ:<12} {size:<12} reclaimable {reclaimable}")
    else:
        print("Docker disk usage: Unable to retrieve information")
    print()
    
    # Optional safe cleanup
    if args.ApplySafeCleanup:
        print("=== Running user-level safe cleanup ===")
        success, stdout, stderr = run_safe_cleanup()
        if success:
            print("Safe cleanup completed successfully")
            if stdout:
                print(stdout)
        else:
            print("Safe cleanup failed")
            if stderr:
                print(f"Error: {stderr}")
        print()
    
    print(r"Done. Watchdog history: logs\wsl-memory-pressure.log (task \DevOptimizer\WSL-Memory-Watchdog, every 30 min)")

if __name__ == '__main__':
    main()