"""
DevOptimizer Core Module
Python port of DevOptimizer.psm1 - Core automation functions for Windows optimization
"""

import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

from rich.console import Console

console = Console()

# Module constants
DEVOPTIMIZER_ROOT = Path("D:/DevOptimizer")
VAULT_NAME = "DevOptimizerVault"

REQUIRED_DIRS = [
    "bin",
    "ps",
    "py",
    "tasks",
    "configs",
    ".env",
    "metrics",
    "traces",
    "logs",
    "ai-analysis"
]

DEFAULT_COUNTERS = [
    r"\\Processor(_Total)\\% Processor Time",
    r"\\Memory\\Available MBytes",
    r"\\Memory\\Committed Bytes",
    r"\\PhysicalDisk(_Total)\\Disk Read Bytes/sec",
    r"\\PhysicalDisk(_Total)\\Disk Write Bytes/sec",
    r"\\Network Interface(*)\\Bytes Total/sec",
    r"\\Process(*)\\Working Set",
    r"\\System\\Processor Queue Length"
]


@dataclass
class SystemMetrics:
    """System metrics snapshot"""
    timestamp: datetime
    cpu_usage: float
    cpu_processes: int
    memory_total_gb: float
    memory_available_gb: float
    memory_committed_gb: float
    disk_read_bytes_per_sec: float
    disk_write_bytes_per_sec: float
    network_interfaces: dict[str, float]


def run_command(cmd: list[str], capture: bool = True, check: bool = False) -> subprocess.CompletedProcess:
    """Run a command with proper Windows handling"""
    try:
        return subprocess.run(
            cmd,
            capture_output=capture,
            text=True,
            check=check,
            encoding='utf-8',
            errors='replace'
        )
    except FileNotFoundError:
        return subprocess.CompletedProcess(cmd, 1, "", f"Command not found: {cmd[0]}")
    except Exception as e:
        return subprocess.CompletedProcess(cmd, 1, "", str(e))


def initialize_devoptimizer() -> bool:
    """
    Initialize DevOptimizer environment and verify prerequisites
    """
    console.print("Initializing DevOptimizer...", style="green")

    # Check Python version
    if sys.version_info < (3, 10):
        console.print(f"Python 3.10+ recommended. Current: {sys.version}", style="yellow")

    # Verify required directories
    for dir_name in REQUIRED_DIRS:
        dir_path = DEVOPTIMIZER_ROOT / dir_name
        if not dir_path.exists():
            console.print(f"Directory {dir_path} not found. Creating...", style="yellow")
            dir_path.mkdir(parents=True, exist_ok=True)

    console.print("✓ DevOptimizer initialized successfully", style="green")
    return True


def start_performance_collection(
    duration: int = 0,
    counters: Optional[list[str]] = None
) -> dict[str, Any]:
    """
    Start performance counter collection using logman
    
    Args:
        duration: Duration in seconds (0 = continuous until stopped)
        counters: Custom counter set (default: comprehensive set)
    """
    if counters is None:
        counters = DEFAULT_COUNTERS

    session_name = "DevOptimizer-Counters"
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = DEVOPTIMIZER_ROOT / "metrics" / f"counters_{timestamp}.blg"
    counter_file = DEVOPTIMIZER_ROOT / "metrics" / "counters.txt"

    try:
        # Stop existing session if running
        run_command(["logman", "stop", session_name, "-ets"], capture=True)

        # Create counter file
        counter_file.parent.mkdir(parents=True, exist_ok=True)
        counter_file.write_text("\n".join(counters), encoding="utf-8")

        # Build logman arguments
        logman_args = [
            "create", "counter", session_name,
            "-cf", str(counter_file),
            "-f", "bin",
            "-o", str(output_path)
        ]

        if duration > 0:
            logman_args.extend(["-d", str(duration)])

        # Start collection
        result = run_command(["logman"] + logman_args, check=True)

        if duration > 0:
            console.print(f"✓ Performance collection started for {duration} seconds", style="green")
        else:
            console.print("✓ Performance collection started (continuous)", style="green")

        return {
            "session_name": session_name,
            "output_path": str(output_path),
            "status": "Running"
        }
    except Exception as e:
        console.print(f"Failed to start performance collection: {e}", style="red")
        return {"status": "Failed", "error": str(e)}


