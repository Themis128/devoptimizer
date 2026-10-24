"""
Register-ScheduledTasks.ps1 - Python port
Manage DevOptimizer scheduled tasks using Windows Task Scheduler
"""

import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

import typer

from devoptimizer_cli.core.io_helpers import safe_write_json

app = typer.Typer(help="Manage DevOptimizer scheduled tasks")


def _run_schtasks(args: list[str]) -> subprocess.CompletedProcess:
    """Run schtasks.exe with the given arguments."""
    return subprocess.run(
        ["schtasks.exe"] + args,
        capture_output=True,
        text=True,
        shell=False,
    )


def _run_powershell(script: str) -> subprocess.CompletedProcess:
    """Run a PowerShell script and return the result."""
    return subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
        capture_output=True,
        text=True,
        shell=False,
    )


def _check_admin() -> bool:
    """Check if running as administrator."""
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
             "([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)"],
            capture_output=True,
            text=True,
            shell=False,
        )
        return result.stdout.strip().lower() == "true"
    except Exception:
        return False


def _get_task_files(tasks_dir: Path) -> list[Path]:
    """Get all XML task files from the tasks directory."""
    if not tasks_dir.exists():
        return []
    return sorted(tasks_dir.glob("*.xml"))


@app.command("register")
def register_tasks(
    tasks_dir: str = typer.Option(r"D:\DevOptimizer\tasks", help="Directory containing task XML files"),
    force: bool = typer.Option(False, help="Overwrite existing tasks"),
    logs_dir: str = typer.Option(r"D:\DevOptimizer\logs", help="Directory for log files"),
):
    """Register DevOptimizer scheduled tasks from XML files."""
    tasks_path = Path(tasks_dir)
    logs_path = Path(logs_dir)

    if not _check_admin():
        typer.echo("This command must be run as administrator to manage scheduled tasks", err=True)
        raise typer.Exit(1)

    task_files = _get_task_files(tasks_path)
    if not task_files:
        typer.echo(f"No task files found in: {tasks_path}", err=True)
        raise typer.Exit(0)

    typer.echo(f"Found {len(task_files)} task files")

    results = {
        "timestamp": datetime.now().isoformat(),
        "operation": "register",
        "tasks": [],
        "errors": [],
    }

    logs_path.mkdir(parents=True, exist_ok=True)

    for task_file in task_files:
        task_name = task_file.stem
        typer.echo(f"\nProcessing task: {task_name}")

        try:
            # Check if task exists
            check_result = _run_schtasks(["/Query", "/TN", task_name])

            if check_result.returncode == 0 and not force:
                typer.echo(f"Task already exists: {task_name}")
                typer.echo("Use --force to overwrite existing tasks")
                results["tasks"].append({
                    "name": task_name,
                    "action": "register",
                    "status": "already_exists",
                })
                continue

            if check_result.returncode == 0 and force:
                # Unregister existing task
                _run_schtasks(["/Delete", "/TN", task_name, "/F"])
                typer.echo(f"Removed existing task: {task_name}")

            # Register new task using XML
            with open(task_file, "r", encoding="utf-8") as f:
                xml_content = f.read()

            # Use PowerShell Register-ScheduledTask with XML
            ps_script = f'''
$xml = @"
{xml_content}
"@
Register-ScheduledTask -Xml $xml -TaskName "{task_name}" -Force
'''
            reg_result = _run_powershell(ps_script)

            if reg_result.returncode == 0:
                results["tasks"].append({
                    "name": task_name,
                    "action": "registered",
                    "status": "success",
                    "file": str(task_file),
                })
                typer.echo(f"Registered task: {task_name}")
            else:
                raise Exception(reg_result.stderr)

        except Exception as e:
            results["errors"].append({
                "task": task_name,
                "action": "register",
                "error": str(e),
            })
            typer.echo(f"Failed to process task '{task_name}': {e}", err=True)

    # Save results
    results_file = logs_path / f"task_registration_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    safe_write_json(results, results_file)
    typer.echo(f"\nResults saved to: {results_file}")

    # Display registered DevOptimizer tasks
    typer.echo("\nRegistered DevOptimizer tasks:")
    list_result = _run_schtasks(["/Query", "/FO", "LIST", "/V"])
    if list_result.returncode == 0:
        lines = list_result.stdout.splitlines()
        current_task = {}
        for line in lines:
            if line.startswith("TaskName:"):
                if current_task and "DevOptimizer" in current_task.get("TaskName", ""):
                    _print_task_info(current_task)
                current_task = {"TaskName": line.split(":", 1)[1].strip()}
            elif ":" in line and current_task:
                key, value = line.split(":", 1)
                current_task[key.strip()] = value.strip()
        if current_task and "DevOptimizer" in current_task.get("TaskName", ""):
            _print_task_info(current_task)

    # Display summary
    successful = sum(1 for t in results["tasks"] if t["status"] == "success")
    failed = len(results["errors"])

    typer.echo("\n" + "=" * 60)
    typer.echo("SCHEDULED TASKS MANAGEMENT COMPLETED")
    typer.echo("=" * 60)
    typer.echo(f"Operation: {results['operation']}")
    typer.echo(f"Tasks processed: {len(results['tasks'])}")
    typer.echo(f"Successful: {successful}")
    typer.echo(f"Failed: {failed}")

    if results["errors"]:
        typer.echo("\nErrors encountered:")
        for error in results["errors"]:
            typer.echo(f"- {error['task']}: {error['error']}")

    typer.echo(f"\nResults file: {results_file}")
    typer.echo("=" * 60)

    if failed > 0:
        raise typer.Exit(1)


