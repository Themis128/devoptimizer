"""
Metrics collection commands
"""

import json
import psutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeElapsedColumn

app = typer.Typer(name="metrics", help="Performance metrics collection")
console = Console()

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
        with open(output, 'w') as f:
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

        with open(counter_file, 'w') as f:
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
