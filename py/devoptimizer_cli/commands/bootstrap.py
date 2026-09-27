"""
Development environment bootstrap commands
"""

import json
import subprocess
import sys
import re
from pathlib import Path
from typing import Optional, List

import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn

app = typer.Typer(name="bootstrap", help="Development environment setup")
console = Console()

def check_winget_available() -> bool:
    """Check if winget is available"""
    try:
        result = subprocess.run(["winget", "--version"], capture_output=True, text=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def check_chocolatey_available() -> bool:
    """Check if Chocolatey is available"""
    try:
        result = subprocess.run(["choco", "--version"], capture_output=True, text=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

@app.command()
def install_tools(
    package_file: Optional[Path] = typer.Option(None, "--packages", "-p", help="Package configuration file"),
    use_winget: bool = typer.Option(True, "--winget", help="Use winget for installation"),
    use_chocolatey: bool = typer.Option(False, "--chocolatey", help="Use Chocolatey for installation"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation prompts")
):
    """Install development tools using package managers"""

    if not package_file:
        package_file = Path("D:/DevOptimizer/configs/winget-packages.json")

    if not package_file.exists():
        console.print(f"Package file not found: {package_file}", style="red")
        raise typer.Exit(1)

    # Check available package managers
    winget_available = check_winget_available()
    chocolatey_available = check_chocolatey_available()

    if use_winget and not winget_available:
        console.print("winget not available, skipping winget installations", style="yellow")
        use_winget = False

    if use_chocolatey and not chocolatey_available:
        console.print("Chocolatey not available, skipping Chocolatey installations", style="yellow")
        use_chocolatey = False

    if not use_winget and not use_chocolatey:
        console.print("No package managers available", style="red")
        raise typer.Exit(1)

    # Load package configuration
    try:
        with open(package_file, 'r') as f:
            packages_config = json.load(f)

        packages = packages_config.get('packages', [])

    except Exception as e:
        console.print(f"Error loading package file: {e}", style="red")
        raise typer.Exit(1)

    if not confirm:
        console.print(f"Will install {len(packages)} packages. Continue?", style="yellow")
        if not typer.confirm("Proceed?"):
            console.print("Installation cancelled", style="yellow")
            return

    installation_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "packages": [],
        "errors": []
    }

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        console=console
    ) as progress:

        task = progress.add_task("Installing packages...", total=len(packages))

        for i, package in enumerate(packages):
            package_name = package.get('name', 'Unknown')
            package_id = package.get('id', '')
            category = package.get('category', 'Unknown')

            progress.update(task, description=f"Installing {package_name}...")

            success = False
            error_msg = ""

            # Try winget first
            if use_winget and package_id:
                try:
                    cmd = ["winget", "install", package_id, "--accept-source-agreements", "--accept-package-agreements", "--silent"]
                    result = subprocess.run(cmd, capture_output=True, text=True, check=True)

                    installation_results["packages"].append({
                        "name": package_name,
                        "id": package_id,
                        "category": category,
                        "method": "winget",
                        "status": "success"
                    })

                    console.print(f"✓ Installed {package_name} (winget)", style="green")
                    success = True

                except subprocess.CalledProcessError as e:
                    error_msg = f"winget failed: {e.stderr}"

            # Try Chocolatey if winget failed
            if not success and use_chocolatey:
                try:
                    # Convert winget ID to Chocolatey package name (simplified)
                    choco_name = package_id.split('.')[-1].lower()

                    cmd = ["choco", "install", choco_name, "-y"]
                    result = subprocess.run(cmd, capture_output=True, text=True, check=True)

                    installation_results["packages"].append({
                        "name": package_name,
                        "id": package_id,
                        "category": category,
                        "method": "chocolatey",
                        "status": "success"
                    })

                    console.print(f"✓ Installed {package_name} (Chocolatey)", style="green")
                    success = True

                except subprocess.CalledProcessError as e:
                    error_msg += f" | chocolatey failed: {e.stderr}"

            if not success:
                installation_results["packages"].append({
                    "name": package_name,
                    "id": package_id,
                    "category": category,
                    "status": "failed"
                })

                installation_results["errors"].append({
                    "package": package_name,
                    "id": package_id,
                    "error": error_msg
                })

                console.print(f"✗ Failed to install {package_name}", style="red")

            progress.update(task, advance=1)

    # Save results
    results_file = Path("D:/DevOptimizer/logs/installation_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with open(results_file, 'w') as f:
        json.dump(installation_results, f, indent=2)

    # Display summary
    successful = len([p for p in installation_results["packages"] if p["status"] == "success"])
    failed = len([p for p in installation_results["packages"] if p["status"] == "failed"])

    console.print(f"\nInstallation Summary:", style="bold blue")
    console.print(f"Successful: {successful}")
    console.print(f"Failed: {failed}")

    if installation_results["errors"]:
        console.print(f"\nFailed installations:", style="red")
        for error in installation_results["errors"]:
            console.print(f"- {error['package']}: {error['error']}")

    console.print(f"✓ Results saved to: {results_file}", style="green")

@app.command()
def setup_python(
    version: str = typer.Option("3.12", "--version", "-v", help="Python version to install"),
    create_venv: bool = typer.Option(True, "--venv", help="Create virtual environment"),
    install_deps: bool = typer.Option(True, "--deps", help="Install Python dependencies")
):
    """Setup Python development environment"""

    setup_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "actions": [],
        "errors": []
    }

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:

        # Check if Python is already installed
        try:
            result = subprocess.run(["python", "--version"], capture_output=True, text=True, check=True)
            python_version = result.stdout.strip()
            setup_results["actions"].append({
                "action": "python_check",
                "status": "found",
                "version": python_version
            })
            console.print(f"✓ Python found: {python_version}", style="green")
        except subprocess.CalledProcessError:
            # Try to install Python using winget
            task = progress.add_task("Installing Python...", total=None)

            try:
                cmd = ["winget", "install", f"Python.Python.{version.replace('.', '')}", "--accept-source-agreements", "--accept-package-agreements", "--silent"]
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)

                setup_results["actions"].append({
                    "action": "python_install",
                    "status": "success",
                    "version": version
                })

                console.print(f"✓ Python {version} installed", style="green")

            except subprocess.CalledProcessError as e:
                setup_results["errors"].append({
                    "action": "python_install",
                    "error": str(e)
                })
                console.print(f"✗ Failed to install Python: {e}", style="red")
                return

        # Create virtual environment
        if create_venv:
            task = progress.add_task("Creating virtual environment...", total=None)

            venv_path = Path("D:/DevOptimizer/py/venv")

            try:
                subprocess.run(["python", "-m", "venv", str(venv_path)], check=True)

                setup_results["actions"].append({
                    "action": "venv_create",
                    "status": "success",
                    "path": str(venv_path)
                })

                console.print(f"✓ Virtual environment created: {venv_path}", style="green")

            except subprocess.CalledProcessError as e:
                setup_results["errors"].append({
                    "action": "venv_create",
                    "error": str(e)
                })
                console.print(f"✗ Failed to create virtual environment: {e}", style="red")

        # Install Python dependencies
        if install_deps:
            task = progress.add_task("Installing Python dependencies...", total=None)

            # Create requirements.txt
            requirements = [
                "typer>=0.9.0",
                "rich>=13.0.0",
                "psutil>=5.9.0",
                "pydantic>=2.0.0",
                "httpx>=0.24.0",
                "colorama>=0.4.6"
            ]

            requirements_file = Path("D:/DevOptimizer/py/requirements.txt")

            try:
                with open(requirements_file, 'w') as f:
                    f.write('\n'.join(requirements))

                # Install dependencies
                if create_venv and venv_path.exists():
                    pip_path = venv_path / "Scripts" / "pip.exe"
                    if pip_path.exists():
                        subprocess.run([str(pip_path), "install", "-r", str(requirements_file)], check=True)
                    else:
                        subprocess.run(["pip", "install", "-r", str(requirements_file)], check=True)
                else:
                    subprocess.run(["pip", "install", "-r", str(requirements_file)], check=True)

                setup_results["actions"].append({
                    "action": "deps_install",
                    "status": "success",
                    "requirements": requirements
                })

                console.print("✓ Python dependencies installed", style="green")

            except subprocess.CalledProcessError as e:
                setup_results["errors"].append({
                    "action": "deps_install",
                    "error": str(e)
                })
                console.print(f"✗ Failed to install dependencies: {e}", style="red")

    # Save results
    results_file = Path("D:/DevOptimizer/logs/python_setup_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with open(results_file, 'w') as f:
        json.dump(setup_results, f, indent=2)

    console.print(f"✓ Setup results saved to: {results_file}", style="green")

@app.command()
def setup_git(
    name: Optional[str] = typer.Option(None, "--name", "-n", help="Git user name"),
    email: Optional[str] = typer.Option(None, "--email", "-e", help="Git user email"),
    editor: str = typer.Option("code", "--editor", "-ed", help="Default Git editor")
):
    """Setup Git configuration"""

    setup_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "actions": [],
        "errors": []
    }

    # Check if Git is installed
    try:
        result = subprocess.run(["git", "--version"], capture_output=True, text=True, check=True)
        git_version = result.stdout.strip()
        setup_results["actions"].append({
            "action": "git_check",
            "status": "found",
            "version": git_version
        })
        console.print(f"✓ Git found: {git_version}", style="green")
    except subprocess.CalledProcessError:
        console.print("Git not found. Please install Git first.", style="red")
        raise typer.Exit(1)

    # Configure Git
    if name:
        try:
            subprocess.run(["git", "config", "--global", "user.name", name], check=True)
            setup_results["actions"].append({
                "action": "git_config_name",
                "status": "success",
                "value": name
            })
            console.print(f"✓ Git user name set to: {name}", style="green")
        except subprocess.CalledProcessError as e:
            setup_results["errors"].append({
                "action": "git_config_name",
                "error": str(e)
            })

    if email:
        try:
            subprocess.run(["git", "config", "--global", "user.email", email], check=True)
            setup_results["actions"].append({
                "action": "git_config_email",
                "status": "success",
                "value": email
            })
            console.print(f"✓ Git user email set to: {email}", style="green")
        except subprocess.CalledProcessError as e:
            setup_results["errors"].append({
                "action": "git_config_email",
                "error": str(e)
            })

    # Set default editor - sanitize input to prevent command injection
    # Only allow alphanumeric characters, dots, hyphens, underscores, and spaces
    if not re.match(r'^[a-zA-Z0-9._\-\s]+$', editor):
        console.print(f"Error: Invalid editor name. Only alphanumeric characters, dots, hyphens, underscores, and spaces are allowed.", style="red")
        setup_results["errors"].append({
            "action": "git_config_editor",
            "error": "Invalid editor name format"
        })
    else:
        try:
            subprocess.run(["git", "config", "--global", "core.editor", editor], check=True)
            setup_results["actions"].append({
                "action": "git_config_editor",
                "status": "success",
                "value": editor
            })
            console.print(f"✓ Git editor set to: {editor}", style="green")
        except subprocess.CalledProcessError as e:
            setup_results["errors"].append({
                "action": "git_config_editor",
                "error": str(e)
            })

    # Set useful Git configurations
    git_configs = [
        ("init.defaultBranch", "main"),
        ("pull.rebase", "true"),
        ("push.default", "simple"),
        ("core.autocrlf", "true"),
        ("core.safecrlf", "true")
    ]

    for config_key, config_value in git_configs:
        try:
            subprocess.run(["git", "config", "--global", config_key, config_value], check=True)
            setup_results["actions"].append({
                "action": f"git_config_{config_key.replace('.', '_')}",
                "status": "success",
                "value": config_value
            })
        except subprocess.CalledProcessError as e:
            setup_results["errors"].append({
                "action": f"git_config_{config_key.replace('.', '_')}",
                "error": str(e)
            })

    # Save results
    results_file = Path("D:/DevOptimizer/logs/git_setup_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with open(results_file, 'w') as f:
        json.dump(setup_results, f, indent=2)

    console.print(f"✓ Git setup results saved to: {results_file}", style="green")

@app.command()
def status():
    """Show bootstrap status and installed tools"""

    console.print("Development Environment Status", style="bold blue")

    # Check Python
    try:
        result = subprocess.run(["python", "--version"], capture_output=True, text=True, check=True)
        console.print(f"✓ Python: {result.stdout.strip()}", style="green")
    except subprocess.CalledProcessError:
        console.print("✗ Python: Not installed", style="red")

    # Check Git
    try:
        result = subprocess.run(["git", "--version"], capture_output=True, text=True, check=True)
        console.print(f"✓ Git: {result.stdout.strip()}", style="green")
    except subprocess.CalledProcessError:
        console.print("✗ Git: Not installed", style="red")

    # Check winget
    try:
        result = subprocess.run(["winget", "--version"], capture_output=True, text=True, check=True)
        console.print(f"✓ winget: {result.stdout.strip()}", style="green")
    except subprocess.CalledProcessError:
        console.print("✗ winget: Not available", style="red")

    # Check Chocolatey
    try:
        result = subprocess.run(["choco", "--version"], capture_output=True, text=True, check=True)
        console.print(f"✓ Chocolatey: {result.stdout.strip()}", style="green")
    except subprocess.CalledProcessError:
        console.print("✗ Chocolatey: Not installed", style="red")

    # Check virtual environment
    venv_path = Path("D:/DevOptimizer/py/venv")
    if venv_path.exists():
        console.print(f"✓ Virtual environment: {venv_path}", style="green")
    else:
        console.print("✗ Virtual environment: Not created", style="red")

    # Check requirements
    requirements_file = Path("D:/DevOptimizer/py/requirements.txt")
    if requirements_file.exists():
        console.print(f"✓ Requirements file: {requirements_file}", style="green")
    else:
        console.print("✗ Requirements file: Not found", style="red")
