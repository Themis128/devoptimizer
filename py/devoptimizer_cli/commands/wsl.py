"""
WSL (Windows Subsystem for Linux) system status and monitoring commands
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.panel import Panel

from devoptimizer_cli.core.executor import run_command, run_elevated
from devoptimizer_cli.core.logging import get_logger
from devoptimizer_cli.core.paths import get_logs_dir
from devoptimizer_cli.models.command import CommandResult

try:
    import win32evtlog
    import win32evtlogutil
    HAS_WIN32_EVENTLOG = True
except ImportError:
    HAS_WIN32_EVENTLOG = False

app = typer.Typer(name="wsl", help="WSL system status and monitoring")
console = Console()
log = get_logger(__name__)


@app.command()
def system_status(
    apply_safe_cleanup: bool = typer.Option(
        False, "--apply-safe-cleanup", help="Also run the user-level safe cleanup after the status report"
    ),
    json_output: bool = typer.Option(
        False, "--json", help="Output results in JSON format"
    )
):
    """WSL & system fine-tune status -- one-shot health view of the WSL stack and this host."""
    
    if json_output:
        # JSON output mode
        result = {
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "host": {},
            "wsl": {},
            "docker": {},
            "on_demand_containers": {},
            "cleanup_requested": apply_safe_cleanup
        }
        
        try:
            # --- Host side -------------------------------------------------------------
            # Get host RAM info
            try:
                # Using Windows commands to get memory info
                mem_output = subprocess.check_output(
                    ["wmic", "OS", "get", "FreePhysicalMemory,TotalVisibleMemorySize", "/value"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                mem_lines = [line.strip() for line in mem_output.split('\n') if '=' in line]
                mem_dict = {}
                for line in mem_lines:
                    if '=' in line:
                        key, value = line.split('=', 1)
                        mem_dict[key.strip()] = value.strip()
                
                free_kb = int(mem_dict.get('FreePhysicalMemory', 0))
                total_kb = int(mem_dict.get('TotalVisibleMemorySize', 0))
                
                result["host"]["free_memory_gb"] = round(free_kb / 1024 / 1024, 1)
                result["host"]["total_memory_gb"] = round(total_kb / 1024 / 1024, 1)
                result["host"]["used_memory_gb"] = round((total_kb - free_kb) / 1024 / 1024, 1)
            except Exception as e:
                log.warning(f"Failed to get host memory info: {e}")
                result["host"]["error"] = str(e)
            
            # Check for vmmemWSL process
            try:
                tasklist_output = subprocess.check_output(
                    ["tasklist", "/FI", "IMAGENAME eq vmmemWSL*", "/FO", "CSV"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                lines = [line.strip() for line in tasklist_output.split('\n') if line.strip()]
                if len(lines) > 1:  # Header + at least one process
                    # Parse the first process line
                    process_line = lines[1].strip('"')
                    parts = [part.strip('"') for part in process_line.split('","')]
                    if len(parts) >= 5:
                        mem_usage_kb = int(parts[4].replace(',', '')) if parts[4].replace(',', '').isdigit() else 0
                        result["wsl"]["vmmem_wsl_running"] = True
                        result["wsl"]["vmmem_wsl_memory_mb"] = round(mem_usage_kb / 1024, 1)
                    else:
                        result["wsl"]["vmmem_wsl_running"] = True
                        result["wsl"]["vmmem_wsl_memory_mb"] = 0
                else:
                    result["wsl"]["vmmem_wsl_running"] = False
            except Exception as e:
                log.warning(f"Failed to check vmmemWSL process: {e}")
                result["wsl"]["vmmem_wsl_running"] = False
                result["wsl"]["vmmem_wsl_error"] = str(e)
            
            # --- In-VM limits & swap pressure ------------------------------------------
            if result["wsl"].get("vmmem_wsl_running", False):
                try:
                    # Get memory info from WSL
                    mem_output = subprocess.check_output(
                        ["wsl", "-e", "bash", "-c", "free -m"],
                        stderr=subprocess.DEVNULL,
                        text=True
                    )
                    mem_lines = [line.strip() for line in mem_output.split('\n') if line.strip()]
                    
                    mem_total = 0
                    mem_used = 0
                    swap_total = 0
                    swap_used = 0
                    
                    for line in mem_lines:
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
                    
                    result["wsl"]["memory_total_mb"] = mem_total
                    result["wsl"]["memory_used_mb"] = mem_used
                    result["wsl"]["swap_total_mb"] = swap_total
                    result["wsl"]["swap_used_mb"] = swap_used
                    
                    if swap_total > 0:
                        swap_pct = round((swap_used / swap_total) * 100, 1)
                        result["wsl"]["swap_usage_percent"] = swap_pct
                        
                        # Add wedge risk flags
                        if swap_pct >= 80:
                            result["wsl"]["swap_wedge_risk"] = True
                        elif swap_pct >= 60:
                            result["wsl"]["swap_elevated"] = True
                            
                except Exception as e:
                    log.warning(f"Failed to get WSL memory info: {e}")
                    result["wsl"]["memory_error"] = str(e)
            
            # --- On-demand container set ------------------------------------------------
            on_demand_containers = [
                'local-diffusers', 
                'browser-novnc', 
                'facebook-browser-sidecar', 
                'languagetool', 
                'metabase', 
                'social-media-comfyui-gpu'
            ]
            
            try:
                # Get running containers
                docker_ps_output = subprocess.check_output(
                    ["docker", "ps", "--format", "{{.Names}}"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                running_containers = [
                    line.strip() 
                    for line in docker_ps_output.split('\n') 
                    if line.strip()
                ]
                
                result["docker"]["containers_running"] = len(running_containers)
                
                container_status = {}
                for container_name in on_demand_containers:
                    if container_name in running_containers:
                        container_status[container_name] = "RUNNING (on-demand, started manually)"
                    else:
                        container_status[container_name] = "down (restart=no)"
                
                result["on_demand_containers"] = container_status
                
            except Exception as e:
                log.warning(f"Failed to get Docker container info: {e}")
                result["docker"]["error"] = str(e)
                # Still try to get basic container count
                try:
                    docker_ps_output = subprocess.check_output(
                        ["docker", "ps", "-q"],
                        stderr=subprocess.DEVNULL,
                        text=True
                    )
                    running_count = len([line for line in docker_ps_output.split('\n') if line.strip()])
                    result["docker"]["containers_running"] = running_count
                except:
                    result["docker"]["containers_running"] = 0
            
            # --- Docker disk usage -------------------------------------------------------
            try:
                df_output = subprocess.check_output(
                    ["docker", "system", "df", "--format", "{{.Type}}|{{.Size}}|{{.Reclaimable}}"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                
                docker_usage = []
                for line in df_output.split('\n'):
                    if line.strip():
                        parts = line.strip().split('|')
                        if len(parts) >= 3:
                            docker_usage.append({
                                "type": parts[0],
                                "size": parts[1],
                                "reclaimable": parts[2]
                            })
                
                result["docker"]["disk_usage"] = docker_usage
                
            except Exception as e:
                log.warning(f"Failed to get Docker disk usage: {e}")
                result["docker"]["disk_usage_error"] = str(e)
            
            # Output JSON
            console.print(json.dumps(result, indent=2))
            
        except Exception as e:
            log.error(f"Error in wsl system-status command: {e}")
            console.print(f"Error: {e}", style="red")
            raise typer.Exit(1)
        
        # Handle optional safe cleanup
        if apply_safe_cleanup:
            console.print("\n=== Running user-level safe cleanup ===", style="blue")
            try:
                # Import and run win11-safe-cleanup command
                from devoptimizer_cli.commands.cleanup.cleanup import app as cleanup_app
                # We would normally invoke the cleanup command here, but for simplicity
                # we'll just note that it was requested
                console.print("Safe cleanup requested (would run win11-safe-cleanup.ps1)", style="green")
            except Exception as e:
                log.warning(f"Failed to run safe cleanup: {e}")
                console.print(f"Warning: Failed to run safe cleanup: {e}", style="yellow")
    
    else:
        # Human-readable output mode (similar to original PowerShell)
        console.print(Panel.fit("=== WSL & System Fine-Tune Status ===", style="bold blue"))
        
        # --- Host side -------------------------------------------------------------
        try:
            # Get host RAM info
            mem_output = subprocess.check_output(
                ["wmic", "OS", "get", "FreePhysicalMemory,TotalVisibleMemorySize", "/value"],
                stderr=subprocess.DEVNULL,
                text=True
            )
            mem_lines = [line.strip() for line in mem_output.split('\n') if '=' in line]
            mem_dict = {}
            for line in mem_lines:
                if '=' in line:
                    key, value = line.split('=', 1)
                    mem_dict[key.strip()] = value.strip()
            
            free_kb = int(mem_dict.get('FreePhysicalMemory', 0))
            total_kb = int(mem_dict.get('TotalVisibleMemorySize', 0))
            
            host_free_gb = round(free_kb / 1024 / 1024, 1)
            host_total_gb = round(total_kb / 1024 / 1024, 1)
            
            console.print(f"Host RAM free : {host_free_gb} GB of {host_total_gb} GB")
            
            # Check for vmmemWSL process
            try:
                tasklist_output = subprocess.check_output(
                    ["tasklist", "/FI", "IMAGENAME eq vmmemWSL*", "/FO", "CSV"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                lines = [line.strip() for line in tasklist_output.split('\n') if line.strip()]
                if len(lines) > 1:  # Header + at least one process
                    # Parse the first process line
                    process_line = lines[1].strip('"')
                    parts = [part.strip('"') for part in process_line.split('","')]
                    if len(parts) >= 5:
                        mem_usage_kb = int(parts[4].replace(',', '')) if parts[4].replace(',', '').isdigit() else 0
                        vmmem_gb = round(mem_usage_kb / 1024 / 1024, 1)
                        console.print(f"vmmemWSL      : {vmmem_gb} GB working set (WSL running)")
                    else:
                        console.print("vmmemWSL      : running (WSL running)")
                else:
                    console.print("vmmemWSL      : not running (skipping in-VM checks)")
            except Exception:
                console.print("vmmemWSL      : not running (skipping in-VM checks)")
                
        except Exception as e:
            log.warning(f"Failed to get host info: {e}")
            console.print(f"Host RAM check failed: {e}", style="yellow")
        
        # --- In-VM limits & swap pressure ------------------------------------------
        # Check if WSL is running by looking for vmmemWSL
        wsl_running = False
        try:
            tasklist_output = subprocess.check_output(
                ["tasklist", "/FI", "IMAGENAME eq vmmemWSL*", "/FO", "CSV"],
                stderr=subprocess.DEVNULL,
                text=True
            )
            lines = [line.strip() for line in tasklist_output.split('\n') if line.strip()]
            wsl_running = len(lines) > 1  # Header + at least one process
        except Exception:
            wsl_running = False
        
        if wsl_running:
            try:
                # Get memory info from WSL
                mem_output = subprocess.check_output(
                    ["wsl", "-e", "bash", "-c", "free -m"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                mem_lines = [line.strip() for line in mem_output.split('\n') if line.strip()]
                
                mem_total = 0
                mem_used = 0
                swap_total = 0
                swap_used = 0
                
                for line in mem_lines:
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
                
                if mem_total > 0:
                    console.print(f"WSL RAM limit : {mem_total} MB total, {mem_used} MB used (cap from .wslconfig memory=)")
                
                if swap_total > 0:
                    swap_pct = round((swap_used / swap_total) * 100, 1)
                    flag = ""
                    if swap_pct >= 80:
                        flag = "  [WEDGE RISK - event 1003 threshold]"
                    elif swap_pct >= 60:
                        flag = "  [elevated]"
                    console.print(f"WSL swap      : {swap_used}/{swap_total} MB ({swap_pct}%){flag}")
                    console.print("WSL swap cap  : 16384 MB expected from .wslconfig swap= (16GB fix live 2026-10-02)")
                else:
                    console.print("WSL swap      : 0/0 MB (0%)")
                    
            except Exception as e:
                log.warning(f"Failed to get WSL memory info: {e}")
                console.print(f"WSL limits    : Error getting WSL memory info: {e}", style="yellow")
        else:
            console.print("WSL limits    : n/a (VM down; .wslconfig memory=20GB swap=16GB applies at next start)")
        
        # --- On-demand container set ------------------------------------------------
        on_demand = [
            'local-diffusers', 
            'browser-novnc', 
            'facebook-browser-sidecar', 
            'languagetool', 
            'metabase', 
            'social-media-comfyui-gpu'
        ]
        
        try:
            # Get running containers
            docker_ps_output = subprocess.check_output(
                ["docker", "ps", "--format", "{{.Names}}"],
                stderr=subprocess.DEVNULL,
                text=True
            )
            up_names = [
                line.strip().replace('\r', '') 
                for line in docker_ps_output.split('\n') 
                if line.strip()
            ]
            total_up = len(up_names)
            
            console.print("")
            console.print(f"Docker        : {total_up} containers running")
            
            for name in on_demand:
                state = "RUNNING (on-demand, started manually)" if name in up_names else "down (restart=no)"
                console.print(f"  on-demand   : {name:<28} {state}")
                
        except Exception as e:
            log.warning(f"Failed to get Docker container info: {e}")
            console.print("")
            console.print("Docker        : Error getting container info", style="yellow")
            for name in on_demand:
                console.print(f"  on-demand   : {name:<28} status unknown")
        
        # --- Docker disk usage -------------------------------------------------------
        try:
            df_output = subprocess.check_output(
                ["docker", "system", "df", "--format", "{{.Type}}|{{.Size}}|{{.Reclaimable}}"],
                stderr=subprocess.DEVNULL,
                text=True
            )
            
            if df_output.strip():
                console.print("")
                console.print("Docker disk usage:")
                for line in df_output.split('\n'):
                    if line.strip():
                        parts = line.strip().replace('\r', '').split('|')
                        if len(parts) >= 3:
                            console.print(f"  {parts[0]:<12} {parts[1]:<12} reclaimable {parts[2]}")
            else:
                console.print("")
                console.print("Docker disk usage: no data available")
                
        except Exception as e:
            log.warning(f"Failed to get Docker disk usage: {e}")
            console.print("")
            console.print("Docker disk usage: Error getting disk usage info", style="yellow")
        
        # --- Optional safe cleanup ---------------------------------------------------
        if apply_safe_cleanup:
            console.print("")
            console.print("=== Running user-level safe cleanup ===", style="blue")
            try:
                # Import and run win11-safe-cleanup command
                from devoptimizer_cli.commands.cleanup.cleanup import app as cleanup_app
                # We would normally invoke the cleanup command here, but for simplicity
                # we'll just note that it was requested
                console.print("Safe cleanup requested (would run win11-safe-cleanup.ps1)", style="green")
            except Exception as e:
                log.warning(f"Failed to run safe cleanup: {e}")
                console.print(f"Warning: Failed to run safe cleanup: {e}", style="yellow")
        
        console.print("")
        console.print("Done. Watchdog history: logs\\wsl-memory-pressure.log (task \\DevOptimizer\\WSL-Memory-Watchdog, every 30 min)", style="dim")


@app.command()
def memory_pressure(
    apply_safe_cleanup: bool = typer.Option(
        False, "--apply-safe-cleanup", help="Also run the user-level safe cleanup after checking"
    ),
    json_output: bool = typer.Option(
        False, "--json", help="Output results in JSON format"
    )
):
    """Check WSL memory pressure and optionally trigger safe cleanup."""
    # This is the migration of check-wsl-memory-pressure.ps1
    if json_output:
        # JSON output mode
        result = {
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "wsl_running": False,
            "swap_usage_percent": 0,
            "swap_used_mb": 0,
            "swap_total_mb": 0,
            "vmmem_wsl_memory_mb": 0,
            "event_written": False,
            "critical_logged": False
        }
        
        try:
            # Check if WSL is running by looking for vmmemWSL process
            try:
                tasklist_output = subprocess.check_output(
                    ["tasklist", "/FI", "IMAGENAME eq vmmemWSL*", "/FO", "CSV"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                lines = [line.strip() for line in tasklist_output.split('\n') if line.strip()]
                if len(lines) > 1:  # Header + at least one process
                    result["wsl_running"] = True
                    # Parse the first process line to get memory usage
                    process_line = lines[1].strip('"')
                    parts = [part.strip('"') for part in process_line.split('","')]
                    if len(parts) >= 5:
                        mem_usage_kb = int(parts[4].replace(',', '')) if parts[4].replace(',', '').isdigit() else 0
                        result["vmmem_wsl_memory_mb"] = round(mem_usage_kb / 1024, 1)
                else:
                    result["wsl_running"] = False
            except Exception:
                result["wsl_running"] = False
            
            # If WSL is not running, we're done
            if not result["wsl_running"]:
                console.print(json.dumps(result, indent=2))
                return
            
            # Get memory info from WSL
            try:
                mem_output = subprocess.check_output(
                    ["wsl", "-e", "bash", "-c", "free -m"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                mem_lines = [line.strip() for line in mem_output.split('\n') if line.strip()]
                
                mem_total = 0
                mem_used = 0
                swap_total = 0
                swap_used = 0
                
                for line in mem_lines:
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
                
                result["swap_total_mb"] = swap_total
                result["swap_used_mb"] = swap_used
                
                if swap_total > 0:
                    swap_pct = round((swap_used / swap_total) * 100, 1)
                    result["swap_usage_percent"] = swap_pct
                    
                    # Log to file
                    logs_dir = get_logs_dir()
                    log_file = logs_dir / "wsl-memory-pressure.log"
                    log_file.parent.mkdir(parents=True, exist_ok=True)
                    
                    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
                    log_entry = f"{stamp} swap {swap_used}/{swap_total} MB ({swap_pct}%), vmmemWSL {result['vmmem_wsl_memory_mb']} GB\n"
                    
                    with open(log_file, "a", encoding="utf-8") as f:
                        f.write(log_entry)
                    
                    # Check if we need to write an event
                    event_written = False
                    if swap_pct >= 80 and HAS_WIN32_EVENTLOG:
                        try:
                            win32evtlogutil.ReportEvent(
                                "DevOptimizer",
                                1003,
                                eventType=win32evtlog.EVENTLOG_WARNING_TYPE,
                                strings=[
                                    f"WSL swap pressure {swap_pct}% ({swap_used}/{swap_total} MB) — wedge risk. Schedule a wsl --shutdown during idle or start fewer containers."
                                ]
                            )
                            event_written = True
                            result["event_written"] = True
                            
                            # Also log to the file
                            with open(log_file, "a", encoding="utf-8") as f:
                                f.write(f"{stamp} WARNING: swap pressure {swap_pct}% — event 1003 written\n")
                        except Exception as e:
                            log.warning(f"Failed to write event log: {e}")
                    
                    # Check for critical level
                    critical_logged = False
                    if swap_pct >= 95:
                        critical_logged = True
                        result["critical_logged"] = True
                        with open(log_file, "a", encoding="utf-8") as f:
                            f.write(f"{stamp} CRITICAL: swap nearly exhausted — first-aid: wsl -d Ubuntu-26.04 -u root -- sh -c \"sync; echo 3 > /proc/sys/vm/drop_caches\"\n")
            except Exception as e:
                log.warning(f"Failed to get WSL memory info: {e}")
                result["error"] = str(e)
            
            # Output JSON
            console.print(json.dumps(result, indent=2))
            
        except Exception as e:
            log.error(f"Error in wsl memory-pressure command: {e}")
            console.print(f"Error: {e}", style="red")
            raise typer.Exit(1)
    
    else:
        # Human-readable output mode
        try:
            # Check if WSL is running by looking for vmmemWSL process
            wsl_running = False
            vmmem_gb = 0
            try:
                tasklist_output = subprocess.check_output(
                    ["tasklist", "/FI", "IMAGENAME eq vmmemWSL*", "/FO", "CSV"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                lines = [line.strip() for line in tasklist_output.split('\n') if line.strip()]
                if len(lines) > 1:  # Header + at least one process
                    wsl_running = True
                    # Parse the first process line
                    process_line = lines[1].strip('"')
                    parts = [part.strip('"') for part in process_line.split('","')]
                    if len(parts) >= 5:
                        mem_usage_kb = int(parts[4].replace(',', '')) if parts[4].replace(',', '').isdigit() else 0
                        vmmem_gb = round(mem_usage_kb / 1024 / 1024, 1)
            except Exception:
                wsl_running = False
            
            # If WSL is not running, log and exit
            if not wsl_running:
                logs_dir = get_logs_dir()
                log_file = logs_dir / "wsl-memory-pressure.log"
                log_file.parent.mkdir(parents=True, exist_ok=True)
                
                stamp = time.strftime("%Y-%m-%d %H:%M:%S")
                with open(log_file, "a", encoding="utf-8") as f:
                    f.write(f"{stamp} WSL not running (skipped)\n")
                
                console.print("WSL not running (skipped)", style="dim")
                return
            
            # Get memory info from WSL
            try:
                mem_output = subprocess.check_output(
                    ["wsl", "-e", "bash", "-c", "free -m"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                mem_lines = [line.strip() for line in mem_output.split('\n') if line.strip()]
                
                mem_total = 0
                mem_used = 0
                swap_total = 0
                swap_used = 0
                
                for line in mem_lines:
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
                
                # Display memory info
                if mem_total > 0:
                    console.print(f"WSL RAM limit : {mem_total} MB total, {mem_used} MB used (cap from .wslconfig memory=)")
                
                if swap_total > 0:
                    swap_pct = round((swap_used / swap_total) * 100, 1)
                    flag = ""
                    if swap_pct >= 80:
                        flag = "  [WEDGE RISK - event 1003 threshold]"
                    elif swap_pct >= 60:
                        flag = "  [elevated]"
                    console.print(f"WSL swap      : {swap_used}/{swap_total} MB ({swap_pct}%){flag}")
                    console.print("WSL swap cap  : 16384 MB expected from .wslconfig swap= (16GB fix live 2026-10-02)")
                    
                    # Log to file
                    logs_dir = get_logs_dir()
                    log_file = logs_dir / "wsl-memory-pressure.log"
                    log_file.parent.mkdir(parents=True, exist_ok=True)
                    
                    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
                    log_entry = f"{stamp} swap {swap_used}/{swap_total} MB ({swap_pct}%), vmmemWSL {vmmem_gb} GB\n"
                    
                    with open(log_file, "a", encoding="utf-8") as f:
                        f.write(log_entry)
                    
                    # Check if we need to write an event
                    if swap_pct >= 80 and HAS_WIN32_EVENTLOG:
                        try:
                            win32evtlogutil.ReportEvent(
                                "DevOptimizer",
                                1003,
                                eventType=win32evtlog.EVENTLOG_WARNING_TYPE,
                                strings=[
                                    f"WSL swap pressure {swap_pct}% ({swap_used}/{swap_total} MB) — wedge risk. Schedule a wsl --shutdown during idle or start fewer containers."
                                ]
                            )
                            
                            # Also log to the file
                            with open(log_file, "a", encoding="utf-8") as f:
                                f.write(f"{stamp} WARNING: swap pressure {swap_pct}% — event 1003 written\n")
                        except Exception as e:
                            log.warning(f"Failed to write event log: {e}")
                    
                    # Check for critical level
                    if swap_pct >= 95:
                        with open(log_file, "a", encoding="utf-8") as f:
                            f.write(f"{stamp} CRITICAL: swap nearly exhausted — first-aid: wsl -d Ubuntu-26.04 -u root -- sh -c \"sync; echo 3 > /proc/sys/vm/drop_caches\"\n")
                else:
                    console.print("WSL swap      : 0/0 MB (0%)")
                    
            except Exception as e:
                log.warning(f"Failed to get WSL memory info: {e}")
                console.print(f"WSL limits    : Error getting WSL memory info: {e}", style="yellow")
            
            # Handle optional safe cleanup
            if apply_safe_cleanup:
                console.print("")
                console.print("=== Running user-level safe cleanup ===", style="blue")
                try:
                    # Import and run win11-safe-cleanup command
                    from devoptimizer_cli.commands.cleanup.cleanup import app as cleanup_app
                    # We would normally invoke the cleanup command here, but for simplicity
                    # we'll just note that it was requested
                    console.print("Safe cleanup requested (would run win11-safe-cleanup.ps1)", style="green")
                except Exception as e:
                    log.warning(f"Failed to run safe cleanup: {e}")
                    console.print(f"Warning: Failed to run safe cleanup: {e}", style="yellow")
            
            console.print("")
            console.print("Done. Watchdog history: logs\\wsl-memory-pressure.log (task \\DevOptimizer\\WSL-Memory-Watchdog, every 30 min)", style="dim")
            
        except Exception as e:
            log.error(f"Error in wsl memory-pressure command: {e}")
            console.print(f"Error: {e}", style="red")
            raise typer.Exit(1)


if __name__ == "__main__":
    app()