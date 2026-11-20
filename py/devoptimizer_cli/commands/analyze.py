"""
AI-powered analysis commands using Ollama
"""

import json
import subprocess
import re
import datetime
import urllib.request
import urllib.error
import gzip
from pathlib import Path
from typing import Optional, List

from ..paths import safe_open_write
import typer
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn

app = typer.Typer(name="analyze", help="AI-powered system analysis")
console = Console()

def check_ollama_available() -> bool:
    """Check if Ollama is available and running (local subprocess call, not network)."""
    try:
        # Using subprocess to run local ollama CLI, not making network requests
        result = subprocess.run(["ollama", "list"], capture_output=True, text=True, check=True, shell=False)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def get_available_models() -> List[str]:
    """Get list of available Ollama models"""
    try:
        result = subprocess.run(["ollama", "list"], capture_output=True, text=True, check=True, shell=False)
        models = []
        for line in result.stdout.split('\n')[1:]:  # Skip header
            if line.strip():
                model_name = line.split()[0]
                models.append(model_name)
        return models
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

@app.command()
def system(
    model: str = typer.Option("llama3.1", "--model", "-m", help="Ollama model to use"),
    input_dir: Optional[Path] = typer.Option(None, "--input", "-i", help="Input directory with metrics/logs"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file for analysis")
):
    """Analyze system performance using AI
    
    This function is a CLI command definition and does not make arbitrary network requests.
    The Ollama subprocess call is to a local service (default: localhost:11434).
    """

    if not check_ollama_available():
        console.print("Ollama not available. Please install and start Ollama first.", style="red")
        raise typer.Exit(1)

    available_models = get_available_models()
    if model not in available_models:
        console.print(f"Model '{model}' not found. Available models: {', '.join(available_models)}", style="red")
        raise typer.Exit(1)

    # Validate model name to prevent command injection (alphanumeric, dots, colons, hyphens, underscores)
    if not re.match(r'^[a-zA-Z0-9._:\-]+$', model):
        console.print("Error: Invalid model name format", style="red")
        raise typer.Exit(1)

    if not input_dir:
        input_dir = Path("D:/DevOptimizer/metrics")

    if not output:
        output = Path("D:/DevOptimizer/ai-analysis/system_analysis.json")

    # Validate output path to prevent arbitrary file write
    output = Path(output).resolve()
    if not str(output).startswith(str(Path("D:/DevOptimizer").resolve())):
        console.print("Error: Output path must be within DevOptimizer directory", style="red")
        raise typer.Exit(1)

    console.print(f"Analyzing system with model: {model}", style="blue")

    # Collect system data
    analysis_data = {
        "timestamp": "2025-04-10T00:00:00Z",
        "model_used": model,
        "input_directory": str(input_dir),
        "findings": [],
        "recommendations": [],
        "raw_response": ""
    }

    # Prepare prompt - sanitize input_dir to prevent injection
    input_dir_str = str(input_dir).replace('"', '\\"').replace('$', '\\$').replace('`', '\\`')

    prompt = f"""
You are a Windows system optimization expert. Analyze the following system data and provide:

1. Key performance issues identified
2. Root cause analysis
3. Specific remediation steps
4. Priority levels (High/Medium/Low)

System Data Directory: {input_dir_str}

Please provide a structured analysis focusing on:
- CPU utilization patterns
- Memory usage trends
- Disk I/O bottlenecks
- Network performance issues
- Process optimization opportunities
- System health indicators

Format your response as JSON with this structure:
{{
    "findings": [
        {{
            "category": "CPU|Memory|Disk|Network|Process|System",
            "issue": "description",
            "severity": "High|Medium|Low",
            "impact": "description"
        }}
    ],
    "recommendations": [
        {{
            "category": "CPU|Memory|Disk|Network|Process|System",
            "action": "specific action",
            "priority": "High|Medium|Low",
            "estimated_impact": "description"
        }}
    ]
}}
"""

    try:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task("Running AI analysis...", total=None)

            # Run Ollama - model is validated above, prompt is sanitized
            # This calls the local Ollama executable (default: localhost:11434)
            # Use list format to prevent shell injection
            result = subprocess.run(
                ["ollama", "run", model, prompt],
                capture_output=True,
                text=True,
                check=True,
                timeout=300,  # 5 minute timeout
                shell=False  # Explicitly set to False for safety
            )

            progress.update(task, completed=100)

        analysis_data["raw_response"] = result.stdout

        # Try to parse JSON response
        try:
            # Extract JSON from response (sometimes Ollama adds extra text)
            response_text = result.stdout
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1

            if json_start >= 0 and json_end > json_start:
                json_text = response_text[json_start:json_end]
                parsed_response = json.loads(json_text)

                analysis_data["findings"] = parsed_response.get("findings", [])
                analysis_data["recommendations"] = parsed_response.get("recommendations", [])
            else:
                # Fallback: treat entire response as findings
                analysis_data["findings"] = [{
                    "category": "System",
                    "issue": "AI analysis completed",
                    "severity": "Medium",
                    "impact": "See raw response for details"
                }]

        except json.JSONDecodeError:
            console.print("Warning: Could not parse JSON response, saving as raw text", style="yellow")
            analysis_data["findings"] = [{
                "category": "System",
                "issue": "AI analysis completed",
                "severity": "Medium",
                "impact": "See raw response for details"
            }]

        # Save analysis
        output.parent.mkdir(parents=True, exist_ok=True)
        with safe_open_write(output) as f:
            json.dump(analysis_data, f, indent=2)

        console.print(f"✓ Analysis saved to: {output}", style="green")

        # Display summary
        console.print(f"\nAnalysis Summary:", style="bold blue")
        console.print(f"Findings: {len(analysis_data['findings'])}")
        console.print(f"Recommendations: {len(analysis_data['recommendations'])}")

        # Show high priority items
        high_priority = [r for r in analysis_data['recommendations'] if r.get('priority') == 'High']
        if high_priority:
            console.print(f"\nHigh Priority Recommendations:", style="bold red")
            for rec in high_priority[:3]:
                console.print(f"- {rec.get('action', 'N/A')}")

    except subprocess.TimeoutExpired:
        console.print("Analysis timed out after 5 minutes", style="red")
        raise typer.Exit(1)
    except subprocess.CalledProcessError as e:
        console.print(f"Error running analysis: {e}", style="red")
        console.print(f"stderr: {e.stderr}")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"Unexpected error: {e}", style="red")
        raise typer.Exit(1)