@app.command("unregister")
def unregister_tasks(
    tasks_dir: str = typer.Option(r"D:\DevOptimizer\tasks", help="Directory containing task XML files"),
    force: bool = typer.Option(False, help="Skip confirmation"),
    logs_dir: str = typer.Option(r"D:\DevOptimizer\logs", help="Directory for log files"),
):
    """Unregister DevOptimizer scheduled tasks."""
    tasks_path = Path(tasks_dir)
    logs_path = Path(logs_dir)

    if not _check_admin():
        typer.echo("This command must be run as administrator to manage scheduled tasks", err=True)
        raise typer.Exit(1)

    task_files = _get_task_files(tasks_path)
    if not task_files:
        typer.echo(f"No task files found in: {tasks_path}", err=True)
        raise typer.Exit(0)

    typer.echo(f"Found {len(task_files)} task files")

    results = {
        "timestamp": datetime.now().isoformat(),
        "operation": "unregister",
        "tasks": [],
        "errors": [],
    }

    logs_path.mkdir(parents=True, exist_ok=True)

    for task_file in task_files:
        task_name = task_file.stem
        typer.echo(f"\nProcessing task: {task_name}")

        try:
            check_result = _run_schtasks(["/Query", "/TN", task_name])

            if check_result.returncode != 0:
                typer.echo(f"Task not found: {task_name}")
                results["tasks"].append({
                    "name": task_name,
                    "action": "unregistered",
                    "status": "not_found",
                })
                continue

            # Unregister task
            confirm_flag = "/F" if force else ""
            unreg_result = _run_schtasks(["/Delete", "/TN", task_name] + ([confirm_flag] if confirm_flag else []))

            if unreg_result.returncode == 0:
                results["tasks"].append({
                    "name": task_name,
                    "action": "unregistered",
                    "status": "success",
                })
                typer.echo(f"Unregistered task: {task_name}")
            else:
                raise Exception(unreg_result.stderr)

        except Exception as e:
            results["errors"].append({
                "task": task_name,
                "action": "unregister",
                "error": str(e),
            })
            typer.echo(f"Failed to process task '{task_name}': {e}", err=True)

    # Save results
    results_file = logs_path / f"task_registration_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    safe_write_json(results, results_file)
    typer.echo(f"\nResults saved to: {results_file}")

    # Display summary
    successful = sum(1 for t in results["tasks"] if t["status"] == "success")
    failed = len(results["errors"])

    typer.echo("\n" + "=" * 60)
    typer.echo("SCHEDULED TASKS MANAGEMENT COMPLETED")
    typer.echo("=" * 60)
    typer.echo(f"Operation: {results['operation']}")
    typer.echo(f"Tasks processed: {len(results['tasks'])}")
    typer.echo(f"Successful: {successful}")
    typer.echo(f"Failed: {failed}")

    if results["errors"]:
        typer.echo("\nErrors encountered:")
        for error in results["errors"]:
            typer.echo(f"- {error['task']}: {error['error']}")

    typer.echo(f"\nResults file: {results_file}")
    typer.echo("=" * 60)

    if failed > 0:
        raise typer.Exit(1)


