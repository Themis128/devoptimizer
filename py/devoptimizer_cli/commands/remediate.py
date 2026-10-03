"""
System remediation commands
"""

import json
import subprocess
import sys
import re
from pathlib import Path
from typing import Optional, List

from devoptimizer_cli.paths import safe_open_write
import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn

app = typer.Typer(name="remediate", help="System remediation and optimization")
console = Console()

@app.command()
def cleanup(
    temp_files: bool = typer.Option(True, "--temp", help="Clean temporary files"),
    cache: bool = typer.Option(True, "--cache", help="Clean cache files"),
    logs: bool = typer.Option(False, "--logs", help="Clean old log files"),
    browser_cache: bool = typer.Option(False, "--browser-cache", help="Clean browser cache"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation prompts")
):
    """Clean up system files and caches"""

    if not confirm:
        console.print("This will clean up system files. Continue?", style="yellow")
        if not typer.confirm("Proceed?"):
            console.print("Cleanup cancelled", style="yellow")
            return

    cleanup_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "actions": [],
        "errors": []
    }

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:

        if temp_files:
            task = progress.add_task("Cleaning temporary files...", total=None)
            try:
                # Clean Windows temp files
                temp_dirs = [
                    "C:\\Windows\\Temp",
                    "C:\\Temp",
                    "$env:TEMP"
                ]

                for temp_dir in temp_dirs:
                    try:
                        if temp_dir.startswith("$env:"):
                            temp_path = Path(temp_dir.replace("$env:", ""))
                        else:
                            temp_path = Path(temp_dir)

                        if temp_path.exists():
                            # Count files before cleanup
                            files_before = sum(1 for _ in temp_path.rglob("*") if _.is_file())

                            # Clean files older than 7 days
                            for file_path in temp_path.rglob("*"):
                                if file_path.is_file() and file_path.stat().st_mtime < (Path().stat().st_mtime - 7 * 24 * 3600):
                                    try:
                                        file_path.unlink()
                                    except:
                                        pass

                            # Count files after cleanup
                            files_after = sum(1 for _ in temp_path.rglob("*") if _.is_file())
                            cleaned = files_before - files_after

                            cleanup_results["actions"].append({
                                "action": "temp_cleanup",
                                "location": str(temp_path),
                                "files_removed": cleaned
                            })

                    except Exception as e:
                        cleanup_results["errors"].append({
                            "action": "temp_cleanup",
                            "location": temp_dir,
                            "error": str(e)
                        })

                progress.update(task, completed=100)

            except Exception as e:
                cleanup_results["errors"].append({
                    "action": "temp_cleanup",
                    "error": str(e)
                })

        if cache:
            task = progress.add_task("Cleaning cache files...", total=None)
            try:
                # Clean common cache locations
                cache_dirs = [
                    "C:\\Windows\\Prefetch",
                    "C:\\Users\\Default\\AppData\\Local\\Temp",
                    "C:\\Windows\\SoftwareDistribution\\Download"
                ]

                for cache_dir in cache_dirs:
                    cache_path = Path(cache_dir)
                    if cache_path.exists():
                        try:
                            files_before = sum(1 for _ in cache_path.rglob("*") if _.is_file())

                            # Clean files older than 30 days
                            for file_path in cache_path.rglob("*"):
                                if file_path.is_file() and file_path.stat().st_mtime < (Path().stat().st_mtime - 30 * 24 * 3600):
                                    try:
                                        file_path.unlink()
                                    except:
                                        pass

                            files_after = sum(1 for _ in cache_path.rglob("*") if _.is_file())
                            cleaned = files_before - files_after

                            cleanup_results["actions"].append({
                                "action": "cache_cleanup",
                                "location": str(cache_path),
                                "files_removed": cleaned
                            })

                        except Exception as e:
                            cleanup_results["errors"].append({
                                "action": "cache_cleanup",
                                "location": cache_dir,
                                "error": str(e)
                            })

                progress.update(task, completed=100)

            except Exception as e:
                cleanup_results["errors"].append({
                    "action": "cache_cleanup",
                    "error": str(e)
                })

        if logs:
            task = progress.add_task("Cleaning old log files...", total=None)
            try:
                log_dirs = [
                    "C:\\Windows\\Logs",
                    "D:\\DevOptimizer\\logs"
                ]

                for log_dir in log_dirs:
                    log_path = Path(log_dir)
                    if log_path.exists():
                        try:
                            files_before = sum(1 for _ in log_path.rglob("*.log") if _.is_file())

                            # Clean log files older than 90 days
                            for log_file in log_path.rglob("*.log"):
                                if log_file.stat().st_mtime < (Path().stat().st_mtime - 90 * 24 * 3600):
                                    try:
                                        log_file.unlink()
                                    except:
                                        pass

                            files_after = sum(1 for _ in log_path.rglob("*.log") if _.is_file())
                            cleaned = files_before - files_after

                            cleanup_results["actions"].append({
                                "action": "log_cleanup",
                                "location": str(log_path),
                                "files_removed": cleaned
                            })

                        except Exception as e:
                            cleanup_results["errors"].append({
                                "action": "log_cleanup",
                                "location": log_dir,
                                "error": str(e)
                            })

                progress.update(task, completed=100)

            except Exception as e:
                cleanup_results["errors"].append({
                    "action": "log_cleanup",
                    "error": str(e)
                })

        if browser_cache:
            task = progress.add_task("Cleaning browser cache...", total=None)
            try:
                # Common browser cache locations
                browser_cache_dirs = [
                    "C:\\Users\\%USERNAME%\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\Cache",
                    "C:\\Users\\%USERNAME%\\AppData\\Local\\Microsoft\\Edge\\User Data\\Default\\Cache",
                    "C:\\Users\\%USERNAME%\\AppData\\Roaming\\Mozilla\\Firefox\\Profiles\\*\\cache2"
                ]

                for cache_dir in browser_cache_dirs:
                    try:
                        # Expand environment variables
                        expanded_dir = Path(cache_dir.replace("%USERNAME%", "Default"))
                        if expanded_dir.exists():
                            files_before = sum(1 for _ in expanded_dir.rglob("*") if _.is_file())

                            # Clean cache files older than 7 days
                            for cache_file in expanded_dir.rglob("*"):
                                if cache_file.is_file() and cache_file.stat().st_mtime < (Path().stat().st_mtime - 7 * 24 * 3600):
                                    try:
                                        cache_file.unlink()
                                    except:
                                        pass

                            files_after = sum(1 for _ in expanded_dir.rglob("*") if _.is_file())
                            cleaned = files_before - files_after

                            cleanup_results["actions"].append({
                                "action": "browser_cache_cleanup",
                                "location": str(expanded_dir),
                                "files_removed": cleaned
                            })

                    except Exception as e:
                        cleanup_results["errors"].append({
                            "action": "browser_cache_cleanup",
                            "location": cache_dir,
                            "error": str(e)
                        })

                progress.update(task, completed=100)

            except Exception as e:
                cleanup_results["errors"].append({
                    "action": "browser_cache_cleanup",
                    "error": str(e)
                })

    # Save results
    results_file = Path("D:/DevOptimizer/logs/cleanup_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(cleanup_results, f, indent=2)

    # Display summary
    console.print(f"\nCleanup Summary:", style="bold blue")

    total_actions = len(cleanup_results["actions"])
    total_errors = len(cleanup_results["errors"])
    total_files = sum(action.get("files_removed", 0) for action in cleanup_results["actions"])

    console.print(f"Actions completed: {total_actions}")
    console.print(f"Files removed: {total_files}")
    console.print(f"Errors: {total_errors}")

    if cleanup_results["errors"]:
        console.print(f"\nErrors encountered:", style="red")
        for error in cleanup_results["errors"]:
            console.print(f"- {error['action']}: {error['error']}")

    console.print(f"✓ Results saved to: {results_file}", style="green")

@app.command()
def optimize(
    registry: bool = typer.Option(True, "--registry", help="Optimize registry"),
    services: bool = typer.Option(True, "--services", help="Optimize services"),
    startup: bool = typer.Option(True, "--startup", help="Optimize startup programs"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation prompts")
):
    """Optimize system performance"""

    if not confirm:
        console.print("This will make system optimizations. Continue?", style="yellow")
        if not typer.confirm("Proceed?"):
            console.print("Optimization cancelled", style="yellow")
            return

    optimization_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "actions": [],
        "errors": []
    }

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:

        if registry:
            task = progress.add_task("Optimizing registry...", total=None)
            try:
                # Registry optimizations (safe ones) - using argument lists instead of shell=True
                registry_commands = [
                    # Disable unnecessary visual effects
                    ["reg", "add", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects", "/v", "VisualFXSetting", "/t", "REG_DWORD", "/d", "2", "/f"],
                    # Optimize for performance
                    ["reg", "add", "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects", "/v", "VisualFXSetting", "/t", "REG_DWORD", "/d", "2", "/f"],
                    # Disable unnecessary animations
                    ["reg", "add", "HKCU\\Control Panel\\Desktop\\WindowMetrics", "/v", "MinAnimate", "/t", "REG_SZ", "/d", "0", "/f"]
                ]

                for cmd in registry_commands:
                    try:
                        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
                        optimization_results["actions"].append({
                            "action": "registry_optimization",
                            "command": " ".join(cmd),
                            "status": "success"
                        })
                    except subprocess.CalledProcessError as e:
                        optimization_results["errors"].append({
                            "action": "registry_optimization",
                            "command": " ".join(cmd),
                            "error": e.stderr
                        })

                progress.update(task, completed=100)

            except Exception as e:
                optimization_results["errors"].append({
                    "action": "registry_optimization",
                    "error": str(e)
                })

        if services:
            task = progress.add_task("Optimizing services...", total=None)
            try:
                # Services to optimize (set to manual start)
                services_to_optimize = [
                    "Fax",
                    "WSearch",
                    "TabletInputService",
                    "XblAuthManager",
                    "XblGameSave",
                    "XboxNetApiSvc"
                ]

                for service in services_to_optimize:
                    try:
                        # Check if service exists and is running
                        result = subprocess.run(
                            ["sc", "query", service],
                            capture_output=True,
                            text=True,
                            check=False
                        )

                        if "RUNNING" in result.stdout:
                            # Set to manual start
                            subprocess.run(
                                ["sc", "config", service, "start=", "demand"],
                                capture_output=True,
                                text=True,
                                check=True
                            )

                            optimization_results["actions"].append({
                                "action": "service_optimization",
                                "service": service,
                                "change": "Set to manual start"
                            })

                    except subprocess.CalledProcessError as e:
                        optimization_results["errors"].append({
                            "action": "service_optimization",
                            "service": service,
                            "error": e.stderr
                        })

                progress.update(task, completed=100)

            except Exception as e:
                optimization_results["errors"].append({
                    "action": "service_optimization",
                    "error": str(e)
                })

        if startup:
            task = progress.add_task("Optimizing startup programs...", total=None)
            try:
                # Get startup programs
                startup_result = subprocess.run(
                    ["wmic", "startup", "get", "name,command,location"],
                    capture_output=True,
                    text=True,
                    check=True
                )

                # Parse startup programs (simplified)
                startup_programs = []
                for line in startup_result.stdout.split('\n'):
                    if line.strip() and not line.startswith('Name'):
                        parts = line.split()
                        if len(parts) >= 2:
                            startup_programs.append({
                                "name": parts[0],
                                "location": parts[-1] if len(parts) > 2 else "Unknown"
                            })

                optimization_results["actions"].append({
                    "action": "startup_analysis",
                    "programs_found": len(startup_programs),
                    "programs": startup_programs[:5]  # Limit to first 5
                })

                progress.update(task, completed=100)

            except Exception as e:
                optimization_results["errors"].append({
                    "action": "startup_optimization",
                    "error": str(e)
                })

    # Save results
    results_file = Path("D:/DevOptimizer/logs/optimization_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(optimization_results, f, indent=2)

    # Display summary
    console.print(f"\nOptimization Summary:", style="bold blue")

    total_actions = len(optimization_results["actions"])
    total_errors = len(optimization_results["errors"])

    console.print(f"Actions completed: {total_actions}")
    console.print(f"Errors: {total_errors}")

    if optimization_results["errors"]:
        console.print(f"\nErrors encountered:", style="red")
        for error in optimization_results["errors"]:
            console.print(f"- {error['action']}: {error.get('error', 'Unknown error')}")

    console.print(f"✓ Results saved to: {results_file}", style="green")

@app.command()
def defrag(
    drives: Optional[List[str]] = typer.Option(None, "--drives", "-d", help="Specific drives to defragment"),
    analyze_only: bool = typer.Option(False, "--analyze", "-a", help="Only analyze, don't defragment")
):
    """Defragment drives for better performance"""

    if not drives:
        # Get all local drives
        try:
            result = subprocess.run(
                ["wmic", "logicaldisk", "get", "size,freespace,caption"],
                capture_output=True,
                text=True,
                check=True
            )

            drives = []
            for line in result.stdout.split('\n'):
                if ':' in line and not line.startswith('Caption'):
                    drive = line.split()[0]
                    if drive.endswith(':'):
                        drives.append(drive)
        except Exception as e:
            console.print(f"Error getting drives: {e}", style="red")
            return

    defrag_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "drives": [],
        "errors": []
    }

    for drive in drives:
        # Validate drive letter to prevent command injection
        if not re.match(r'^[A-Z]:$', drive.upper()):
            console.print(f"Invalid drive format: {drive}. Expected format: C:", style="red")
            defrag_results["errors"].append({
                "drive": drive,
                "error": "Invalid drive format"
            })
            continue

        console.print(f"Processing drive: {drive}", style="blue")

        try:
            if analyze_only:
                # Analyze only - drive is validated above
                result = subprocess.run(
                    ["defrag", drive.upper(), "/A"],
                    capture_output=True,
                    text=True,
                    check=True
                )

                defrag_results["drives"].append({
                    "drive": drive,
                    "action": "analyze",
                    "output": result.stdout
                })

                console.print(f"✓ Analysis completed for {drive}", style="green")

            else:
                # Full defragmentation - drive is validated above
                result = subprocess.run(
                    ["defrag", drive.upper(), "/O"],
                    capture_output=True,
                    text=True,
                    check=True
                )

                defrag_results["drives"].append({
                    "drive": drive,
                    "action": "defragment",
                    "output": result.stdout
                })

                console.print(f"✓ Defragmentation completed for {drive}", style="green")

        except subprocess.CalledProcessError as e:
            defrag_results["errors"].append({
                "drive": drive,
                "error": e.stderr
            })
            console.print(f"✗ Error processing {drive}: {e.stderr}", style="red")

    # Save results - validate path to prevent arbitrary file write
    results_file = Path("D:/DevOptimizer/logs/defrag_results.json").resolve()
    if not str(results_file).startswith(str(Path("D:/DevOptimizer").resolve())):
        console.print("Error: Results path must be within DevOptimizer directory", style="red")
        raise typer.Exit(1)

    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(defrag_results, f, indent=2)

    console.print(f"✓ Results saved to: {results_file}", style="green")