def stop_performance_collection(session_name: str = "DevOptimizer-Counters") -> bool:
    """Stop performance counter collection"""
    try:
        result = run_command(["logman", "stop", session_name, "-ets"], check=True)
        console.print("✓ Performance collection stopped", style="green")
        return True
    except Exception as e:
        console.print(f"Failed to stop performance collection: {e}", style="red")
        return False


def start_etw_trace(
    profile: str = "CPU",
    duration: int = 60
) -> dict[str, Any]:
    """
    Start ETW tracing using WPR
    
    Args:
        profile: WPR profile (CPU, DiskIO, Network, SystemActivity)
        duration: Duration in seconds
    """
    valid_profiles = ["CPU", "DiskIO", "Network", "SystemActivity"]
    if profile not in valid_profiles:
        console.print(f"Invalid profile: {profile}. Valid: {valid_profiles}", style="red")
        return {"status": "Failed", "error": "Invalid profile"}

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = DEVOPTIMIZER_ROOT / "traces" / f"trace_{profile}_{timestamp}.etl"

    try:
        # Start trace
        result = run_command(["wpr", "-start", profile, "-filemode"], check=True)
        console.print(f"✓ ETW trace started with {profile} profile", style="green")

        if duration > 0:
            time.sleep(duration)
            stop_etw_trace(str(output_path))

        return {
            "profile": profile,
            "output_path": str(output_path),
            "status": "Running"
        }
    except Exception as e:
        console.print(f"Failed to start ETW trace: {e}", style="red")
        return {"status": "Failed", "error": str(e)}


def stop_etw_trace(output_path: Optional[str] = None) -> Optional[str]:
    """Stop ETW tracing and save to file"""
    if output_path is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = str(DEVOPTIMIZER_ROOT / "traces" / f"trace_{timestamp}.etl")

    try:
        result = run_command(["wpr", "-stop", output_path], check=True)
        console.print(f"✓ ETW trace saved to: {output_path}", style="green")
        return output_path
    except Exception as e:
        console.print(f"Failed to stop ETW trace: {e}", style="red")
        return None


def export_event_logs(
    log_names: Optional[list[str]] = None,
    start_time: Optional[datetime] = None
) -> list[str]:
    """
    Export relevant event logs to files
    
    Args:
        log_names: List of log names to export
        start_time: Start time for filtering (default: 1 day ago)
    """
    if log_names is None:
        log_names = ["System", "Application", "Microsoft-Windows-Diagnostics-Performance/Operational"]
    
    if start_time is None:
        start_time = datetime.now().replace(day=datetime.now().day - 1)

    output_dir = DEVOPTIMIZER_ROOT / "logs" / "eventlogs"
    output_dir.mkdir(parents=True, exist_ok=True)

    exported_files = []

    for log_name in log_names:
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            safe_log_name = log_name.replace("/", "_").replace("-", "_")
            output_file = output_dir / f"{safe_log_name}_{timestamp}.evtx"

            # Export log using wevtutil
            query = f"*[System[TimeCreated[@SystemTime>='{start_time.isoformat()}Z']]]"
            result = run_command(["wevtutil", "epl", log_name, str(output_file), f"/q:{query}"], check=True)

            console.print(f"✓ Exported {log_name} to: {output_file}", style="green")
            exported_files.append(str(output_file))
        except Exception as e:
            console.print(f"Failed to export {log_name}: {e}", style="yellow")

    return exported_files


def install_dev_tools(package_file: Optional[str] = None) -> dict[str, Any]:
    """
    Install development tools using winget
    
    Args:
        package_file: Path to JSON file containing package list
    """
    if package_file is None:
        package_file = str(DEVOPTIMIZER_ROOT / "configs" / "winget-packages.json")

    if not Path(package_file).exists():
        console.print(f"Package file not found: {package_file}", style="yellow")
        return {"status": "Failed", "error": "Package file not found"}

    try:
        with open(package_file) as f:
            config = json.load(f)

        packages = config.get("packages", [])
        results = []

        for package in packages:
            package_name = package.get("name", "Unknown")
            package_id = package.get("id", "")
            category = package.get("category", "unknown")

            console.print(f"Installing {package_name}...", style="yellow")

            try:
                result = run_command([
                    "winget", "install", package_id,
                    "--accept-source-agreements",
                    "--accept-package-agreements",
                    "--silent"
                ], check=True)

                results.append({
                    "name": package_name,
                    "id": package_id,
                    "category": category,
                    "method": "winget",
                    "status": "success"
                })
                console.print(f"✓ Installed {package_name} (winget)", style="green")
            except Exception as e:
                results.append({
                    "name": package_name,
                    "id": package_id,
                    "category": category,
                    "method": "winget",
                    "status": "failed",
                    "error": str(e)
                })
                console.print(f"Failed to install {package_name}: {e}", style="yellow")

        return {"status": "Completed", "packages": results}
    except Exception as e:
        console.print(f"Failed to process package file: {e}", style="red")
        return {"status": "Failed", "error": str(e)}