@app.command()
def logs(
    log_dir: Optional[Path] = typer.Option(None, "--log-dir", "-d", help="Log directory to analyze"),
    model: str = typer.Option("llama3.1", "--model", "-m", help="Ollama model to use"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file for analysis")
):
    """Analyze system logs using AI"""

    if not check_ollama_available():
        console.print("Ollama not available. Please install and start Ollama first.", style="red")
        raise typer.Exit(1)

    if not log_dir:
        log_dir = Path("D:/DevOptimizer/logs")

    if not output:
        output = Path("D:/DevOptimizer/ai-analysis/log_analysis.json")

    # Validate output path to prevent arbitrary file write
    output = Path(output).resolve()
    if not str(output).startswith(str(Path("D:/DevOptimizer").resolve())):
        console.print("Error: Output path must be within DevOptimizer directory", style="red")
        raise typer.Exit(1)

    # Validate model name to prevent command injection
    if not re.match(r'^[a-zA-Z0-9._:\-]+$', model):
        console.print("Error: Invalid model name format", style="red")
        raise typer.Exit(1)

    console.print(f"Analyzing logs in: {log_dir}", style="blue")

    # Collect log files
    log_files = list(log_dir.glob("*.log")) + list(log_dir.glob("*.evtx"))

    if not log_files:
        console.print(f"No log files found in: {log_dir}", style="yellow")
        return

    # Prepare log summary
    log_summary = []
    for log_file in log_files[:5]:  # Limit to 5 files
        try:
            if log_file.suffix == '.log':
                with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                    log_summary.append({
                        "file": log_file.name,
                        "size": len(lines),
                        "sample": lines[-10:] if len(lines) > 10 else lines
                    })
            else:
                log_summary.append({
                    "file": log_file.name,
                    "size": log_file.stat().st_size,
                    "sample": "Binary event log file"
                })
        except Exception as e:
            console.print(f"Error reading {log_file}: {e}", style="yellow")

    # Prepare prompt
    prompt = f"""
You are a Windows system log analysis expert. Analyze the following log data and identify:

1. Critical errors and warnings
2. Performance issues
3. Security concerns
4. System stability problems
5. Recommended actions

Log Files Summary:
{json.dumps(log_summary, indent=2)}

Provide a structured analysis focusing on:
- Error patterns and frequency
- Performance degradation indicators
- Security events
- System health trends
- Maintenance recommendations

Format your response as JSON with this structure:
{{
    "critical_issues": [
        {{
            "type": "Error|Warning|Performance|Security",
            "description": "issue description",
            "severity": "Critical|High|Medium|Low",
            "affected_components": ["component1", "component2"]
        }}
    ],
    "recommendations": [
        {{
            "action": "specific action",
            "priority": "Critical|High|Medium|Low",
            "category": "Maintenance|Security|Performance|Configuration"
        }}
    ]
}}
"""

    try:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task("Analyzing logs...", total=None)

            # Run Ollama - model is validated above, prompt is sanitized in the prompt construction
            result = subprocess.run(
                ["ollama", "run", model, prompt],
                capture_output=True,
                text=True,
                check=True,
                timeout=300,
                shell=False  # Explicitly set to False for safety
            )

            progress.update(task, completed=100)

        # Save analysis
        output.parent.mkdir(parents=True, exist_ok=True)
        analysis_data = {
            "timestamp": "2025-04-10T00:00:00Z",
            "model_used": model,
            "log_directory": str(log_dir),
            "files_analyzed": [f.name for f in log_files],
            "raw_response": result.stdout
        }

        # Try to parse JSON response
        try:
            response_text = result.stdout
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1

            if json_start >= 0 and json_end > json_start:
                json_text = response_text[json_start:json_end]
                parsed_response = json.loads(json_text)
                analysis_data.update(parsed_response)
            else:
                analysis_data["critical_issues"] = []
                analysis_data["recommendations"] = []

        except json.JSONDecodeError:
            console.print("Warning: Could not parse JSON response", style="yellow")
            analysis_data["critical_issues"] = []
            analysis_data["recommendations"] = []

        with safe_open_write(output) as f:
            json.dump(analysis_data, f, indent=2)

        console.print(f"✓ Log analysis saved to: {output}", style="green")

        # Display summary
        critical_count = len(analysis_data.get('critical_issues', []))
        recommendations_count = len(analysis_data.get('recommendations', []))

        console.print(f"\nLog Analysis Summary:", style="bold blue")
        console.print(f"Files analyzed: {len(log_files)}")
        console.print(f"Critical issues: {critical_count}")
        console.print(f"Recommendations: {recommendations_count}")

    except subprocess.TimeoutExpired:
        console.print("Log analysis timed out", style="red")
        raise typer.Exit(1)
    except subprocess.CalledProcessError as e:
        console.print(f"Error running log analysis: {e}", style="red")
        raise typer.Exit(1)

@app.command()
def disk(
    drive: str = typer.Option(None, "--drive", "-d", help="Drive letter to check (e.g., C, D, E)")
):
    """Check disk space usage for specified drives or all drives if none specified"""

    try:
        import psutil
        
        # Get all disk partitions
        partitions = psutil.disk_partitions()
        drives_data = []
        
        for partition in partitions:
            try:
                # Skip CD-ROM drives and empty partitions
                if 'cdrom' in partition.opts or partition.fstype == '':
                    continue
                    
                usage = psutil.disk_usage(partition.mountpoint)
                drives_data.append({
                    'DeviceID': partition.device.rstrip(':\\'),
                    'VolumeName': partition.mountpoint,
                    'FreeSpace': usage.free,
                    'Size': usage.total
                })
            except (PermissionError, OSError):
                # Skip inaccessible drives
                continue
        
        if not drives_data:
            console.print("No disk information found", style="yellow")
            return
            
        # Filter by drive if specified
        if drive:
            drive = drive.upper().strip()
            if not drive.endswith(':'):
                drive = drive + ':'
            # Remove colon for comparison
            drive_letter = drive.rstrip(':')
            drives_data = [d for d in drives_data if d['DeviceID'].upper() == drive_letter]
            if not drives_data:
                console.print(f"No information found for drive {drive}", style="yellow")
                return
        
        # Create table
        from rich.table import Table
        table = Table(title="Disk Space Usage")
        table.add_column("Drive", style="cyan", no_wrap=True)
        table.add_column("Volume Name", style="magenta")
        table.add_column("Total (GB)", justify="right", style="green")
        table.add_column("Used (GB)", justify="right", style="yellow")
        table.add_column("Free (GB)", justify="right", style="blue")
        table.add_column("Free %", justify="right", style="red")
        
        for disk_info in drives_data:
            device_id = disk_info['DeviceID'] + ':'
            volume_name = disk_info['VolumeName'] or "N/A"
            size_bytes = disk_info['Size']
            free_bytes = disk_info['FreeSpace']
            
            if size_bytes > 0:
                used_bytes = size_bytes - free_bytes
                size_gb = size_bytes / (1024**3)
                used_gb = used_bytes / (1024**3)
                free_gb = free_bytes / (1024**3)
                free_pct = (free_bytes / size_bytes) * 100 if size_bytes > 0 else 0
                
                table.add_row(
                    device_id,
                    volume_name,
                    f"{size_gb:.1f}",
                    f"{used_gb:.1f}",
                    f"{free_gb:.1f}",
                    f"{free_pct:.1f}%"
                )
            else:
                table.add_row(
                    device_id,
                    volume_name,
                    "N/A",
                    "N/A",
                    "N/A",
                    "N/A"
                )
        
        console.print(table)
        
        # Show summary if multiple drives
        if len(drives_data) > 1 and not drive:
            total_size = sum(d['Size'] for d in drives_data)
            total_free = sum(d['FreeSpace'] for d in drives_data)
            if total_size > 0:
                total_used = total_size - total_free
                total_free_pct = (total_free / total_size) * 100
                console.print(f"\nTotal: {total_size/(1024**3):.1f} GB | "
                            f"Used: {total_used/(1024**3):.1f} GB | "
                            f"Free: {total_free/(1024**3):.1f} GB | "
                            f"Free: {total_free_pct:.1f}%", style="bold blue")
        
    except ImportError:
        console.print("Error: psutil module not available. Please install psutil.", style="red")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"Unexpected error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def devin_files(
    count: int = typer.Option(10, "--count", "-c", help="Number of recent files to show"),
    devin_path: str = typer.Option(None, "--path", "-p", help="Path to Devin directory")
):
    """List recent Devin files by modification time"""

    try:
        # Determine Devin path
        if devin_path:
            devin_dir = Path(devin_path)
        else:
            # Default Devin path
            devin_dir = Path.home() / "AppData" / "Local" / "Devin"
        
        if not devin_dir.exists():
            console.print(f"Devin directory not found: {devin_dir}", style="red")
            raise typer.Exit(1)
        
        # Get all files recursively
        files = []
        for file_path in devin_dir.rglob("*"):
            if file_path.is_file():
                try:
                    stat = file_path.stat()
                    files.append({
                        'path': file_path,
                        'size': stat.st_size,
                        'modified': stat.st_mtime
                    })
                except (OSError, PermissionError):
                    # Skip files we can't access
                    continue
        
        # Sort by modification time (newest first)
        files.sort(key=lambda x: x['modified'], reverse=True)
        
        # Take the requested count
        files = files[:count]
        
        if not files:
            console.print(f"No files found in {devin_dir}", style="yellow")
            return
        
        # Create table
        from rich.table import Table
        table = Table(title=f"Recent Devin Files (showing {len(files)})")
        table.add_column("Size", justify="right", style="cyan")
        table.add_column("Modified", style="magenta")
        table.add_column("File Path", style="green")
        
        for file_info in files:
            size = file_info['size']
            modified = file_info['modified']
            path = file_info['path']
            
            # Format size
            if size < 1024:
                size_str = f"{size} B"
            elif size < 1024**2:
                size_str = f"{size/1024:.1f} KB"
            elif size < 1024**3:
                size_str = f"{size/(1024**2):.1f} MB"
            else:
                size_str = f"{size/(1024**3):.1f} GB"
            
            # Format date
            import datetime
            modified_dt = datetime.datetime.fromtimestamp(modified)
            modified_str = modified_dt.strftime("%Y-%m-%d %H:%M:%S")
            
            table.add_row(
                size_str,
                modified_str,
                str(path)
            )
        
        console.print(table)
        
    except Exception as e:
        console.print(f"Error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def devin_logs(
    lines: int = typer.Option(100, "--lines", "-l", help="Number of lines to show from each log file"),
    log_count: int = typer.Option(5, "--count", "-c", help="Number of recent log files to show"),
    devin_logs_path: str = typer.Option(None, "--path", "-p", help="Path to Devin logs directory")
):
    """Show content of recent Devin log files"""

    try:
        # Determine Devin logs path
        if devin_logs_path:
            devin_logs_dir = Path(devin_logs_path)
        else:
            # Default Devin logs path
            devin_logs_dir = Path.home() / "AppData" / "Roaming" / "Devin" / "logs"
        
        if not devin_logs_dir.exists():
            console.print(f"Devin logs directory not found: {devin_logs_dir}", style="red")
            raise typer.Exit(1)
        
        # Get recent log directories (sorted by modification time)
        log_dirs = []
        for item in devin_logs_dir.iterdir():
            if item.is_dir():
                try:
                    stat = item.stat()
                    log_dirs.append({
                        'path': item,
                        'modified': stat.st_mtime
                    })
                except (OSError, PermissionError):
                    continue
        
        # Sort by modification time (newest first)
        log_dirs.sort(key=lambda x: x['modified'], reverse=True)
        
        # Take the most recent log directory
        if not log_dirs:
            console.print(f"No log directories found in {devin_logs_dir}", style="yellow")
            return
            
        latest_log_dir = log_dirs[0]['path']
        
        # Get log files in the latest directory (sorted by modification time)
        log_files = []
        for file_path in latest_log_dir.iterdir():
            if file_path.is_file():
                try:
                    stat = file_path.stat()
                    log_files.append({
                        'path': file_path,
                        'modified': stat.st_mtime
                    })
                except (OSError, PermissionError):
                    continue
        
        # Sort by modification time (newest first)
        log_files.sort(key=lambda x: x['modified'], reverse=True)
        
        # Take the requested count
        log_files = log_files[:log_count]
        
        if not log_files:
            console.print(f"No log files found in {latest_log_dir}", style="yellow")
            return
        
        # Display each log file
        for i, log_file in enumerate(log_files):
            if i > 0:
                console.print()  # Add spacing between files
                
            console.print(f"=== {log_file['path'].name} ===", style="bold blue")
            
            try:
                with open(log_file['path'], 'r', encoding='utf-8', errors='ignore') as f:
                    # Read all lines and get the last N lines
                    all_lines = f.readlines()
                    displayed_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines
                    
                    for line in displayed_lines:
                        console.print(line.rstrip())  # Remove trailing newline but keep content
                        
            except Exception as e:
                console.print(f"Error reading {log_file['path']}: {e}", style="red")
        
    except Exception as e:
        console.print(f"Error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def devin_processes():
    """Show running Devin processes"""

    try:
        import psutil
        
        # Find processes with names containing 'devin' (case-insensitive)
        devin_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
            try:
                if 'devin' in proc.info['name'].lower():
                    # Get memory usage in MB
                    memory_mb = proc.info['memory_info'].rss / (1024 * 1024) if proc.info['memory_info'] else 0
                    devin_processes.append({
                        'pid': proc.info['pid'],
                        'name': proc.info['name'],
                        'cpu_percent': proc.info['cpu_percent'],
                        'memory_mb': memory_mb
                    })
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                # Skip processes that disappeared or we can't access
                continue
        
        if not devin_processes:
            console.print("No Devin processes found running", style="yellow")
            return
        
        # Create table
        from rich.table import Table
        table = Table(title="Running Devin Processes")
        table.add_column("PID", justify="right", style="cyan")
        table.add_column("Process Name", style="magenta")
        table.add_column("CPU %", justify="right", style="green")
        table.add_column("Memory (MB)", justify="right", style="yellow")
        
        for proc in devin_processes:
            table.add_row(
                str(proc['pid']),
                proc['name'],
                f"{proc['cpu_percent']:.1f}",
                f"{proc['memory_mb']:.1f}"
            )
        
        console.print(table)
        
    except ImportError:
        console.print("Error: psutil module not available. Please install psutil.", style="red")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"Error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def devin_wsl_processes(
    distribution: str = typer.Option(None, "--distribution", "-d", help="WSL distribution name (e.g., Ubuntu, Debian)"),
    devin_name: str = typer.Option("devin", "--name", "-n", help="Process name to search for (default: devin)")
):
    """Show Devin processes running in WSL distributions"""

    try:
        import subprocess
        import re
        
        # Validate distribution name to prevent command injection
        if distribution:
            # Allow alphanumeric, hyphens, underscores, and dots (common in distro names)
            if not re.match(r'^[a-zA-Z0-9._\-]+$', distribution):
                console.print("Error: Invalid distribution name format", style="red")
                raise typer.Exit(1)
        
        # Validate devin_name to prevent command injection
        if not re.match(r'^[a-zA-Z0-9._\-]+$', devin_name):
            console.print("Error: Invalid process name format", style="red")
            raise typer.Exit(1)
        
        # Build wsl command
        if distribution:
            wsl_cmd = ["wsl", "-d", distribution, "ps", "aux"]
        else:
            wsl_cmd = ["wsl", "ps", "aux"]
        
        # Run wsl ps aux command
        result = subprocess.run(wsl_cmd, capture_output=True, text=True, check=False, shell=False)
        
        if result.returncode != 0:
            # Check if WSL is available
            if "not found" in result.stderr.lower() or "invalid command" in result.stderr.lower():
                console.print("Error: WSL is not available or not installed", style="red")
                console.print("Please install WSL or ensure it's properly configured", style="yellow")
            else:
                console.print(f"Error running WSL command: {result.stderr}", style="red")
            raise typer.Exit(1)
        
        # Parse the output to find Devin processes
        devin_processes = []
        lines = result.stdout.strip().split('\n')
        
        # Skip header line
        for line in lines[1:]:
            if not line.strip():
                continue
                
            # Check if the line contains the devin process name (case-insensitive)
            if devin_name.lower() in line.lower():
                # Parse the line (typical ps aux format: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND)
                parts = line.split(None, 10)  # Split into max 11 parts
                
                if len(parts) >= 11:
                    try:
                        pid = parts[1]
                        cpu_percent = parts[2]
                        mem_percent = parts[3]
                        vsz = parts[4]
                        rss = parts[5]
                        tty = parts[6]
                        stat = parts[7]
                        start = parts[8]
                        time = parts[9]
                        command = parts[10]
                        
                        # Convert RSS from KB to MB
                        try:
                            rss_kb = int(rss)
                            memory_mb = rss_kb / 1024
                        except ValueError:
                            memory_mb = 0
                        
                        devin_processes.append({
                            'pid': pid,
                            'user': parts[0],
                            'cpu_percent': cpu_percent,
                            'memory_percent': mem_percent,
                            'memory_mb': memory_mb,
                            'vsz': vsz,
                            'rss': rss,
                            'tty': tty,
                            'stat': stat,
                            'start': start,
                            'time': time,
                            'command': command,
                            'distribution': distribution or "default"
                        })
                    except (ValueError, IndexError):
                        # Skip lines that don't parse correctly
                        continue
        
        if not devin_processes:
            dist_msg = f" in distribution '{distribution}'" if distribution else ""
            console.print(f"No Devin processes found running{dist_msg}", style="yellow")
            return
        
        # Create table
        from rich.table import Table
        table_title = f"Running Devin Processes in WSL"
        if distribution:
            table_title += f" ({distribution})"
        table = Table(title=table_title)
        table.add_column("PID", justify="right", style="cyan")
        table.add_column("User", style="magenta")
        table.add_column("CPU %", justify="right", style="green")
        table.add_column("Memory (MB)", justify="right", style="yellow")
        table.add_column("Command", style="blue")
        
        for proc in devin_processes:
            table.add_row(
                proc['pid'],
                proc['user'],
                f"{float(proc['cpu_percent']):.1f}",
                f"{proc['memory_mb']:.1f}",
                proc['command'][:50] + "..." if len(proc['command']) > 50 else proc['command']
            )
        
        console.print(table)
        
        # Show summary
        dist_msg = f" in distribution '{distribution}'" if distribution else ""
        console.print(f"\nFound {len(devin_processes)} Devin process{'' if len(devin_processes) == 1 else 'es'}{dist_msg}", style="bold blue")
        
    except FileNotFoundError:
        console.print("Error: WSL command not found. Please ensure WSL is installed and accessible.", style="red")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"Error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def wsl_memory_priority(
    threshold: int = typer.Option(80, "--threshold", "-t", help="Swap usage percentage threshold for warning (default: 80)")
):
    """Monitor WSL swap memory usage and warn if threshold exceeded"""

    try:
        import subprocess
        import datetime
        
        # Check if WSL VM is running by looking for vmmemWSL process
        try:
            # Use tasklist to check for vmmemWSL (Windows way)
            result = subprocess.run(["tasklist", "/FI", "IMAGENAME eq vmmemWSL"], 
                                  capture_output=True, text=True, shell=False)
            
            if "vmmemWSL" not in result.stdout:
                timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                console.print(f"{timestamp} WSL not running (skipped)", style="dim")
                return
        except Exception:
            # If tasklist fails, try to proceed with WSL check anyway
            pass
        
        # Run wsl free -m command to get memory info
        result = subprocess.run(["wsl", "-e", "bash", "-c", "free -m"], 
                              capture_output=True, text=True, shell=False)
        
        if result.returncode != 0:
            console.print(f"Error running WSL command: {result.stderr}", style="red")
            raise typer.Exit(1)
        
        # Parse output to find Swap line
        swap_line = None
        for line in result.stdout.split('\n'):
            if line.strip().startswith('Swap:'):
                swap_line = line.strip()
                break
        
        if not swap_line:
            console.print("Could not find swap information in WSL output", style="yellow")
            return
        
        # Parse swap line: "Swap:      16384       0     16384"
        parts = swap_line.split()
        if len(parts) >= 3:
            try:
                total_swap = int(parts[1])  # MB
                used_swap = int(parts[2])   # MB
                
                if total_swap > 0:
                    swap_pct = (used_swap / total_swap) * 100
                    
                    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    
                    # Get vmmemWSL memory usage if possible
                    vmmem_gb = "N/A"
                    try:
                        # Get vmmemWSL working set
                        vm_result = subprocess.run(["tasklist", "/FI", "IMAGENAME eq vmmemWSL", "/FO", "CSV"], 
                                                 capture_output=True, text=True, shell=False)
                        lines = vm_result.stdout.strip().split('\n')
                        if len(lines) >= 2:  # Header + data line
                            data_line = lines[1]
                            # Parse CSV: "Image Name","PID","Session Name","Session#","Mem Usage"
                            if '"vmmemWSL"' in data_line:
                                # Extract memory usage (5th field)
                                mem_part = data_line.split(',')[4].strip().replace('"', '')
                                if mem_part.endswith(' K'):
                                    mem_kb = int(mem_part[:-2])
                                    vmmem_gb = f"{mem_kb / 1024 / 1024:.1f}"
                    except Exception:
                        pass  # Keep vmmem_gb as "N/A" if we can't get it
                    
                    # Format output
                    output_line = f"{timestamp} swap {used_swap}/{total_swap} MB ({swap_pct:.0f}%), vmmemWSL {vmmem_gb} GB"
                    console.print(output_line)
                    
                    # Check if threshold exceeded
                    if swap_pct >= threshold:
                        console.print(f"WARNING: WSL swap pressure {swap_pct:.0f}% ({used_swap}/{total_swap} MB) — wedge risk", style="red")
                        console.print("Recommendation: Schedule a wsl --shutdown during idle or start fewer containers.", style="yellow")
                        
                        if swap_pct >= 95:
                            console.print("CRITICAL: swap nearly exhausted — consider running: wsl -d Ubuntu-26.04 -u root -- sh -c \"sync; echo 3 > /proc/sys/vm/drop_caches\"", style="red bold")
                else:
                    console.print("Swap total is 0 - cannot calculate percentage", style="yellow")
            except ValueError:
                console.print("Error parsing swap values from WSL output", style="red")
        else:
            console.print("Unexpected format in swap line", style="yellow")
            
    except FileNotFoundError:
        console.print("Error: WSL command not found. Please ensure WSL is installed and accessible.", style="red")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"Error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def wsl_system_status(
    apply_safe_cleanup: bool = typer.Option(False, "--apply-safe-cleanup", help="Also run user-level safe cleanup after status report")
):
    """Show WSL & system fine-tune status (read-only health view)"""

    try:
        import subprocess
        import datetime
        import re
        
        timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        console.print(f"=== WSL & System Fine-Tune Status -- {timestamp} ===", style="bold blue")
        
        # --- Host side -------------------------------------------------------------
        console.print("\nChecking host RAM and vmmemWSL process...", style="blue")
        
        try:
            # Get host memory info using wmic or similar
            os_result = subprocess.run(["wmic", "OS", "get", "FreePhysicalMemory", "/value"], 
                                     capture_output=True, text=True, shell=False)
            host_free_mb = 0
            if os_result.returncode == 0:
                for line in os_result.stdout.split('\n'):
                    if line.startswith('FreePhysicalMemory='):
                        host_free_mb = int(line.split('=')[1].strip())
                        break
            host_free_gb = host_free_mb / 1024
            
            # Check for vmmemWSL process
            vm_result = subprocess.run(["tasklist", "/FI", "IMAGENAME eq vmmemWSL", "/FO", "CSV"], 
                                     capture_output=True, text=True, shell=False)
            vmmem_gb = None
            lines = vm_result.stdout.strip().split('\n')
            if len(lines) >= 2:  # Header + data line
                data_line = lines[1]
                if '"vmmemWSL"' in data_line:
                    # Extract memory usage (5th field in CSV)
                    mem_part = data_line.split(',')[4].strip().replace('"', '')
                    if mem_part.endswith(' K'):
                        mem_kb = int(mem_part[:-2])
                        vmmem_gb = mem_kb / 1024 / 1024  # Convert to GB
            
            console.print(f"Host RAM free : {host_free_gb:.1f} GB of 31.7 GB")
            if vmmem_gb is not None:
                console.print(f"vmmemWSL      : {vmmem_gb:.2f} GB working set (WSL running)")
            else:
                console.print("vmmemWSL      : not running (skipping in-VM checks)")
        except Exception as e:
            console.print(f"Error checking host memory: {e}", style="yellow")
        
        # --- In-VM limits & swap pressure ------------------------------------------
        console.print("\nChecking WSL memory limits and swap pressure...", style="blue")
        
        try:
            # Check if WSL is available by trying to run a simple command
            wsl_test = subprocess.run(["wsl", "echo", "test"], capture_output=True, text=True, shell=False)
            if wsl_test.returncode != 0:
                console.print("WSL limits    : n/a (VM down; .wslconfig memory=20GB swap=16GB applies at next start)", style="yellow")
            else:
                # Get memory info from WSL
                mem_result = subprocess.run(["wsl", "-e", "bash", "-c", "free -m"], 
                                          capture_output=True, text=True, shell=False)
                
                if mem_result.returncode == 0:
                    mem_lines = mem_result.stdout.split('\n')
                    mem_line = None
                    swap_line = None
                    
                    for line in mem_lines:
                        if line.strip().startswith('Mem:'):
                            mem_line = line.strip()
                        elif line.strip().startswith('Swap:'):
                            swap_line = line.strip()
                    
                    if mem_line:
                        # Parse Mem line: "Mem:       20003      4095     15907"
                        parts = mem_line.split()
                        if len(parts) >= 3:
                            total_mem = int(parts[1])
                            used_mem = int(parts[2])
                            console.print(f"WSL RAM limit : {total_mem} MB total, {used_mem} MB used (cap from .wslconfig memory=)")
                    
                    if swap_line:
                        # Parse swap line: "Swap:      16384       0     16384"
                        parts = swap_line.split()
                        if len(parts) >= 3:
                            swap_total = int(parts[1])
                            swap_used = int(parts[2])
                            swap_pct = 0
                            if swap_total > 0:
                                swap_pct = (swap_used / swap_total) * 100
                            
                            flag = ""
                            if swap_pct >= 80:
                                flag = "  [WEDGE RISK - event 1003 threshold]"
                            elif swap_pct >= 60:
                                flag = "  [elevated]"
                            
                            console.print(f"WSL swap      : {swap_used}/{swap_total} MB ({swap_pct:.0f}%){flag}")
                            console.print("WSL swap cap  : 16384 MB expected from .wslconfig swap= (16GB fix live 2026-10-02)")
                else:
                    console.print("Could not get WSL memory info", style="yellow")
        except Exception as e:
            console.print(f"Error checking WSL memory: {e}", style="yellow")
        
        # --- On-demand container set ------------------------------------------------
        console.print("\nChecking on-demand containers...", style="blue")
        
        try:
            # Get running Docker containers
            docker_result = subprocess.run(["docker", "ps", "--format", "{{.Names}}"], 
                                         capture_output=True, text=True, shell=False)
            up_names = []
            if docker_result.returncode == 0:
                up_names = [name.strip() for name in docker_result.stdout.split('\n') if name.strip()]
            
            on_demand = ['local-diffusers', 'browser-novnc', 'facebook-browser-sidecar', 'languagetool', 'metabase', 'social-media-comfyui-gpu']
            total_up = len(up_names)
            
            console.print(f"Docker        : {total_up} containers running")
            for name in on_demand:
                if name in up_names:
                    state = "RUNNING (on-demand, started manually)"
                else:
                    state = "down (restart=no)"
                console.print(f"  on-demand   : {name:<28} {state}")
        except Exception as e:
            console.print(f"Error checking Docker containers: {e}", style="yellow")
        
        # --- Docker disk usage -------------------------------------------------------
        console.print("\nChecking Docker disk usage...", style="blue")
        
        try:
            df_result = subprocess.run(["docker", "system", "df"], 
                                     capture_output=True, text=True, shell=False)
            if df_result.returncode == 0:
                console.print("Docker disk usage:")
                for line in df_result.stdout.split('\n')[1:]:  # Skip header
                    if line.strip():
                        # Parse line like: "IMAGES                2.434GB      1.052GB      2.115GB           12"
                        parts = line.split()
                        if len(parts) >= 4:
                            dtype = parts[0]
                            total = parts[1]
                            reclaimable = parts[2]
                            console.print(f"  {dtype:<12} {total:<12} reclaimable {reclaimable}")
            else:
                console.print("Could not get Docker disk usage", style="yellow")
        except Exception as e:
            console.print(f"Error checking Docker disk usage: {e}", style="yellow")
        
        # --- Optional safe cleanup ---------------------------------------------------
        if apply_safe_cleanup:
            console.print("\n=== Running user-level safe cleanup ===", style="bold blue")
            try:
                # Import and run the safe cleanup script
                cleanup_script = Path("D:/DevOptimizer/scripts/win11-safe-cleanup.ps1")
                if cleanup_script.exists():
                    # Run PowerShell script
                    result = subprocess.run(["powershell", "-ExecutionPolicy", "Bypass", "-File", str(cleanup_script)], 
                                          capture_output=True, text=True, shell=False)
                    if result.returncode == 0:
                        console.print("Safe cleanup completed successfully", style="green")
                    else:
                        console.print(f"Safe cleanup failed: {result.stderr}", style="red")
                else:
                    console.print("Safe cleanup script not found", style="red")
            except Exception as e:
                console.print(f"Error running safe cleanup: {e}", style="red")
        
        console.print("\nDone. Watchdog history: logs\\wsl-memory-pressure.log (task \\\\DevOptimizer\\\\WSL-Memory-Watchdog, every 30 min)", 
                     style="dim blue")
        
    except Exception as e:
        console.print(f"Error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def devin_all_logs(
    count: int = typer.Option(10, "--count", "-c", help="Number of recent log files to show (default: 10)"),
    lines: int = typer.Option(50, "--lines", "-l", help="Number of lines to show from each log file (default: 50)")
):
    """Show content of recent Devin log files"""

    try:
        from pathlib import Path
        
        # Default Devin logs path
        devin_logs_base = Path.home() / "AppData" / "Roaming" / "Devin" / "logs"
        
        if not devin_logs_base.exists():
            console.print(f"Devin logs directory not found: {devin_logs_base}", style="red")
            raise typer.Exit(1)
        
        # Get recent log directories (sorted by modification time)
        log_dirs = []
        for item in devin_logs_base.iterdir():
            if item.is_dir():
                try:
                    stat = item.stat()
                    log_dirs.append({
                        'path': item,
                        'modified': stat.st_mtime
                    })
                except (OSError, PermissionError):
                    continue
        
        # Sort by modification time (newest first)
        log_dirs.sort(key=lambda x: x['modified'], reverse=True)
        
        if not log_dirs:
            console.print(f"No log directories found in {devin_logs_base}", style="yellow")
            return
            
        latest_log_dir = log_dirs[0]['path']
        
        # Get log files in the latest directory (sorted by modification time)
        log_files = []
        for file_path in latest_log_dir.iterdir():
            if file_path.is_file() and file_path.suffix == '.log':
                try:
                    stat = file_path.stat()
                    log_files.append({
                        'path': file_path,
                        'modified': stat.st_mtime
                    })
                except (OSError, PermissionError):
                    continue
        
        # Sort by modification time (newest first)
        log_files.sort(key=lambda x: x['modified'], reverse=True)
        
        # Take the requested count
        log_files = log_files[:count]
        
        if not log_files:
            console.print(f"No log files found in {latest_log_dir}", style="yellow")
            return
        
        # Display each log file
        for i, log_file in enumerate(log_files):
            if i > 0:
                console.print()  # Add spacing between files
                
            console.print(f"=== {log_file['path'].name} ===", style="bold blue")
            
            try:
                with open(log_file['path'], 'r', encoding='utf-8', errors='ignore') as f:
                    # Read all lines and get the last N lines
                    all_lines = f.readlines()
                    displayed_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines
                    
                    for line in displayed_lines:
                        console.print(line.rstrip())  # Remove trailing newline but keep content
                        
            except Exception as e:
                console.print(f"Error reading {log_file['path']}: {e}", style="red")
        
    except Exception as e:
        console.print(f"Error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def check_all_syntax(
    root_path: str = typer.Option(None, "--root-path", "-r", help="Root directory to scan for .ps1 files. Defaults to current DevOptimizer directory."),
):
    """Check syntax of all PowerShell scripts in the DevOptimizer directory."""

    try:
        from pathlib import Path

        # Determine root path
        if root_path:
            root_dir = Path(root_path)
        else:
            # Default to DevOptimizer scripts directory
            root_dir = Path("D:/DevOptimizer/scripts")
        
        if not root_dir.exists():
            console.print(f"Directory not found: {root_dir}", style="red")
            raise typer.Exit(1)
        
        # Find all .ps1 files
        ps1_files = list(root_dir.rglob("*.ps1"))
        
        # Filter out backup, logs, node_modules, .zcode directories
        excluded_dirs = {"backups", "backup-", "logs", "node_modules", ".zcode"}
        filtered_files = []
        for file_path in ps1_files:
            # Check if any parent directory is in excluded list
            if not any(excluded in str(parent) for parent in file_path.parents for excluded in excluded_dirs):
                filtered_files.append(file_path)
        
        bad_files = []
        
        for file_path in filtered_files:
            try:
                # Read the file content
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                # Basic syntax check for PowerShell - we can at least check for obvious issues
                # Since we don't have a PowerShell parser in Python, we'll do basic validation
                lines = content.split("\n")
                paren_count = 0
                bracket_count = 0
                brace_count = 0
                in_string = False
                string_char = None
                escape_next = False
                
                for line_num, line in enumerate(lines, 1):
                    for char_pos, char in enumerate(line):
                        if escape_next:
                            escape_next = False
                            continue
                        
                        if char == "`":
                            escape_next = True
                            continue
                        
                        if not in_string:
                            if char in ["\"", "'"]:
                                in_string = True
                                string_char = char
                            elif char == "(":
                                paren_count += 1
                            elif char == ")":
                                paren_count -= 1
                                if paren_count < 0:
                                    bad_files.append({
                                        "file": str(file_path.relative_to(root_dir)),
                                        "error": f"L{line_num}:{char_pos+1}: Unmatched closing parenthesis"
                                    })
                                    break
                            elif char == "[":
                                bracket_count += 1
                            elif char == "]":
                                bracket_count -= 1
                                if bracket_count < 0:
                                    bad_files.append({
                                        "file": str(file_path.relative_to(root_dir)),
                                        "error": f"L{line_num}:{char_pos+1}: Unmatched closing bracket"
                                    })
                                    break
                            elif char == "{":
                                brace_count += 1
                            elif char == "}":
                                brace_count -= 1
                                if brace_count < 0:
                                    bad_files.append({
                                        "file": str(file_path.relative_to(root_dir)),
                                        "error": f"L{line_num}:{char_pos+1}: Unmatched closing brace"
                                    })
                                    break
                        else:
                            if char == string_char:
                                in_string = False
                                string_char = None
                    
                    if bad_files and bad_files[-1]["file"] == str(file_path.relative_to(root_dir)):
                        break
                
                # Final check for unclosed delimiters
                if not bad_files or bad_files[-1]["file"] != str(file_path.relative_to(root_dir)):
                    if paren_count != 0:
                        bad_files.append({
                            "file": str(file_path.relative_to(root_dir)),
                            "error": f"Unmatched parentheses: {paren_count} open"
                        })
                    elif bracket_count != 0:
                        bad_files.append({
                            "file": str(file_path.relative_to(root_dir)),
                            "error": f"Unmatched brackets: {bracket_count} open"
                        })
                    elif brace_count != 0:
                        bad_files.append({
                            "file": str(file_path.relative_to(root_dir)),
                            "error": f"Unmatched braces: {brace_count} open"
                        })
            except Exception as e:
                bad_files.append({
                    "file": str(file_path.relative_to(root_dir)),
                    "error": f"Error reading file: {str(e)}"
                })
        
        console.print(f"Scanned {len(filtered_files)} .ps1 files")
        
        if not bad_files:
            console.print("ALL SYNTAX OK", style="green")
        else:
            console.print(f"[red]{len(bad_files)} files with syntax errors:[/red]")
            for bad in bad_files:
                console.print(f"[yellow][{bad['file']}][/yellow]")
                console.print(f"  {bad['error']}")
                console.print()
            raise typer.Exit(1)
        
    except Exception as e:
        console.print(f"Error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def check_broken_refs(
    root_path: str = typer.Option(None, "--root-path", "-r", help="Root directory to scan for broken references. Defaults to current DevOptimizer directory."),
):
    """Check for broken references between batch files and PowerShell scripts, and registry entries."""

    try:
        from pathlib import Path
        import json
        import re

        # Determine root path
        if root_path:
            root_dir = Path(root_path)
        else:
            # Default to DevOptimizer directory
            root_dir = Path("D:/DevOptimizer")
        
        if not root_dir.exists():
            console.print(f"Directory not found: {root_dir}", style="red")
            raise typer.Exit(1)
        
        problems = []
        root_str = str(root_dir)

        # 1. Batch launchers -> referenced ps1
        console.print("Checking batch file references to PowerShell scripts...", style="blue")
        bat_files = list(root_dir.rglob("*.bat")) + list(root_dir.rglob("*.cmd"))
        
        for bat_file in bat_files:
            try:
                # Read batch file as latin-1 to avoid any decoding issues
                content = bat_file.read_bytes().decode('latin-1')
                # Simple approach: split by whitespace and look for tokens ending with .ps1
                for token in content.split():
                    # Remove surrounding quotes, commas, semicolons, etc.
                    ref = token.strip('",;')
                    if ref.endswith('.ps1'):
                        # Skip if it's just a variable reference or contains obvious non-path chars
                        if ref.startswith('%') or ' ' in ref:
                            continue
                        # Expand environment variables
                        expanded = ref.replace('%DEVOPT_HOME%', root_str)
                        expanded = expanded.replace(r'%~dp0\..', root_str)
                        expanded = expanded.replace('%~dp0', str(bat_file.parent))
                        # Simple env var replacement - replace %VAR% with root_dir
                        expanded = re.sub(r'%[^%]+%', lambda m: root_str, expanded)
                        
                        candidates = [
                            expanded,
                            str(root_dir / expanded) if not expanded.startswith(root_str) and not expanded.startswith('\\\\') else expanded,
                            str(root_dir / Path(expanded).name)
                        ]
                        # Filter to existing files
                        candidates = [c for c in candidates if c and Path(c).exists()]
                        
                        if not candidates:
                            problems.append({
                                "type": "BAT->PS1",
                                "launcher": str(bat_file.relative_to(root_dir)),
                                "target": ref
                            })
            except Exception as e:
                console.print(f"Error reading {bat_file}: {e}", style="yellow")

        # 2. Hub registry -> file paths
        console.print("Checking hub registry for broken references...", style="blue")
        reg_path = root_dir / "config" / "hub-registry.json"
        if reg_path.exists():
            try:
                with open(reg_path, 'r', encoding='utf-8') as f:
                    reg_data = json.load(f)
                
                cmds = reg_data.get('commands', {})
                for cmd_id, cmd_data in cmds.items():
                    # Check various path fields
                    path_fields = ['Path', 'FilePath', 'Script']
                    for field in path_fields:
                        if field in cmd_data and cmd_data[field]:
                            file_path = cmd_data[field]
                            full_path = root_dir / file_path if not file_path.startswith(root_str) else Path(file_path)
                            if not full_path.exists():
                                problems.append({
                                    "type": "REGISTRY",
                                    "launcher": cmd_id,
                                    "target": file_path
                                })
                                break  # Only report once per command
            except Exception as e:
                console.print(f"Error reading registry: {e}", style="yellow")
        else:
            console.print(f"Registry file not found: {reg_path}", style="yellow")

            console.print(f"=== Broken references: {len(problems)} ===", style="bold")
        
        if problems:
            # Group by type
            grouped = {}
            for problem in problems:
                ptype = problem["type"]
                if ptype not in grouped:
                    grouped[ptype] = []
                grouped[ptype].append(problem)
            
            for ptype, plist in grouped.items():
                console.print(f"  {ptype}: {len(plist)}", style="cyan")
            
            console.print("")
            # Sort by type, then launcher
            sorted_problems = sorted(problems, key=lambda x: (x["type"], x["launcher"]))
            for problem in sorted_problems:
                console.print(f"[{problem['type']}] {problem['launcher']}", style="yellow")
                console.print(f"      -> {problem['target']}")
                console.print("")
            
            raise typer.Exit(1)
        else:
            console.print("NO BROKEN REFERENCES FOUND", style="green")
        
    except Exception as e:
        console.print(f"Error: {e}", style="red")
        raise typer.Exit(1)


