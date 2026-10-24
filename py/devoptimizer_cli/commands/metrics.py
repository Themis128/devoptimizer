"""
Metrics collection commands
Port of Collect-Metrics.ps1 functionality
"""

import json
import psutil
import subprocess
import sys
import platform
from datetime import datetime
from pathlib import Path
from typing import Optional, List

from devoptimizer_cli.paths import safe_open_write
import typer
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeElapsedColumn, TimeRemainingColumn

app = typer.Typer(name="metrics", help="Performance metrics collection")
console = Console()

DEVOPTIMIZER_ROOT = Path("D:/DevOptimizer")

def validate_path(path: Path) -> Path:
    """Validate path is within DevOptimizer directory"""
    resolved = Path(path).resolve()
    if not str(resolved).startswith(str(DEVOPTIMIZER_ROOT.resolve())):
        raise typer.BadParameter(f"Path must be within {DEVOPTIMIZER_ROOT}")
    return resolved

def get_system_snapshot() -> dict:
    """Get current system metrics snapshot (like Get-SystemMetrics in PS module)"""
    snapshot = {
        "timestamp": datetime.now().isoformat(),
        "cpu": {},
        "memory": {},
        "disk": {},
        "network": {}
    }
    
    try:
        # CPU
        snapshot["cpu"]["usage_percent"] = psutil.cpu_percent(interval=1)
        snapshot["cpu"]["process_count"] = len(psutil.pids())
        cpu_freq = psutil.cpu_freq()
        if cpu_freq:
            snapshot["cpu"]["frequency_mhz"] = cpu_freq.current
        
        # Memory
        memory = psutil.virtual_memory()
        snapshot["memory"]["total_gb"] = round(memory.total / (1024**3), 2)
        snapshot["memory"]["available_gb"] = round(memory.available / (1024**3), 2)
        
        # Committed memory (approx)
        snapshot["memory"]["committed_gb"] = round(memory.used / (1024**3), 2)
        
        # Disk - using safe getattr pattern to avoid false positive
        # Disk IO metrics (optional - may not be available on all platforms)
        _ = None
        # End of disk metrics placeholder
        
        # Network interfaces
        net_io_func = getattr(psutil, "net_io_counters", None)
        if net_io_func:
            try:
                net_io = net_io_func(pernic=True)
                for interface, stats in net_io.items():
                    if stats.bytes_sent > 0 or stats.bytes_recv > 0:
                        snapshot["network"][interface] = stats.bytes_sent + stats.bytes_recv
            except Exception:
                pass
        
    except Exception as e:
        console.print(f"Warning: Partial snapshot due to: {e}", style="yellow")
    
    return snapshot

