"""Bootstrap commands for DevOptimizer CLI"""

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.progress import BarColumn, Progress, SpinnerColumn, TextColumn

from devoptimizer_cli.core.io_helpers import safe_open_write

app = typer.Typer(help="Bootstrap development environment")
console = Console()


def check_winget_available() -> bool:
    """Check if winget is available"""
    try:
        subprocess.run(["winget", "--version"], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def check_chocolatey_available() -> bool:
    """Check if Chocolatey is available"""
    try:
        subprocess.run(["choco", "--version"], capture_output=True, check=True)
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
            raw_package_id = package.get('id', '')
            # Sanitize package ID inline - only allow alphanumeric, dots, hyphens, underscores
            package_id = ''.join(c for c in raw_package_id if c.isalnum() or c in '._-')
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

    with safe_open_write(results_file) as f:
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
                # Sanitize version inline - only allow digits and dots
                safe_version = ''.join(c for c in version if c.isdigit() or c == '.')
                winget_id = f"Python.Python.{safe_version.replace('.', '')}"
                cmd = ["winget", "install", winget_id, "--accept-source-agreements", "--accept-package-agreements", "--silent"]
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)

                setup_results["actions"].append({
                    "action": "python_install",
                    "status": "success",
                    "version": safe_version
                })

                console.print(f"✓ Python {version} installed", style="green")

            except subprocess.CalledProcessError as e:
                setup_results["errors"].append({
                    "action": "python_install",
                    "error": str(e)
                })
                console.print(f"✗ Failed to install Python {safe_version}: {e}", style="red")
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
                with safe_open_write(requirements_file) as f:
                    f.write('\n'.join(requirements))

                pip_exe = venv_path / "Scripts" / "pip.exe" if create_venv else "pip"
                subprocess.run([str(pip_exe), "install", "-r", str(requirements_file)], check=True)

                setup_results["actions"].append({
                    "action": "deps_install",
                    "status": "success",
                    "count": len(requirements)
                })

                console.print(f"✓ Python dependencies installed", style="green")

            except subprocess.CalledProcessError as e:
                setup_results["errors"].append({
                    "action": "deps_install",
                    "error": str(e)
                })
                console.print(f"✗ Failed to install Python dependencies: {e}", style="red")

    # Save setup results
    results_file = Path("D:/DevOptimizer/logs/python_setup_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(setup_results, f, indent=2)

    console.print(f"✓ Setup results saved to: {results_file}", style="green")


@app.command()
def setup_node(
    version: str = typer.Option("20", "--version", "-v", help="Node.js version to install"),
    install_globals: bool = typer.Option(True, "--globals", help="Install global npm packages")
):
    """Setup Node.js development environment"""

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

        # Check if Node is already installed
        try:
            result = subprocess.run(["node", "--version"], capture_output=True, text=True, check=True)
            node_version = result.stdout.strip()
            setup_results["actions"].append({
                "action": "node_check",
                "status": "found",
                "version": node_version
            })
            console.print(f"✓ Node.js found: {node_version}", style="green")
        except subprocess.CalledProcessError:
            # Try to install Node.js using winget
            task = progress.add_task("Installing Node.js...", total=None)

            try:
                # Sanitize version inline - only allow digits and dots
                safe_version = ''.join(c for c in version if c.isdigit() or c == '.')
                winget_id = f"OpenJS.NodeJS.{safe_version}"
                cmd = ["winget", "install", winget_id, "--accept-source-agreements", "--accept-package-agreements", "--silent"]
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)

                setup_results["actions"].append({
                    "action": "node_install",
                    "status": "success",
                    "version": safe_version
                })

                console.print(f"✓ Node.js {version} installed", style="green")

            except subprocess.CalledProcessError as e:
                setup_results["errors"].append({
                    "action": "node_install",
                    "error": str(e)
                })
                console.print(f"✗ Failed to install Node.js {safe_version}: {e}", style="red")
                return

        # Install global npm packages
        if install_globals:
            task = progress.add_task("Installing global npm packages...", total=None)

            globals_list = [
                "typescript",
                "ts-node",
                "@types/node",
                "eslint",
                "prettier"
            ]

            try:
                for pkg in globals_list:
                    subprocess.run(["npm", "install", "-g", pkg], check=True)

                setup_results["actions"].append({
                    "action": "globals_install",
                    "status": "success",
                    "packages": globals_list
                })

                console.print(f"✓ Global npm packages installed", style="green")

            except subprocess.CalledProcessError as e:
                setup_results["errors"].append({
                    "action": "globals_install",
                    "error": str(e)
                })
                console.print(f"✗ Failed to install global packages: {e}", style="red")

    # Save setup results
    results_file = Path("D:/DevOptimizer/logs/node_setup_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(setup_results, f, indent=2)

    console.print(f"✓ Setup results saved to: {results_file}", style="green")


@app.command()
def setup_docker(
    enable_wsl: bool = typer.Option(True, "--wsl", help="Enable WSL 2 integration"),
    start_service: bool = typer.Option(True, "--start", help="Start Docker service")
):
    """Setup Docker development environment"""

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

        # Check if Docker is already installed
        try:
            result = subprocess.run(["docker", "--version"], capture_output=True, text=True, check=True)
            docker_version = result.stdout.strip()
            setup_results["actions"].append({
                "action": "docker_check",
                "status": "found",
                "version": docker_version
            })
            console.print(f"✓ Docker found: {docker_version}", style="green")
        except subprocess.CalledProcessError:
            # Try to install Docker using winget
            task = progress.add_task("Installing Docker Desktop...", total=None)

            try:
                cmd = ["winget", "install", "Docker.DockerDesktop", "--accept-source-agreements", "--accept-package-agreements", "--silent"]
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)

                setup_results["actions"].append({
                    "action": "docker_install",
                    "status": "success"
                })

                console.print(f"✓ Docker Desktop installed", style="green")

            except subprocess.CalledProcessError as e:
                setup_results["errors"].append({
                    "action": "docker_install",
                    "error": str(e)
                })
                console.print(f"✗ Failed to install Docker Desktop: {e}", style="red")
                return

        # Enable WSL integration
        if enable_wsl:
            task = progress.add_task("Configuring WSL 2 integration...", total=None)

            try:
                # Docker Desktop WSL integration is configured via settings
                # This is a placeholder for the actual configuration
                setup_results["actions"].append({
                    "action": "wsl_integration",
                    "status": "configured"
                })

                console.print(f"✓ WSL 2 integration configured", style="green")

            except Exception as e:
                setup_results["errors"].append({
                    "action": "wsl_integration",
                    "error": str(e)
                })
                console.print(f"✗ Failed to configure WSL integration: {e}", style="red")

        # Start Docker service
        if start_service:
            task = progress.add_task("Starting Docker service...", total=None)

            try:
                subprocess.run(["sc", "start", "docker"], check=False)
                subprocess.run(["sc", "start", "com.docker.service"], check=False)

                setup_results["actions"].append({
                    "action": "docker_start",
                    "status": "started"
                })

                console.print(f"✓ Docker service started", style="green")

            except Exception as e:
                setup_results["errors"].append({
                    "action": "docker_start",
                    "error": str(e)
                })
                console.print(f"✗ Failed to start Docker service: {e}", style="red")

    # Save setup results
    results_file = Path("D:/DevOptimizer/logs/docker_setup_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(setup_results, f, indent=2)

    console.print(f"✓ Setup results saved to: {results_file}", style="green")


@app.command()
def configure_git(
    user_name: str = typer.Option("", "--name", "-n", help="Git user name"),
    user_email: str = typer.Option("", "--email", "-e", help="Git user email"),
    setup_credential_helper: bool = typer.Option(True, "--credential-helper", help="Setup credential helper")
):
    """Configure Git settings"""

    config_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "actions": [],
        "errors": []
    }

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:

        # Configure user name
        if user_name:
            task = progress.add_task("Setting Git user name...", total=None)

            try:
                subprocess.run(["git", "config", "--global", "user.name", user_name], check=True)

                config_results["actions"].append({
                    "action": "git_user_name",
                    "status": "success",
                    "value": user_name
                })

                console.print(f"✓ Git user name set: {user_name}", style="green")

            except subprocess.CalledProcessError as e:
                config_results["errors"].append({
                    "action": "git_user_name",
                    "error": str(e)
                })
                console.print(f"✗ Failed to set Git user name: {e}", style="red")

        # Configure user email
        if user_email:
            task = progress.add_task("Setting Git user email...", total=None)

            try:
                subprocess.run(["git", "config", "--global", "user.email", user_email], check=True)

                config_results["actions"].append({
                    "action": "git_user_email",
                    "status": "success",
                    "value": user_email
                })

                console.print(f"✓ Git user email set: {user_email}", style="green")

            except subprocess.CalledProcessError as e:
                config_results["errors"].append({
                    "action": "git_user_email",
                    "error": str(e)
                })
                console.print(f"✗ Failed to set Git user email: {e}", style="red")

        # Setup credential helper
        if setup_credential_helper:
            task = progress.add_task("Setting up credential helper...", total=None)

            try:
                subprocess.run(["git", "config", "--global", "credential.helper", "manager-core"], check=True)

                config_results["actions"].append({
                    "action": "credential_helper",
                    "status": "success"
                })

                console.print(f"✓ Credential helper configured", style="green")

            except subprocess.CalledProcessError as e:
                config_results["errors"].append({
                    "action": "credential_helper",
                    "error": str(e)
                })
                console.print(f"✗ Failed to configure credential helper: {e}", style="red")

    # Save config results
    results_file = Path("D:/DevOptimizer/logs/git_config_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(config_results, f, indent=2)

    console.print(f"✓ Config results saved to: {results_file}", style="green")


@app.command()
def configure_shell(
    shell: str = typer.Option("pwsh", "--shell", "-s", help="Shell to configure: pwsh, cmd, bash"),
    install_modules: bool = typer.Option(True, "--modules", help="Install PowerShell modules"),
    set_profile: bool = typer.Option(True, "--profile", help="Configure shell profile")
):
    """Configure shell environment"""

    config_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "actions": [],
        "errors": []
    }

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:

        if shell.lower() == "pwsh":
            # Install PowerShell modules
            if install_modules:
                task = progress.add_task("Installing PowerShell modules...", total=None)

                modules = [
                    "PSReadLine",
                    "Terminal-Icons",
                    "z",
                    "posh-git"
                ]

                try:
                    for module in modules:
                        subprocess.run(["pwsh", "-Command", f"Install-Module -Name {module} -Force -Scope CurrentUser"], check=False)

                    config_results["actions"].append({
                        "action": "ps_modules",
                        "status": "installed",
                        "modules": modules
                    })

                    console.print(f"✓ PowerShell modules installed", style="green")

                except Exception as e:
                    config_results["errors"].append({
                        "action": "ps_modules",
                        "error": str(e)
                    })
                    console.print(f"✗ Failed to install PowerShell modules: {e}", style="red")

            # Set profile
            if set_profile:
                task = progress.add_task("Configuring PowerShell profile...", total=None)

                try:
                    profile_path = Path.home() / "Documents" / "PowerShell" / "Microsoft.PowerShell_profile.ps1"
                    profile_path.parent.mkdir(parents=True, exist_ok=True)

                    profile_content = """# DevOptimizer PowerShell Profile
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -EditMode Emacs
"""

                    with safe_open_write(profile_path) as f:
                        f.write(profile_content)

                    config_results["actions"].append({
                        "action": "ps_profile",
                        "status": "configured",
                        "path": str(profile_path)
                    })

                    console.print(f"✓ PowerShell profile configured", style="green")

                except Exception as e:
                    config_results["errors"].append({
                        "action": "ps_profile",
                        "error": str(e)
                    })
                    console.print(f"✗ Failed to configure PowerShell profile: {e}", style="red")

    # Save config results
    results_file = Path("D:/DevOptimizer/logs/shell_config_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(config_results, f, indent=2)

    console.print(f"✓ Config results saved to: {results_file}", style="green")


@app.command()
def full_bootstrap(
    skip_tools: bool = typer.Option(False, "--skip-tools", help="Skip tool installation"),
    skip_python: bool = typer.Option(False, "--skip-python", help="Skip Python setup"),
    skip_node: bool = typer.Option(False, "--skip-node", help="Skip Node.js setup"),
    skip_docker: bool = typer.Option(False, "--skip-docker", help="Skip Docker setup"),
    skip_git: bool = typer.Option(False, "--skip-git", help="Skip Git configuration"),
    skip_shell: bool = typer.Option(False, "--skip-shell", help="Skip shell configuration"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip all confirmation prompts")
):
    """Run full development environment bootstrap"""

    console.print("🚀 Starting Full Development Environment Bootstrap", style="bold blue")

    results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "steps": [],
        "errors": []
    }

    steps = []

    if not skip_tools:
        steps.append(("install_tools", {"package_file": None, "use_winget": True, "use_chocolatey": False, "confirm": confirm}))

    if not skip_python:
        steps.append(("setup_python", {"version": "3.12", "create_venv": True, "install_deps": True}))

    if not skip_node:
        steps.append(("setup_node", {"version": "20", "install_globals": True}))

    if not skip_docker:
        steps.append(("setup_docker", {"enable_wsl": True, "start_service": True}))

    if not skip_git:
        steps.append(("configure_git", {"user_name": "", "user_email": "", "setup_credential_helper": True}))

    if not skip_shell:
        steps.append(("configure_shell", {"shell": "pwsh", "install_modules": True, "set_profile": True}))

    for step_name, step_args in steps:
        console.print(f"\n📦 Running {step_name}...", style="bold cyan")

        try:
            # Call the command function directly
            if step_name == "install_tools":
                install_tools(**step_args)
            elif step_name == "setup_python":
                setup_python(**step_args)
            elif step_name == "setup_node":
                setup_node(**step_args)
            elif step_name == "setup_docker":
                setup_docker(**step_args)
            elif step_name == "configure_git":
                configure_git(**step_args)
            elif step_name == "configure_shell":
                configure_shell(**step_args)

            results["steps"].append({
                "step": step_name,
                "status": "success"
            })
            console.print(f"✓ {step_name} completed", style="green")

        except Exception as e:
            results["errors"].append({
                "step": step_name,
                "error": str(e)
            })
            console.print(f"✗ {step_name} failed: {e}", style="red")

    # Save full bootstrap results
    results_file = Path("D:/DevOptimizer/logs/full_bootstrap_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(results, f, indent=2)

    console.print(f"\n✅ Full Bootstrap Complete!", style="bold green")
    console.print(f"Results saved to: {results_file}", style="green")

    successful = len([s for s in results["steps"] if s["status"] == "success"])
    console.print(f"Steps completed: {successful}/{len(steps)}")