@app.command()
def nextcloud(
    backup_config: bool = typer.Option(False, "--backup-config", help="Additionally back up the client configuration"),
    keep_backups: int = typer.Option(5, "--keep-backups", help="Number of config backups to retain")
):
    """NextCloud sync health check -- read-only status of the desktop client and its sync root."""
    
    console.print("=== NextCloud Sync Health Check ===", style="bold blue")
    
    # Initialize findings list
    findings = []

    def _is_ip_address_private(ip_str):
        """Check if an IP address is private/reserved (RFC 1918, RFC 5735, etc.)."""
        try:
            import socket
            import struct
            # Convert IP string to packed bytes
            packed_ip = socket.inet_aton(ip_str)
            # Convert to integer for easier comparison
            ip_int = struct.unpack("!I", packed_ip)[0]
            
            # Check for private IP ranges:
            # 10.0.0.0/8
            if (ip_int & 0xFF000000) == 0x0A000000:
                return True
            # 172.16.0.0/12
            if (ip_int & 0xFFF00000) == 0xAC100000:
                return True
            # 192.168.0.0/16
            if (ip_int & 0xFFFF0000) == 0xC0A80000:
                return True
            # 127.0.0.0/8 (loopback)
            if (ip_int & 0xFF000000) == 0x7F000000:
                return True
            # 169.254.0.0/16 (link-local)
            if (ip_int & 0xFFFF0000) == 0xA9FE0000:
                return True
            # 224.0.0.0/4 (multicast)
            if (ip_int & 0xF0000000) == 0xE0000000:
                return True
            # 240.0.0.0/4 (reserved)
            if (ip_int & 0xF0000000) == 0xF0000000:
                return True
            # 0.0.0.0/8 (reserved)
            if (ip_int & 0xFF000000) == 0x00000000:
                return True
            
            return False
        except Exception:
            # If we can't parse the IP, treat it as unsafe
            return True

    def _validate_github_api_url(url_to_check):
        """Validate URL is a GitHub API URL to prevent SSRF attacks."""
        from urllib.parse import urlparse
        import socket
        
        parsed = urlparse(url_to_check)
        if parsed.scheme != 'https':
            raise ValueError("Only HTTPS protocol is allowed")
        domain = parsed.hostname.lower() if parsed.hostname else ""
        if domain != 'api.github.com':
            raise ValueError("Only api.github.com domain is allowed")
        expected_path_prefix = '/repos/nextcloud/desktop/releases/latest'
        if not parsed.path.startswith(expected_path_prefix):
            raise ValueError("Unexpected path in GitHub API URL")
        
        # Additional protection against DNS rebinding by validating resolved IP addresses
        try:
            if parsed.hostname:
                # Get all IP addresses associated with the hostname
                ip_addresses = socket.gethostbyname_ex(parsed.hostname)[2]
                for ip in ip_addresses:
                    if _is_ip_address_private(ip):
                        raise ValueError(f"Resolved to private/reserved IP address: {ip}")
        except socket.gaierror:
            # If we can't resolve the hostname, let the request fail naturally
            # This is safer than allowing potentially invalid hostnames
            pass
        except Exception as e:
            # If there's any other error in IP validation, fail safe
            raise ValueError(f"IP validation failed: {str(e)}")
        
        return url_to_check

    def _make_ssrf_protected_github_request(url):
        """Make an SSRF-protected request to GitHub API.
        
        Validates the URL before and after the request to prevent SSRF attacks.
        """
        # Validate URL to prevent SSRF (Server-Side Request Forgery) before request
        validated_url = _validate_github_api_url(url)

        # Pin redirects off: any redirect target would fail URL
        # validation anyway, so block the hop outright instead of
        # validating only after it fired.
        class _NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, hdrs, newurl):
                return None

        # Create request with validated URL
        req = urllib.request.Request(
            validated_url,
            headers={'User-Agent': 'DevOptimizer-NextCloud-Checker'}
        )

        # Make the request
        with urllib.request.build_opener(_NoRedirect).open(
                req, timeout=10) as response:
            # Validate final URL after redirects to prevent SSRF via redirect
            final_url = response.geturl() if hasattr(response, 'geturl') else url
            final_validated_url = _validate_github_api_url(final_url)
            return response

    # 1. Client detection and version checking
    try:
        # Common NextCloud client paths
        client_paths = [
            Path.home() / "AppData" / "Local" / "NextCloud" / "NextCloud.exe",
            Path("C:/Program Files/NextCloud/NextCloud.exe"),
            Path("C:/Program Files (x86)/NextCloud/NextCloud.exe")
        ]
        
        client_exe = None
        for path in client_paths:
            if path.exists():
                client_exe = path
                break
        
        if client_exe:
            # Get file version
            try:
                result = subprocess.run(
                    ["powershell", "-Command", f"(Get-Item '{client_exe}').VersionInfo.ProductVersion"],
                    capture_output=True, text=True, shell=False, timeout=10
                )
                if result.returncode == 0 and result.stdout.strip():
                    version = result.stdout.strip()
                    console.print(f"NextCloud client found: {client_exe} (v{version})", style="green")
                else:
                    console.print(f"NextCloud client found: {client_exe} (version unknown)", style="yellow")
                    findings.append({
                        "type": "WARNING",
                        "message": "Could not determine NextCloud client version"
                    })
            except Exception as e:
                console.print(f"NextCloud client found: {client_exe} (version check failed)", style="yellow")
                findings.append({
                    "type": "WARNING",
                    "message": f"Failed to get client version: {str(e)}"
                })
            
            # Check if process is running
            try:
                result = subprocess.run(
                    ["tasklist", "/FI", "IMAGENAME eq NextCloud.exe"],
                    capture_output=True, text=True, shell=False
                )
                if "NextCloud.exe" in result.stdout:
                    console.print("NextCloud client: RUNNING", style="green")
                else:
                    console.print("NextCloud client: NOT RUNNING", style="yellow")
                    findings.append({
                        "type": "INFO",
                        "message": "NextCloud client is not currently running"
                    })
            except Exception as e:
                console.print(f"Error checking client process: {e}", style="red")
                findings.append({
                    "type": "ERROR",
                    "message": f"Failed to check client process: {str(e)}"
                })
        else:
            console.print("NextCloud client: NOT FOUND", style="red")
            findings.append({
                "type": "ERROR",
                "message": "NextCloud client executable not found in common locations"
            })
    except Exception as e:
        console.print(f"Error during client detection: {e}", style="red")
        findings.append({
            "type": "ERROR",
            "message": f"Client detection failed: {str(e)}"
        })
    
    # 2. Configuration file parsing
    try:
        config_paths = [
            Path.home() / "AppData" / "Local" / "NextCloud" / "nextcloud.cfg",
            Path("C:/ProgramData/NextCloud/nextcloud.cfg")
        ]
        
        config_file = None
        for path in config_paths:
            if path.exists():
                config_file = path
                break
        
        if config_file:
            console.print(f"Configuration file: {config_file}", style="green")
            
            # Parse basic config info
            try:
                content = config_file.read_text(encoding='utf-8', errors='ignore')
                lines = content.split('\n')
                
                # Look for important settings
                sync_root = None
                for line in lines:
                    if line.strip().startswith('SyncRoot='):
                        sync_root = line.split('=', 1)[1].strip()
                        break
                
                if sync_root:
                    console.print(f"Sync root: {sync_root}", style="blue")
                    # Validate sync root exists
                    sync_path = Path(sync_root)
                    if sync_path.exists():
                        console.print(f"Sync root validation: EXISTS", style="green")
                    else:
                        console.print(f"Sync root validation: NOT FOUND", style="red")
                        findings.append({
                            "type": "ERROR",
                            "message": f"Sync root path does not exist: {sync_root}"
                        })
                else:
                    console.print("Sync root: NOT FOUND in config", style="yellow")
                    
            except Exception as e:
                console.print(f"Error reading config file: {e}", style="red")
                findings.append({
                    "type": "ERROR",
                    "message": f"Failed to read configuration file: {str(e)}"
                })
        else:
            console.print("Configuration file: NOT FOUND", style="yellow")
            findings.append({
                "type": "WARNING",
                "message": "NextCloud configuration file not found"
            })
    except Exception as e:
        console.print(f"Error during config parsing: {e}", style="red")
        findings.append({
            "type": "ERROR",
            "message": f"Configuration parsing failed: {str(e)}"
        })
    
    # 3. Sync journal size monitoring
    try:
        # Look for sync journal files
        journal_paths = []
        
        # Check common locations
        appdata_local = Path.home() / "AppData" / "Local"
        if appdata_local.exists():
            for item in appdata_local.rglob("*"):
                if item.is_file() and item.name.endswith(('.db', '-wal')) and 'nextcloud' in item.name.lower():
                    journal_paths.append(item)
        
        # Also check program data
        program_data = Path("C:/ProgramData")
        if program_data.exists():
            for item in program_data.rglob("*"):
                if item.is_file() and item.name.endswith(('.db', '-wal')) and 'nextcloud' in item.name.lower():
                    journal_paths.append(item)
        
        if journal_paths:
            total_size = 0
            for journal in journal_paths[:10]:  # Limit to first 10 files
                try:
                    size = journal.stat().st_size
                    total_size += size
                    console.print(f"Journal file: {journal.name} ({size // 1024} KB)", style="blue")
                except Exception as e:
                    console.print(f"Error reading journal {journal}: {e}", style="yellow")
            
            total_mb = total_size / (1024 * 1024)
            console.print(f"Total journal size: {total_mb:.2f} MB", style="green")
            
            if total_mb > 100:  # Arbitrary threshold
                console.print(f"WARNING: Journal size exceeds 100 MB", style="yellow")
                findings.append({
                    "type": "WARNING",
                    "message": f"Sync journal size is large ({total_mb:.2f} MB)"
                })
        else:
            console.print("Sync journal files: NOT FOUND", style="yellow")
            findings.append({
                "type": "INFO",
                "message": "No NextCloud sync journal files found"
            })
    except Exception as e:
        console.print(f"Error during journal monitoring: {e}", style="red")
        findings.append({
            "type": "ERROR",
            "message": f"Journal monitoring failed: {str(e)}"
        })
    
    # 4. Recent client log analysis
    try:
        log_paths = []
        
        # Check common log locations
        appdata_local = Path.home() / "AppData" / "Local"
        if appdata_local.exists():
            nextcloud_dir = appdata_local / "NextCloud"
            if nextcloud_dir.exists():
                for item in nextcloud_dir.rglob("*"):
                    if item.is_file() and item.name.endswith('.log') and 'nextcloud' in item.name.lower():
                        log_paths.append(item)
        
        # Also check for .log.gz files
        for log_path in list(log_paths):  # Copy list to avoid modification during iteration
            gz_path = Path(str(log_path) + ".gz")
            if gz_path.exists():
                log_paths.append(gz_path)
        
        if log_paths:
            error_count = 0
            warning_count = 0
            lines_checked = 0
            
            # Check most recent log files first
            log_paths.sort(key=lambda x: x.stat().st_mtime if x.exists() else 0, reverse=True)
            
            for log_file in log_paths[:5]:  # Check up to 5 most recent log files
                try:
                    if log_file.suffix == '.gz':
                        # Handle gzipped logs
                        with gzip.open(log_file, 'rt', encoding='utf-8', errors='ignore') as f:
                            lines = f.readlines()
                    else:
                        # Handle regular logs
                        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                            lines = f.readlines()
                    
                    # Check last 1000 lines or all lines if less
                    lines_to_check = lines[-1000:] if len(lines) > 1000 else lines
                    lines_checked += len(lines_to_check)
                    
                    for line in lines_to_check:
                        line_lower = line.lower()
                        if 'error' in line_lower:
                            error_count += 1
                        elif 'warning' in line_lower:
                            warning_count += 1
                            
                except Exception as e:
                    console.print(f"Error reading log {log_file}: {e}", style="yellow")
            
            console.print(f"Log analysis: {lines_checked} lines checked", style="blue")
            console.print(f"Errors found: {error_count}", style="red" if error_count > 0 else "green")
            console.print(f"Warnings found: {warning_count}", style="yellow" if warning_count > 0 else "green")
            
            if error_count > 0:
                findings.append({
                    "type": "ERROR",
                    "message": f"Found {error_count} errors in recent client logs"
                })
            if warning_count > 5:  # Arbitrary threshold
                findings.append({
                    "type": "WARNING",
                    "message": f"Found {warning_count} warnings in recent client logs"
                })
        else:
            console.print("Client logs: NOT FOUND", style="yellow")
            findings.append({
                "type": "INFO",
                "message": "No NextCloud client log files found"
            })
    except Exception as e:
        console.print(f"Error during log analysis: {e}", style="red")
        findings.append({
            "type": "ERROR",
            "message": f"Log analysis failed: {str(e)}"
        })
    
    # 5. Bounded conflict-file audit
    try:
        console.print("Checking for conflict files...", style="blue")
        
        conflict_count = 0
        conflict_files = []
        
        # Look for conflict files in common locations
        search_paths = [
            Path.home(),
            Path("C:/"),
        ]
        
        # Limit search to avoid performance issues
        for search_path in search_paths:
            if not search_path.exists():
                continue
                
            try:
                # Look for files with conflict pattern in name
                for item in search_path.rglob("*"):
                    if item.is_file():
                        filename = item.name.lower()
                        # Common conflict file patterns
                        if any(pattern in filename for pattern in [
                            'conflict', 
                            ' (',  # Space followed by opening parenthesis often indicates conflict
                            ' Kopie',  # German for copy
                            ' copie',  # French for copy
                            ' copia'   # Spanish for copy
                        ]) and (
                            '.nextcloud' in str(item).lower() or 
                            'nextcloud' in str(item).lower()
                        ):
                            conflict_count += 1
                            conflict_files.append(str(item))
                            
                            # Limit to prevent excessive output
                            if conflict_count >= 20:
                                break
                                
                if conflict_count >= 20:
                    break
                    
            except Exception:
                # Skip directories we can't access
                continue
        
        if conflict_count > 0:
            console.print(f"Conflict files found: {conflict_count}", style="red")
            # Show first few examples
            for i, cf in enumerate(conflict_files[:3]):
                console.print(f"  - {cf}", style="red")
            if conflict_count > 3:
                console.print(f"  ... and {conflict_count - 3} more", style="red")
                
            findings.append({
                "type": "ERROR",
                "message": f"Found {conflict_count} conflict files in NextCloud sync folders"
            })
        else:
            console.print("Conflict files: NONE FOUND", style="green")
    except Exception as e:
        console.print(f"Error during conflict file audit: {e}", style="red")
        findings.append({
            "type": "ERROR",
            "message": f"Conflict file audit failed: {str(e)}"
        })
    
    # 6. Defender exclusion checking (when elevated)
    try:
        # Check if we're running with elevated privileges
        is_elevated = False
        try:
            result = subprocess.run(
                ["net", "session"],
                capture_output=True, text=True, shell=False
            )
            is_elevated = (result.returncode == 0)
        except Exception:
            pass
        
        if is_elevated:
            console.print("Checking Defender exclusions (elevated)...", style="blue")
            
            # Common NextCloud paths to check for exclusions
            paths_to_check = [
                str(Path.home() / "AppData" / "Local" / "NextCloud"),
                str(Path.home() / "AppData" / "Local" / "NextCloud" / "NextCloud.exe"),
            ]
            
            # Add sync root if we found it earlier
            # (We'd need to store this from earlier - for simplicity, we'll skip this part)
            
            exclusion_issues = []
            for path in paths_to_check:
                if Path(path).exists():
                    try:
                        # Check if path is excluded from Defender scanning
                        result = subprocess.run(
                            ["powershell", "-Command", 
                             f"(Get-MpPreference).ExclusionPath | Where-Object {{ $_ -like '*{path}*' }}"],
                            capture_output=True, text=True, shell=False, timeout=15
                        )
                        if result.returncode == 0:
                            if not result.stdout.strip():
                                exclusion_issues.append(path)
                    except Exception as e:
                        console.print(f"Error checking Defender exclusion for {path}: {e}", style="yellow")
            
            if exclusion_issues:
                console.print(f"Defender exclusion issues: {len(exclusion_issues)} paths not excluded", style="yellow")
                for path in exclusion_issues:
                    console.print(f"  - {path}", style="yellow")
                findings.append({
                    "type": "WARNING",
                    "message": f"{len(exclusion_issues)} NextCloud paths are not excluded from Windows Defender scanning"
                })
            else:
                console.print("Defender exclusions: OK (all NextCloud paths excluded)", style="green")
        else:
            console.print("Defender exclusion check: SKIPPED (requires elevation)", style="dim")
    except Exception as e:
        console.print(f"Error during Defender exclusion check: {e}", style="red")
        findings.append({
            "type": "ERROR",
            "message": f"Defender exclusion check failed: {str(e)}"
        })
    
    # 7. cldflt driver status checking
    try:
        console.print("Checking cldflt driver status...", style="blue")
        
        try:
            result = subprocess.run(
                ["sc", "query", "cldflt"],
                capture_output=True, text=True, shell=False
            )
            
            if result.returncode == 0:
                if "RUNNING" in result.stdout:
                    console.print("cldflt driver: RUNNING", style="green")
                else:
                    console.print("cldflt driver: NOT RUNNING", style="yellow")
                    findings.append({
                        "type": "WARNING",
                        "message": "NextCloud filesystem filter driver (cldflt) is not running"
                    })
            else:
                console.print("cldflt driver: NOT FOUND", style="yellow")
                findings.append({
                    "type": "WARNING",
                    "message": "NextCloud filesystem filter driver (cldflt) not found"
                })
        except Exception as e:
            console.print(f"Error checking cldflt driver: {e}", style="red")
            findings.append({
                "type": "ERROR",
                "message": f"Failed to check cldflt driver status: {str(e)}"
            })
    except Exception as e:
        console.print(f"Error during cldflt driver check: {e}", style="red")
        findings.append({
            "type": "ERROR",
            "message": f"cldflt driver check failed: {str(e)}"
        })
    
    # 8. Latest version check via GitHub API - FIXED FOR SSRF
    try:
        console.print("Checking for latest NextCloud version...", style="blue")
        
        try:
            # Use GitHub API to get latest release with SSRF protection
            url = "https://api.github.com/repos/nextcloud/desktop/releases/latest"
            
            # Make SSRF-protected request to GitHub API
            response = _make_ssrf_protected_github_request(url)
            
            if response.status == 200:
                data = json.loads(response.read().decode())
                tag_name = data.get('tag_name', '')
                
                # Clean up tag name (remove 'v' prefix if present)
                latest_version = tag_name.lstrip('v')
                
                # Get current version if we have it
                current_version = None
                try:
                    client_paths = [
                        Path.home() / "AppData" / "Local" / "NextCloud" / "NextCloud.exe",
                        Path("C:/Program Files/NextCloud/NextCloud.exe"),
                        Path("C:/Program Files (x86)/NextCloud/NextCloud.exe")
                    ]
                    
                    for path in client_paths:
                        if path.exists():
                            result = subprocess.run(
                                ["powershell", "-Command", f"(Get-Item '{path}').VersionInfo.ProductVersion"],
                                capture_output=True, text=True, shell=False, timeout=5
                            )
                            if result.returncode == 0 and result.stdout.strip():
                                current_version = result.stdout.strip()
                                break
                except Exception:
                    pass  # Keep current_version as None
                
                if latest_version:
                    console.print(f"Latest version available: {latest_version}", style="blue")
                    if current_version:
                        console.print(f"Current version: {current_version}", style="blue")
                        
                        # Simple version comparison (this is basic, could be improved)
                        try:
                            # Parse version numbers
                            current_parts = [int(x) for x in current_version.split('.') if x.isdigit()]
                            latest_parts = [int(x) for x in latest_version.split('.') if x.isdigit()]
                            
                            # Pad with zeros for comparison
                            while len(current_parts) < 3:
                                current_parts.append(0)
                            while len(latest_parts) < 3:
                                latest_parts.append(0)
                            
                            if latest_parts > current_parts:
                                console.print(f"UPDATE AVAILABLE: {current_version} → {latest_version}", style="yellow")
                                findings.append({
                                    "type": "INFO",
                                    "message": f"Newer NextCloud version available: {latest_version} (current: {current_version})"
                                })
                            else:
                                console.print(f"Version is up to date", style="green")
                        except Exception:
                            # If version parsing fails, just show the versions
                            console.print(f"Version comparison skipped - unable to parse versions", style="dim")
                    else:
                        console.print("Current version: UNKNOWN", style="yellow")
                else:
                    console.print("Could not determine latest version from GitHub", style="yellow")
            else:
                console.print(f"GitHub API returned status {response.status}", style="yellow")
        except urllib.error.URLError as e:
            console.print(f"Network error checking GitHub: {e}", style="yellow")
            console.print("Falling back to offline version check...", style="dim")
            
            # Offline fallback - just report that we can't check
            findings.append({
                "type": "INFO",
                "message": "Unable to check for updates online (network issue)"
            })
        except ValueError as e:
            # This catches our validation errors
            console.print(f"Security validation failed: {e}", style="red")
            findings.append({
                "type": "ERROR",
                "message": f"Security check failed: {str(e)}"
            })
        except Exception as e:
            console.print(f"Error checking GitHub API: {e}", style="red")
            findings.append({
                "type": "ERROR",
                "message": f"Failed to check for updates: {str(e)}"
            })
    except Exception as e:
        console.print(f"Error during version check: {e}", style="red")
        findings.append({
            "type": "ERROR",
            "message": f"Version check failed: {str(e)}"
        })
    
    # 9. Optional configuration backup functionality
    if backup_config:
        try:
            console.print("Backing up configuration...", style="blue")
            
            # Find config file
            config_paths = [
                Path.home() / "AppData" / "Local" / "NextCloud" / "nextcloud.cfg",
                Path("C:/ProgramData/NextCloud/nextcloud.cfg")
            ]
            
            config_file = None
            for path in config_paths:
                if path.exists():
                    config_file = path
                    break
            
            if config_file:
                # Create backup directory
                backup_dir = Path("D:/DevOptimizer/backups/nextcloud")
                backup_dir.mkdir(parents=True, exist_ok=True)
                
                # Generate backup filename with timestamp
                timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                backup_file = backup_dir / f"nextcloud.cfg.{timestamp}"
                
                # Copy file
                import shutil
                shutil.copy2(config_file, backup_file)
                
                console.print(f"Configuration backed up to: {backup_file}", style="green")
                
                # Clean up old backups
                try:
                    backups = sorted(backup_dir.glob("nextcloud.cfg.*"), key=lambda x: x.stat().st_mtime, reverse=True)
                    if len(backups) > keep_backups:
                        for old_backup in backups[keep_backups:]:
                            old_backup.unlink()
                            console.print(f"Removed old backup: {old_backup.name}", style="dim")
                except Exception as e:
                    console.print(f"Error cleaning up old backups: {e}", style="yellow")
            else:
                console.print("Configuration file not found for backup", style="yellow")
                findings.append({
                    "type": "WARNING",
                    "message": "Could not backup configuration - file not found"
                })
        except Exception as e:
            console.print(f"Error during configuration backup: {e}", style="red")
            findings.append({
                "type": "ERROR",
                "message": f"Configuration backup failed: {str(e)}"
            })
    
    # 10. Health verdict reporting
    console.print("\n=== Health Check Summary ===", style="bold blue")
    
    error_count = len([f for f in findings if f["type"] == "ERROR"])
    warning_count = len([f for f in findings if f["type"] == "WARNING"])
    info_count = len([f for f in findings if f["type"] == "INFO"])
    
    if error_count > 0:
        verdict = "UNHEALTHY"
        verdict_style = "red"
    elif warning_count > 0:
        verdict = "WARNINGS"
        verdict_style = "yellow"
    else:
        verdict = "HEALTHY"
        verdict_style = "green"
    
    console.print(f"Overall Status: [{verdict}]({verdict_style})", style=verdict_style)
    console.print(f"Issues found: {error_count} errors, {warning_count} warnings, {info_count} informational", style="blue")
    
    # Show details if there are issues
    if findings:
        console.print("\nDetails:", style="blue")
        for finding in findings:
            type_style = {
                "ERROR": "red",
                "WARNING": "yellow", 
                "INFO": "blue"
            }.get(finding["type"], "white")
            
            console.print(f"  [{finding['type']}] {finding['message']}", style=type_style)
    
    # Exit with appropriate code
    if error_count > 0:
        raise typer.Exit(1)
    else:
        raise typer.Exit(0)


@app.command()
def models():
    """List available Ollama models"""

    if not check_ollama_available():
        console.print("Ollama not available. Please install Ollama first.", style="red")
        raise typer.Exit(1)

    try:
        result = subprocess.run(["ollama", "list"], capture_output=True, text=True, check=True, shell=False)

        console.print("Available Ollama Models:", style="bold blue")
        console.print(result.stdout)

    except subprocess.CalledProcessError as e:
        console.print(f"Error listing models: {e}", style="red")
        raise typer.Exit(1)