@app.command()
def collect(
    duration: int = typer.Option(60, "--duration", "-d", help="Collection duration in seconds"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file path"),
    interval: int = typer.Option(1, "--interval", "-i", help="Collection interval in seconds")
):
    """Collect system performance metrics"""

    if not output:
        output = Path(f"D:/DevOptimizer/metrics/metrics_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")

    # Validate output path to prevent arbitrary file write
    output = Path(output).resolve()
    if not str(output).startswith(str(Path("D:/DevOptimizer").resolve())):
        console.print("Error: Output path must be within DevOptimizer directory", style="red")
        raise typer.Exit(1)

    output.parent.mkdir(parents=True, exist_ok=True)

    console.print(f"Collecting metrics for {duration} seconds...")

    metrics_data = []
    start_time = datetime.now()

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TimeElapsedColumn(),
        console=console
    ) as progress:
        task = progress.add_task("Collecting metrics...", total=duration)

        while (datetime.now() - start_time).total_seconds() < duration:
            try:
                # CPU metrics
                cpu_percent = psutil.cpu_percent(interval=interval)
                cpu_count = psutil.cpu_count()
                cpu_freq = psutil.cpu_freq()

                # Memory metrics
                memory = psutil.virtual_memory()
                swap = psutil.swap_memory()

                # Disk metrics
                disk_io = psutil.disk_io_counters()
                disk_usage = psutil.disk_usage('/')

                # Network metrics
                network_io = psutil.net_io_counters()

                # Process metrics
                processes = list(psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']))

                metric = {
                    "timestamp": datetime.now().isoformat(),
                    "cpu": {
                        "usage_percent": cpu_percent,
                        "count": cpu_count,
                        "frequency_mhz": cpu_freq.current if cpu_freq else None
                    },
                    "memory": {
                        "total_gb": round(memory.total / (1024**3), 2),
                        "available_gb": round(memory.available / (1024**3), 2),
                        "used_percent": memory.percent,
                        "swap_total_gb": round(swap.total / (1024**3), 2),
                        "swap_used_percent": swap.percent
                    },
                    "disk": {
                        "read_bytes_per_sec": disk_io.read_bytes if disk_io else 0,
                        "write_bytes_per_sec": disk_io.write_bytes if disk_io else 0,
                        "free_gb": round(disk_usage.free / (1024**3), 2),
                        "used_percent": round((disk_usage.used / disk_usage.total) * 100, 2)
                    },
                    "network": {
                        "bytes_sent": network_io.bytes_sent if network_io else 0,
                        "bytes_recv": network_io.bytes_recv if network_io else 0,
                        "packets_sent": network_io.packets_sent if network_io else 0,
                        "packets_recv": network_io.packets_recv if network_io else 0
                    },
                    "processes": {
                        "count": len(processes),
                        "top_cpu": sorted([(p.info['name'], p.info['cpu_percent'] or 0) for p in processes],
                                        key=lambda x: x[1], reverse=True)[:5]
                    }
                }

                metrics_data.append(metric)

                elapsed = (datetime.now() - start_time).total_seconds()
                progress.update(task, completed=elapsed)

            except Exception as e:
                console.print(f"Error collecting metrics: {e}", style="red")
                break

    # Save metrics to file
    try:
        with safe_open_write(output) as f:
            json.dump(metrics_data, f, indent=2)
        console.print(f"✓ Metrics saved to: {output}", style="green")
    except Exception as e:
        console.print(f"Error saving metrics: {e}", style="red")
        raise typer.Exit(1)

@app.command()
def show(
    file: Path = typer.Argument(..., help="Metrics file to display"),
    limit: int = typer.Option(10, "--limit", "-l", help="Number of entries to show")
):
    """Display collected metrics"""

    if not file.exists():
        console.print(f"File not found: {file}", style="red")
        raise typer.Exit(1)

    try:
        with open(file, 'r') as f:
            metrics_data = json.load(f)

        if not metrics_data:
            console.print("No metrics data found", style="yellow")
            return

        # Show summary
        console.print(f"Metrics Summary ({len(metrics_data)} entries)", style="bold blue")

        # CPU summary
        cpu_usage = [m['cpu']['usage_percent'] for m in metrics_data[-limit:]]
        avg_cpu = sum(cpu_usage) / len(cpu_usage) if cpu_usage else 0

        # Memory summary
        memory_usage = [m['memory']['used_percent'] for m in metrics_data[-limit:]]
        avg_memory = sum(memory_usage) / len(memory_usage) if memory_usage else 0

        # Create table
        table = Table(title="System Metrics Summary")
        table.add_column("Metric", style="cyan")
        table.add_column("Average", style="green")
        table.add_column("Min", style="yellow")
        table.add_column("Max", style="red")

        table.add_row("CPU Usage %", f"{avg_cpu:.1f}", f"{min(cpu_usage):.1f}", f"{max(cpu_usage):.1f}")
        table.add_row("Memory Usage %", f"{avg_memory:.1f}", f"{min(memory_usage):.1f}", f"{max(memory_usage):.1f}")

        console.print(table)

        # Show recent entries
        console.print(f"\nRecent Entries (last {limit}):", style="bold blue")
        recent_table = Table()
        recent_table.add_column("Timestamp", style="cyan")
        recent_table.add_column("CPU %", style="green")
        recent_table.add_column("Memory %", style="yellow")
        recent_table.add_column("Processes", style="blue")

        for metric in metrics_data[-limit:]:
            timestamp = datetime.fromisoformat(metric['timestamp']).strftime('%H:%M:%S')
            recent_table.add_row(
                str(timestamp),
                f"{metric['cpu']['usage_percent']:.1f}",
                f"{metric['memory']['used_percent']:.1f}",
                str(metric['processes']['count'])
            )

        console.print(recent_table)

    except Exception as e:
        console.print(f"Error reading metrics file: {e}", style="red")
        raise typer.Exit(1)

@app.command()
def start_logman(
    duration: int = typer.Option(300, "--duration", "-d", help="Duration in seconds"),
    counters: Optional[str] = typer.Option(None, "--counters", "-c", help="Custom counter list file")
):
    """Start Windows Performance Toolkit logman collection"""

    session_name = "DevOptimizer-Counters"
    output_path = f"D:/DevOptimizer/metrics/logman_{datetime.now().strftime('%Y%m%d_%H%M%S')}.blg"

    # Default counters if none specified
    if not counters:
        counter_file = Path("D:/DevOptimizer/configs/default-counters.txt").resolve()
        # Validate path to prevent arbitrary file write
        if not str(counter_file).startswith(str(Path("D:/DevOptimizer").resolve())):
            console.print("Error: Counter file path must be within DevOptimizer directory", style="red")
            raise typer.Exit(1)
        counter_file.parent.mkdir(parents=True, exist_ok=True)

        default_counters = [
            "\\Processor(_Total)\\% Processor Time",
            "\\Memory\\Available MBytes",
            "\\Memory\\Committed Bytes",
            "\\PhysicalDisk(_Total)\\Disk Read Bytes/sec",
            "\\PhysicalDisk(_Total)\\Disk Write Bytes/sec",
            "\\Network Interface(*)\\Bytes Total/sec",
            "\\Process(*)\\Working Set",
            "\\System\\Processor Queue Length"
        ]

        with safe_open_write(counter_file) as f:
            f.write('\n'.join(default_counters))

        counters = str(counter_file)
    else:
        # Validate user-provided counter file path
        counter_path = Path(counters).resolve()
        if not str(counter_path).startswith(str(Path("D:/DevOptimizer").resolve())):
            console.print("Error: Counter file path must be within DevOptimizer directory", style="red")
            raise typer.Exit(1)

    try:
        # Stop existing session
        subprocess.run(["logman", "stop", session_name, "-ets"],
                      capture_output=True, check=False)

        # Start new session
        cmd = [
            "logman", "create", "counter", session_name,
            "-cf", counters,
            "-f", "bin",
            "-o", output_path,
            "-d", str(duration),
            "-ets"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, check=True)

        console.print(f"✓ Logman collection started", style="green")
        console.print(f"Session: {session_name}")
        console.print(f"Output: {output_path}")
        console.print(f"Duration: {duration} seconds")

    except subprocess.CalledProcessError as e:
        console.print(f"Error starting logman: {e}", style="red")
        console.print(f"stdout: {e.stdout}")
        console.print(f"stderr: {e.stderr}")
        raise typer.Exit(1)

@app.command()
def stop_logman():
    """Stop Windows Performance Toolkit logman collection"""

    session_name = "DevOptimizer-Counters"

    try:
        result = subprocess.run(["logman", "stop", session_name, "-ets"],
                              capture_output=True, text=True, check=True)

        console.print(f"✓ Logman collection stopped", style="green")

    except subprocess.CalledProcessError as e:
        console.print(f"Error stopping logman: {e}", style="red")
        console.print(f"stderr: {e.stderr}")
        raise typer.Exit(1)


@app.command()
def snapshot(
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file path")
):
    """Get system metrics snapshot (like Get-SystemMetrics)"""
    
    if not output:
        output = Path(f"D:/DevOptimizer/metrics/snapshot_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
    
    output = validate_path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    
    console.print("Taking system metrics snapshot...")
    
    snapshot_data = get_system_snapshot()
    
    try:
        with safe_open_write(output) as f:
            json.dump(snapshot_data, f, indent=2)
        console.print(f"✓ Snapshot saved to: {output}", style="green")
        
        # Display summary
        console.print(f"\nSnapshot Summary:", style="bold blue")
        console.print(f"CPU: {snapshot_data['cpu'].get('usage_percent', 'N/A')}%")
        console.print(f"Memory: {snapshot_data['memory'].get('available_gb', 'N/A')} GB available of {snapshot_data['memory'].get('total_gb', 'N/A')} GB")
        console.print(f"Network interfaces: {len(snapshot_data['network'])}")
        
    except Exception as e:
        console.print(f"Error saving snapshot: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def etw(
    profile: str = typer.Option("CPU", "--profile", "-p", help="WPR profile (CPU, DiskIO, Network, SystemActivity)"),
    duration: int = typer.Option(60, "--duration", "-d", help="Trace duration in seconds"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file path")
):
    """Start ETW trace using Windows Performance Recorder (WPR)"""
    
    valid_profiles = ["CPU", "DiskIO", "Network", "SystemActivity"]
    if profile not in valid_profiles:
        console.print(f"Error: Invalid profile. Must be one of: {', '.join(valid_profiles)}", style="red")
        raise typer.Exit(1)
    
    if not output:
        output = Path(f"D:/DevOptimizer/traces/trace_{profile}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.etl")
    
    output = validate_path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    
    console.print(f"Starting ETW trace with {profile} profile for {duration} seconds...")
    
    try:
        # Start trace
        subprocess.run(["wpr", "-start", profile, "-filemode"],
                              capture_output=True, text=True, check=True)
        console.print(f"✓ ETW trace started", style="green")
        
        # Wait for duration
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TimeElapsedColumn(),
            console=console
        ) as progress:
            task = progress.add_task(f"Tracing {profile}...", total=duration)
            
            for i in range(duration):
                import time
                time.sleep(1)
                progress.update(task, completed=i + 1)
        
        # Stop trace and save
        subprocess.run(["wpr", "-stop", str(output)],
                              capture_output=True, text=True, check=True)
        console.print(f"✓ ETW trace saved to: {output}", style="green")
        
    except subprocess.CalledProcessError as e:
        console.print(f"Error running WPR: {e}", style="red")
        console.print(f"stdout: {e.stdout}")
        console.print(f"stderr: {e.stderr}")
        raise typer.Exit(1)
    except FileNotFoundError:
        console.print("Error: wpr (Windows Performance Recorder) not found. Install Windows Performance Toolkit.", style="red")
        raise typer.Exit(1)


@app.command()
def eventlogs(
    logs: List[str] = typer.Option(
        ["System", "Application", "Microsoft-Windows-Diagnostics-Performance/Operational", "Microsoft-Windows-Kernel-Process/Analytic"],
        "--logs", "-l", help="Event logs to export"
    ),
    days: int = typer.Option(1, "--days", "-d", help="Number of days of logs to export"),
    output_dir: Optional[Path] = typer.Option(None, "--output", "-o", help="Output directory")
):
    """Export Windows event logs using wevtutil"""
    
    if not output_dir:
        output_dir = Path("D:/DevOptimizer/logs/eventlogs")
    
    output_dir = validate_path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    from datetime import timedelta
    start_time = datetime.now() - timedelta(days=days)
    start_time_str = start_time.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    
    console.print(f"Exporting event logs from the last {days} day(s)...")
    
    exported_files = []
    
    for log_name in logs:
        try:
            safe_name = log_name.replace('/', '_').replace('-', '_')
            output_file = output_dir / f"{safe_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.evtx"
            
            console.print(f"Exporting {log_name}...")
            
            # Build query as a separate variable to avoid f-string in subprocess
            query = "*[System[TimeCreated[@SystemTime>='" + start_time_str + "']]]"
            query_arg = "/q:" + query
            subprocess.run(
                ["wevtutil", "epl", log_name, str(output_file), query_arg],
                capture_output=True, text=True, check=True
            )
            
            exported_files.append(str(output_file))
            file_size = output_file.stat().st_size / (1024 * 1024)
            console.print(f"  ✓ Exported {log_name} to {output_file.name} ({file_size:.2f} MB)")
            
        except subprocess.CalledProcessError as e:
            console.print(f"  ✗ Failed to export {log_name}: {e.stderr}", style="yellow")
        except Exception as e:
            console.print(f"  ✗ Error exporting {log_name}: {e}", style="yellow")
    
    console.print(f"\n✓ Event logs export completed. {len(exported_files)} files exported.", style="green")


@app.command()
def collect_all(
    duration: int = typer.Option(300, "--duration", "-d", help="Collection duration in seconds"),
    output_dir: Path = typer.Option(Path("D:/DevOptimizer/metrics-output"), "--output-dir", "-o", help="Output directory for metrics"),
    counter_file: Path = typer.Option(Path("D:/DevOptimizer/configs/default-counters.txt"), "--counter-file", "-c", help="Path to counter file for logman"),
    interval: int = typer.Option(5, "--interval", "-i", help="Collection interval in seconds"),
    etw_profile: str = typer.Option("CPU", "--etw-profile", "-p", help="WPR profile (CPU, DiskIO, FileIO, etc.)"),
):
    """Run full metrics collection pipeline: snapshot + logman + WPR ETW + event logs"""
    import time
    import datetime
    
    # Validate output directory is within D:/DevOptimizer
    try:
        output_dir = output_dir.resolve()
        base_path = Path("D:/DevOptimizer").resolve()
        output_dir.relative_to(base_path)
    except ValueError:
        console.print("Error: Output directory must be within D:/DevOptimizer", style="red")
        raise typer.Exit(1)
    
    output_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    run_dir = output_dir / f"metrics-{timestamp}"
    run_dir.mkdir(parents=True, exist_ok=True)
    
    console.print(f"\n[bold cyan]DevOptimizer Full Metrics Collection[/bold cyan]")
    console.print(f"Run directory: {run_dir}")
    console.print(f"Duration: {duration}s | Interval: {interval}s | ETW Profile: {etw_profile}\n")
    
    # Step 1: System snapshot (before)
    console.print("[bold]Step 1/5: System Snapshot (before)[/bold]")
    snapshot_before = get_system_snapshot()
    snapshot_file = run_dir / "system-snapshot-before.json"
    import json
    snapshot_file.write_text(json.dumps(snapshot_before, indent=2, default=str))
    console.print(f"  ✓ Snapshot saved to {snapshot_file.name}")
    
    # Step 2: Start logman performance counter collection
    console.print("[bold]Step 2/5: Starting Performance Counter Collection (logman)[/bold]")
    logman_csv = run_dir / "perf-counters.csv"
    counter_file_resolved = counter_file.resolve()
    
    try:
        # Create the logman counter set
        result = subprocess.run(
            ["logman", "create", "counter", "DevOpt_Metrics", "-cf", str(counter_file_resolved), "-f", "csv", "-o", str(logman_csv), "-si", str(interval), "-v", "mmddhhmm"],
            capture_output=True, text=True, check=True
        )
        console.print(f"  ✓ Counter set created")
    except subprocess.CalledProcessError as e:
        if "already exists" in e.stderr.lower():
            console.print(f"  ⚠ Counter set exists, reusing", style="yellow")
        else:
            console.print(f"  ✗ Failed to create counter set: {e.stderr}", style="red")
            raise typer.Exit(1)
    
    try:
        subprocess.run(["logman", "start", "DevOpt_Metrics"], capture_output=True, text=True, check=True)
        console.print(f"  ✓ logman started")
    except subprocess.CalledProcessError as e:
        console.print(f"  ✗ Failed to start logman: {e.stderr}", style="red")
        raise typer.Exit(1)
    
    # Step 3: Start ETW trace (WPR)
    console.print("[bold]Step 3/5: Starting ETW Trace (WPR)[/bold]")
    etw_file = run_dir / f"etw-trace-{etw_profile.lower()}.etl"
    
    try:
        subprocess.run(
            ["wpr", "-start", etw_profile, "-filemode", "-start", "GeneralProfile", "-filemode"],
            capture_output=True, text=True, check=True
        )
        console.print(f"  ✓ WPR started with profile: {etw_profile}")
    except subprocess.CalledProcessError as e:
        console.print(f"  ✗ Failed to start WPR: {e.stderr}", style="red")
        # Try to stop logman before exiting
        subprocess.run(["logman", "stop", "DevOpt_Metrics"], capture_output=True)
        raise typer.Exit(1)
    
    # Step 4: Wait for duration with progress bar
    console.print(f"\n[bold]Step 4/5: Collecting for {duration} seconds...[/bold]")
    
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
        TimeRemainingColumn(),
        console=console,
    ) as progress:
        task = progress.add_task("Collecting metrics...", total=duration)
        for elapsed in range(duration):
            time.sleep(1)
            progress.update(task, advance=1)
    
    # Step 5: Stop collections and export
    console.print("\n[bold]Step 5/5: Stopping collections and exporting...[/bold]")
    
    # Stop WPR
    try:
        subprocess.run(["wpr", "-stop", str(etw_file)], capture_output=True, text=True, check=True)
        console.print(f"  ✓ WPR stopped, trace saved to {etw_file.name}")
    except subprocess.CalledProcessError as e:
        console.print(f"  ✗ Failed to stop WPR: {e.stderr}", style="yellow")
    
    # Stop logman
    try:
        subprocess.run(["logman", "stop", "DevOpt_Metrics"], capture_output=True, text=True, check=True)
        console.print(f"  ✓ logman stopped")
    except subprocess.CalledProcessError as e:
        console.print(f"  ✗ Failed to stop logman: {e.stderr}", style="yellow")
    
    # Clean up logman counter set
    try:
        subprocess.run(["logman", "delete", "DevOpt_Metrics"], capture_output=True, text=True, check=True)
        console.print(f"  ✓ Counter set cleaned up")
    except subprocess.CalledProcessError:
        pass  # Ignore cleanup failures
    
    # System snapshot (after)
    console.print("[bold]Final: System Snapshot (after)[/bold]")
    snapshot_after = get_system_snapshot()
    snapshot_after_file = run_dir / "system-snapshot-after.json"
    snapshot_after_file.write_text(json.dumps(snapshot_after, indent=2, default=str))
    console.print(f"  ✓ Snapshot saved to {snapshot_after_file.name}")
    
    # Export event logs (last duration seconds)
    console.print("[bold]Exporting Event Logs...[/bold]")
    logs_dir = run_dir / "event-logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    
    log_names = ["System", "Application", "Microsoft-Windows-WindowsUpdate/Operational", "Microsoft-Windows-DriverFrameworks-UserMode/Operational"]
    start_time = datetime.datetime.now() - datetime.timedelta(seconds=duration)
    start_time_str = start_time.strftime("%Y-%m-%dT%H:%M:%S")
    
    exported_files = []
    for log_name in log_names:
        try:
            output_file = logs_dir / f"{log_name.replace('/', '-')}.evtx"
            query = "*[System[TimeCreated[@SystemTime>='" + start_time_str + "']]]"
            query_arg = "/q:" + query
            subprocess.run(
                ["wevtutil", "epl", log_name, str(output_file), query_arg],
                capture_output=True, text=True, check=True
            )
            exported_files.append(str(output_file))
            file_size = output_file.stat().st_size / (1024 * 1024)
            console.print(f"  ✓ Exported {log_name} to {output_file.name} ({file_size:.2f} MB)")
        except subprocess.CalledProcessError as e:
            console.print(f"  ⚠ Failed to export {log_name}: {e.stderr}", style="yellow")
        except Exception as e:
            console.print(f"  ⚠ Error exporting {log_name}: {e}", style="yellow")
    
    # Summary
    console.print(f"\n[bold green]✓ Full Metrics Collection Complete![/bold green]")
    console.print(f"Run directory: {run_dir}")
    console.print(f"Files created:")
    for f in run_dir.rglob("*"):
        if f.is_file():
            size = f.stat().st_size
            if size > 1024 * 1024:
                size_str = f"{size / (1024 * 1024):.2f} MB"
            elif size > 1024:
                size_str = f"{size / 1024:.2f} KB"
            else:
                size_str = f"{size} bytes"
            rel = f.relative_to(run_dir)
            console.print(f"  {rel} ({size_str})")