def get_system_metrics() -> Optional[SystemMetrics]:
    """Get current system metrics snapshot"""
    try:
        # CPU
        cpu_result = run_command([
            "powershell", "-Command",
            "(Get-Counter '\\Processor(_Total)\\% Processor Time' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue"
        ])
        cpu_usage = float(cpu_result.stdout.strip()) if cpu_result.returncode == 0 else 0.0

        # Process count
        proc_result = run_command([
            "powershell", "-Command", "(Get-Process).Count"
        ])
        cpu_processes = int(proc_result.stdout.strip()) if proc_result.returncode == 0 else 0

        # Memory - Total
        mem_total_result = run_command([
            "powershell", "-Command",
            "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)"
        ])
        memory_total_gb = float(mem_total_result.stdout.strip()) if mem_total_result.returncode == 0 else 0.0

        # Memory - Available
        mem_avail_result = run_command([
            "powershell", "-Command",
            "[math]::Round((Get-Counter '\\Memory\\Available MBytes' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue / 1024, 2)"
        ])
        memory_available_gb = float(mem_avail_result.stdout.strip()) if mem_avail_result.returncode == 0 else 0.0

        # Memory - Committed
        mem_commit_result = run_command([
            "powershell", "-Command",
            "[math]::Round((Get-Counter '\\Memory\\Committed Bytes' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue / 1GB, 2)"
        ])
        memory_committed_gb = float(mem_commit_result.stdout.strip()) if mem_commit_result.returncode == 0 else 0.0

        # Disk
        disk_read_result = run_command([
            "powershell", "-Command",
            "(Get-Counter '\\PhysicalDisk(_Total)\\Disk Read Bytes/sec' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue"
        ])
        disk_read = float(disk_read_result.stdout.strip()) if disk_read_result.returncode == 0 else 0.0

        disk_write_result = run_command([
            "powershell", "-Command",
            "(Get-Counter '\\PhysicalDisk(_Total)\\Disk Write Bytes/sec' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue"
        ])
        disk_write = float(disk_write_result.stdout.strip()) if disk_write_result.returncode == 0 else 0.0

        # Network
        network_interfaces = {}
        net_result = run_command([
            "powershell", "-Command",
            "Get-Counter '\\Network Interface(*)\\Bytes Total/sec' -SampleInterval 1 -MaxSamples 1 | Select-Object -ExpandProperty CounterSamples | Where-Object {$_.CookedValue -gt 0} | ForEach-Object { $name = ($_.Path -split '\\\\')[3] -replace '[{}]', ''; \"$name=$($_.CookedValue)\" }"
        ])
        if net_result.returncode == 0:
            for line in net_result.stdout.strip().split("\n"):
                if "=" in line:
                    name, value = line.split("=", 1)
                    network_interfaces[name] = float(value)

        return SystemMetrics(
            timestamp=datetime.now(),
            cpu_usage=cpu_usage,
            cpu_processes=cpu_processes,
            memory_total_gb=memory_total_gb,
            memory_available_gb=memory_available_gb,
            memory_committed_gb=memory_committed_gb,
            disk_read_bytes_per_sec=disk_read,
            disk_write_bytes_per_sec=disk_write,
            network_interfaces=network_interfaces
        )
    except Exception as e:
        console.print(f"Failed to get system metrics: {e}", style="red")
        return None


def get_system_metrics_dict() -> dict[str, Any]:
    """Get system metrics as dictionary (for JSON serialization)"""
    metrics = get_system_metrics()
    if metrics is None:
        return {}
    
    data = asdict(metrics)
    data["timestamp"] = metrics.timestamp.isoformat()
    return data


# Module-level exports
__all__ = [
    "initialize_devoptimizer",
    "start_performance_collection",
    "stop_performance_collection",
    "start_etw_trace",
    "stop_etw_trace",
    "export_event_logs",
    "install_dev_tools",
    "get_system_metrics",
    "get_system_metrics_dict",
    "SystemMetrics",
    "DEVOPTIMIZER_ROOT",
    "REQUIRED_DIRS",
    "DEFAULT_COUNTERS"
]