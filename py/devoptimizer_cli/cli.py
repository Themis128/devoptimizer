"""
DevOptimizer CLI Application
Main entry point with Typer-based commands
"""

import json
import os
import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn

from devoptimizer_cli.commands.metrics import app as metrics_app
from devoptimizer_cli.commands.analyze import app as analyze_app
from devoptimizer_cli.commands.remediate import app as remediate_app
from devoptimizer_cli.commands.bootstrap import app as bootstrap_app
from devoptimizer_cli.commands.security import app as security_app
from devoptimizer_cli.commands.cleanup.cleanup import app as cleanup_app

app = typer.Typer(
    name="devoptimizer",
    help="Windows optimization and monitoring tool",
    add_completion=False,
    rich_markup_mode="rich"
)

console = Console()

# Add command modules
app.add_typer(metrics_app, name="metrics", help="Performance metrics collection")
app.add_typer(analyze_app, name="analyze", help="AI-powered analysis")
app.add_typer(remediate_app, name="remediate", help="System remediation")
app.add_typer(bootstrap_app, name="bootstrap", help="Development environment setup")
app.add_typer(security_app, name="security", help="Security hardening")
app.add_typer(cleanup_app, name="cleanup", help="System cleanup commands")
# Import and add WSL commands
from devoptimizer_cli.commands.wsl import app as wsl_app
app.add_typer(wsl_app, name="wsl", help="WSL system status and monitoring")

@app.command()
def status():
    """Show DevOptimizer system status"""
    console.print(Panel.fit("DevOptimizer Status", style="bold blue"))

    # Check root directory
    root_path = Path("D:/DevOptimizer")
    if root_path.exists():
        console.print("✓ Root directory exists", style="green")
    else:
        console.print("✗ Root directory missing", style="red")
        return

    # Check key directories
    required_dirs = ["bin", "ps", "py", "tasks", "configs", ".env", "metrics", "traces", "logs", "ai-analysis"]
    table = Table(title="Directory Status")
    table.add_column("Directory", style="cyan")
    table.add_column("Status", style="green")
    table.add_column("Path")

    for dir_name in required_dirs:
        dir_path = root_path / dir_name
        if dir_path.exists():
            table.add_row(dir_name, "✓", str(dir_path))
        else:
            table.add_row(dir_name, "✗", str(dir_path))

    console.print(table)

    # Check Python dependencies
    console.print("\n[bold]Python Dependencies:[/bold]")
    deps_table = Table()
    deps_table.add_column("Package", style="cyan")
    deps_table.add_column("Status", style="green")

    required_packages = ["typer", "rich", "psutil", "pydantic", "httpx", "colorama"]
    for package in required_packages:
        try:
            __import__(package)
            deps_table.add_row(package, "✓")
        except ImportError:
            deps_table.add_row(package, "✗")

    console.print(deps_table)

@app.command()
def version():
    """Show version information"""
    from . import __version__

    console.print(f"DevOptimizer CLI v{__version__}")
    console.print(f"Python {sys.version}")
    console.print(f"Platform: {sys.platform}")

@app.callback()
def main(
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Enable verbose output"),
    config: Optional[Path] = typer.Option(None, "--config", "-c", help="Config file path")
):
    """DevOptimizer - Windows optimization and monitoring tool"""
    if verbose:
        console.print("Verbose mode enabled", style="dim")

    if config and not config.exists():
        console.print(f"Config file not found: {config}", style="red")
        raise typer.Exit(1)

if __name__ == "__main__":
    app()