@app.command("list")
def list_tasks(
    filter_prefix: str = typer.Option("DevOptimizer", help="Filter tasks by name prefix"),
):
    """List registered DevOptimizer tasks."""
    result = _run_schtasks(["/Query", "/FO", "LIST", "/V"])

    if result.returncode != 0:
        typer.echo("No tasks found or error querying tasks")
        return

    lines = result.stdout.splitlines()
    current_task = {}
    found_any = False

    for line in lines:
        if line.startswith("TaskName:"):
            if current_task and filter_prefix in current_task.get("TaskName", ""):
                _print_task_info(current_task)
                found_any = True
            current_task = {"TaskName": line.split(":", 1)[1].strip()}
        elif ":" in line and current_task:
            key, value = line.split(":", 1)
            current_task[key.strip()] = value.strip()

    if current_task and filter_prefix in current_task.get("TaskName", ""):
        _print_task_info(current_task)
        found_any = True

    if not found_any:
        typer.echo(f"No tasks found with prefix: {filter_prefix}")


def _print_task_info(task: dict):
    """Print task information."""
    typer.echo(f"  - {task.get('TaskName', 'Unknown')}")
    typer.echo(f"    State: {task.get('State', 'Unknown')}")
    typer.echo(f"    Next Run: {task.get('Next Run Time', 'Never')}")
    typer.echo(f"    Last Run: {task.get('Last Run Time', 'Never')}")
    typer.echo("")


@app.command("status")
def tasks_status(
    filter_prefix: str = typer.Option("DevOptimizer", help="Filter tasks by name prefix"),
):
    """Show detailed status of DevOptimizer tasks."""
    result = _run_schtasks(["/Query", "/FO", "LIST", "/V"])

    if result.returncode != 0:
        typer.echo("No tasks found or error querying tasks")
        return

    lines = result.stdout.splitlines()
    current_task = {}
    found_any = False

    for line in lines:
        if line.startswith("TaskName:"):
            if current_task and filter_prefix in current_task.get("TaskName", ""):
                _print_detailed_task_info(current_task)
                found_any = True
            current_task = {"TaskName": line.split(":", 1)[1].strip()}
        elif ":" in line and current_task:
            key, value = line.split(":", 1)
            current_task[key.strip()] = value.strip()

    if current_task and filter_prefix in current_task.get("TaskName", ""):
        _print_detailed_task_info(current_task)
        found_any = True

    if not found_any:
        typer.echo(f"No tasks found with prefix: {filter_prefix}")


def _print_detailed_task_info(task: dict):
    """Print detailed task information."""
    typer.echo(f"\nTask: {task.get('TaskName', 'Unknown')}")
    typer.echo(f"  State: {task.get('State', 'Unknown')}")
    typer.echo(f"  Next Run: {task.get('Next Run Time', 'Never')}")
    typer.echo(f"  Last Run: {task.get('Last Run Time', 'Never')}")
    typer.echo(f"  Last Result: {task.get('Last Result', 'Unknown')}")
    typer.echo(f"  Author: {task.get('Author', 'Unknown')}")
    typer.echo(f"  Enabled: {task.get('Scheduled Task State', 'Unknown')}")


if __name__ == "__main__":
    app()