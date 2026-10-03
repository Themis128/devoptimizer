"""
Security hardening commands
"""

import json
import subprocess
import sys
import shlex
import platform
from pathlib import Path
from typing import Optional, List

from devoptimizer_cli.paths import safe_open_write
import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn

app = typer.Typer(name="security", help="Security hardening and analysis")
console = Console()

def check_sysinternals_available() -> bool:
    """Check if Sysinternals tools are available"""
    sysinternals_path = Path("D:/DevOptimizer/bin/sysinternals")
    return sysinternals_path.exists() and any(sysinternals_path.glob("*.exe"))

@app.command()
def audit(
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file for audit results"),
    include_processes: bool = typer.Option(True, "--processes", help="Include process analysis"),
    include_services: bool = typer.Option(True, "--services", help="Include service analysis"),
    include_startup: bool = typer.Option(True, "--startup", help="Include startup program analysis"),
    include_defender: bool = typer.Option(True, "--defender", help="Include Windows Defender analysis")
):
    """Perform comprehensive security audit"""

    if not output:
        output = Path("D:/DevOptimizer/security/security_audit.json")

    # Validate output path to prevent arbitrary file write
    output = Path(output).resolve()
    if not str(output).startswith(str(Path("D:/DevOptimizer").resolve())):
        console.print("Error: Output path must be within DevOptimizer directory", style="red")
        raise typer.Exit(1)

    output.parent.mkdir(parents=True, exist_ok=True)

    audit_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "system_info": {},
        "processes": [],
        "services": [],
        "startup_programs": [],
        "defender_status": {},
        "recommendations": [],
        "errors": []
    }

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:

        # System information
        task = progress.add_task("Gathering system information...", total=None)

        try:
            # Get system info - using safe subprocess calls without shell=True
            hostname_result = subprocess.run(["hostname"], capture_output=True, text=True, check=True)
            os_arch_result = subprocess.run(["wmic", "os", "get", "OSArchitecture"], capture_output=True, text=True, check=True)
            uptime_result = subprocess.run(["wmic", "os", "get", "LastBootUpTime"], capture_output=True, text=True, check=True)

            # Use platform module for OS version instead of shell command
            os_version = f"{platform.system()} {platform.release()} {platform.version()}"

            system_info = {
                "hostname": hostname_result.stdout.strip(),
                "os_version": os_version,
                "architecture": os_arch_result.stdout.strip(),
                "uptime": uptime_result.stdout.strip()
            }

            audit_results["system_info"] = system_info

        except Exception as e:
            audit_results["errors"].append({
                "action": "system_info",
                "error": str(e)
            })

        progress.update(task, completed=100)

        # Process analysis
        if include_processes:
            task = progress.add_task("Analyzing running processes...", total=None)

            try:
                # Get process list
                result = subprocess.run(
                    ["wmic", "process", "get", "processid,name,executablepath,commandline", "/format:csv"],
                    capture_output=True,
                    text=True,
                    check=True
                )

                processes = []
                for line in result.stdout.split('\n'):
                    if line.strip() and not line.startswith('Node'):
                        parts = line.split(',')
                        if len(parts) >= 4:
                            processes.append({
                                "pid": parts[1].strip(),
                                "name": parts[2].strip(),
                                "path": parts[3].strip(),
                                "commandline": parts[4].strip() if len(parts) > 4 else ""
                            })

                audit_results["processes"] = processes[:100]  # Limit to first 100

            except Exception as e:
                audit_results["errors"].append({
                    "action": "process_analysis",
                    "error": str(e)
                })

            progress.update(task, completed=100)

        # Service analysis
        if include_services:
            task = progress.add_task("Analyzing services...", total=None)

            try:
                # Get service list
                result = subprocess.run(
                    ["wmic", "service", "get", "name,state,startmode,pathname", "/format:csv"],
                    capture_output=True,
                    text=True,
                    check=True
                )

                services = []
                for line in result.stdout.split('\n'):
                    if line.strip() and not line.startswith('Node'):
                        parts = line.split(',')
                        if len(parts) >= 4:
                            services.append({
                                "name": parts[1].strip(),
                                "state": parts[2].strip(),
                                "start_mode": parts[3].strip(),
                                "path": parts[4].strip() if len(parts) > 4 else ""
                            })

                audit_results["services"] = services

            except Exception as e:
                audit_results["errors"].append({
                    "action": "service_analysis",
                    "error": str(e)
                })

            progress.update(task, completed=100)

        # Startup program analysis
        if include_startup:
            task = progress.add_task("Analyzing startup programs...", total=None)

            try:
                # Get startup programs
                result = subprocess.run(
                    ["wmic", "startup", "get", "name,command,location", "/format:csv"],
                    capture_output=True,
                    text=True,
                    check=True
                )

                startup_programs = []
                for line in result.stdout.split('\n'):
                    if line.strip() and not line.startswith('Node'):
                        parts = line.split(',')
                        if len(parts) >= 3:
                            startup_programs.append({
                                "name": parts[1].strip(),
                                "command": parts[2].strip(),
                                "location": parts[3].strip() if len(parts) > 3 else ""
                            })

                audit_results["startup_programs"] = startup_programs

            except Exception as e:
                audit_results["errors"].append({
                    "action": "startup_analysis",
                    "error": str(e)
                })

            progress.update(task, completed=100)

        # Windows Defender analysis
        if include_defender:
            task = progress.add_task("Analyzing Windows Defender...", total=None)

            try:
                # Get Defender status
                result = subprocess.run(
                    ["powershell", "-Command", "Get-MpComputerStatus"],
                    capture_output=True,
                    text=True,
                    check=True
                )

                defender_info = {}
                for line in result.stdout.split('\n'):
                    if ':' in line:
                        key, value = line.split(':', 1)
                        defender_info[key.strip()] = value.strip()

                audit_results["defender_status"] = defender_info

            except Exception as e:
                audit_results["errors"].append({
                    "action": "defender_analysis",
                    "error": str(e)
                })

            progress.update(task, completed=100)

    # Generate recommendations
    recommendations = []

    # Check for suspicious processes
    suspicious_processes = []
    for process in audit_results.get("processes", []):
        if any(keyword in process.get("name", "").lower() for keyword in ["miner", "crypto", "bitcoin"]):
            suspicious_processes.append(process)

    if suspicious_processes:
        recommendations.append({
            "category": "Processes",
            "severity": "High",
            "issue": "Suspicious processes detected",
            "details": suspicious_processes,
            "action": "Investigate and remove if malicious"
        })

    # Check for unnecessary services
    unnecessary_services = []
    for service in audit_results.get("services", []):
        if service.get("start_mode") == "Auto" and service.get("state") == "Running":
            service_name = service.get("name", "").lower()
            if any(keyword in service_name for keyword in ["fax", "xbox", "tablet"]):
                unnecessary_services.append(service)

    if unnecessary_services:
        recommendations.append({
            "category": "Services",
            "severity": "Medium",
            "issue": "Unnecessary services running",
            "details": unnecessary_services,
            "action": "Consider disabling unused services"
        })

    # Check startup programs
    if len(audit_results.get("startup_programs", [])) > 10:
        recommendations.append({
            "category": "Startup",
            "severity": "Medium",
            "issue": "Too many startup programs",
            "details": f"{len(audit_results['startup_programs'])} startup programs found",
            "action": "Review and disable unnecessary startup programs"
        })

    audit_results["recommendations"] = recommendations

    # Save results
    with safe_open_write(output) as f:
        json.dump(audit_results, f, indent=2)

    # Display summary
    console.print(f"\nSecurity Audit Summary:", style="bold blue")
    console.print(f"Processes analyzed: {len(audit_results.get('processes', []))}")
    console.print(f"Services analyzed: {len(audit_results.get('services', []))}")
    console.print(f"Startup programs: {len(audit_results.get('startup_programs', []))}")
    console.print(f"Recommendations: {len(recommendations)}")
    console.print(f"Errors: {len(audit_results['errors'])}")

    # Show high priority recommendations
    high_priority = [r for r in recommendations if r.get('severity') == 'High']
    if high_priority:
        console.print(f"\nHigh Priority Issues:", style="bold red")
        for rec in high_priority:
            console.print(f"- {rec['issue']}")

    console.print(f"✓ Audit results saved to: {output}", style="green")

@app.command()
def harden(
    disable_unnecessary_services: bool = typer.Option(True, "--services", help="Disable unnecessary services"),
    configure_defender: bool = typer.Option(True, "--defender", help="Configure Windows Defender"),
    set_firewall_rules: bool = typer.Option(True, "--firewall", help="Set firewall rules"),
    configure_updates: bool = typer.Option(True, "--updates", help="Configure Windows Update"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation prompts")
):
    """Apply security hardening measures"""

    if not confirm:
        console.print("This will apply security hardening measures. Continue?", style="yellow")
        if not typer.confirm("Proceed?"):
            console.print("Hardening cancelled", style="yellow")
            return

    hardening_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "actions": [],
        "errors": []
    }

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:

        # Disable unnecessary services
        if disable_unnecessary_services:
            task = progress.add_task("Disabling unnecessary services...", total=None)

            services_to_disable = [
                "Fax",
                "TabletInputService",
                "XblAuthManager",
                "XblGameSave",
                "XboxNetApiSvc",
                "XboxGipSvc",
                "XboxLiveAuthManager"
            ]

            for service in services_to_disable:
                try:
                    # Check if service exists and is running
                    result = subprocess.run(
                        ["sc", "query", service],
                        capture_output=True,
                        text=True,
                        check=False
                    )

                    if "RUNNING" in result.stdout:
                        # Stop and disable service
                        subprocess.run(["sc", "stop", service], capture_output=True, text=True, check=False)
                        subprocess.run(["sc", "config", service, "start=", "disabled"], capture_output=True, text=True, check=False)

                        hardening_results["actions"].append({
                            "action": "disable_service",
                            "service": service,
                            "status": "success"
                        })

                        console.print(f"✓ Disabled service: {service}", style="green")

                except Exception as e:
                    hardening_results["errors"].append({
                        "action": "disable_service",
                        "service": service,
                        "error": str(e)
                    })

            progress.update(task, completed=100)

        # Configure Windows Defender
        if configure_defender:
            task = progress.add_task("Configuring Windows Defender...", total=None)

            # Use safe subprocess calls with argument lists instead of shell=True
            defender_commands = [
                # Enable real-time protection
                ["powershell", "-Command", "Set-MpPreference -DisableRealtimeMonitoring $false"],
                # Enable cloud protection
                ["powershell", "-Command", "Set-MpPreference -EnableCloudProtection $true"],
                # Set scan schedule
                ["powershell", "-Command", "Set-MpPreference -ScanScheduleDay 1"],
                # Enable behavior monitoring
                ["powershell", "-Command", "Set-MpPreference -DisableBehaviorMonitoring $false"],
                # Enable intrusion prevention
                ["powershell", "-Command", "Set-MpPreference -DisableIntrusionPreventionSystem $false"]
            ]

            for cmd in defender_commands:
                try:
                    subprocess.run(cmd, capture_output=True, text=True, check=True)

                    hardening_results["actions"].append({
                        "action": "defender_config",
                        "command": " ".join(cmd),
                        "status": "success"
                    })

                except subprocess.CalledProcessError as e:
                    hardening_results["errors"].append({
                        "action": "defender_config",
                        "command": cmd,
                        "error": str(e)
                    })

            progress.update(task, completed=100)

        # Configure firewall
        if set_firewall_rules:
            task = progress.add_task("Configuring firewall rules...", total=None)

            # Use safe subprocess calls with argument lists instead of shell=True
            firewall_commands = [
                # Enable firewall for all profiles
                ["netsh", "advfirewall", "set", "allprofiles", "state", "on"],
                # Block incoming connections by default
                ["netsh", "advfirewall", "set", "allprofiles", "firewallpolicy", "blockinbound,allowoutbound"],
                # Enable logging
                ["netsh", "advfirewall", "set", "allprofiles", "logging", "filename", "%systemroot%\\system32\\logfiles\\firewall\\pfirewall.log"],
                ["netsh", "advfirewall", "set", "allprofiles", "logging", "maxfilesize", "4096"],
                ["netsh", "advfirewall", "set", "allprofiles", "logging", "droppedconnections", "enable"]
            ]

            for cmd in firewall_commands:
                try:
                    subprocess.run(cmd, capture_output=True, text=True, check=True)

                    hardening_results["actions"].append({
                        "action": "firewall_config",
                        "command": " ".join(cmd),
                        "status": "success"
                    })

                except subprocess.CalledProcessError as e:
                    hardening_results["errors"].append({
                        "action": "firewall_config",
                        "command": cmd,
                        "error": str(e)
                    })

            progress.update(task, completed=100)

        # Configure Windows Update
        if configure_updates:
            task = progress.add_task("Configuring Windows Update...", total=None)

            # Use safe subprocess calls with argument lists instead of shell=True
            update_commands = [
                # Enable automatic updates
                ["reg", "add", "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU", "/v", "NoAutoUpdate", "/t", "REG_DWORD", "/d", "0", "/f"],
                # Set update schedule
                ["reg", "add", "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU", "/v", "ScheduledInstallDay", "/t", "REG_DWORD", "/d", "1", "/f"],
                ["reg", "add", "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU", "/v", "ScheduledInstallTime", "/t", "REG_DWORD", "/d", "3", "/f"],
                # Enable driver updates
                ["reg", "add", "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate", "/v", "ExcludeWUDriversInQualityUpdate", "/t", "REG_DWORD", "/d", "0", "/f"]
            ]

            for cmd in update_commands:
                try:
                    subprocess.run(cmd, capture_output=True, text=True, check=True)

                    hardening_results["actions"].append({
                        "action": "update_config",
                        "command": " ".join(cmd),
                        "status": "success"
                    })

                except subprocess.CalledProcessError as e:
                    hardening_results["errors"].append({
                        "action": "update_config",
                        "command": cmd,
                        "error": str(e)
                    })

            progress.update(task, completed=100)

    # Save results
    results_file = Path("D:/DevOptimizer/security/hardening_results.json")
    results_file.parent.mkdir(parents=True, exist_ok=True)

    with safe_open_write(results_file) as f:
        json.dump(hardening_results, f, indent=2)

    # Display summary
    console.print(f"\nSecurity Hardening Summary:", style="bold blue")

    total_actions = len(hardening_results["actions"])
    total_errors = len(hardening_results["errors"])

    console.print(f"Actions completed: {total_actions}")
    console.print(f"Errors: {total_errors}")

    if hardening_results["errors"]:
        console.print(f"\nErrors encountered:", style="red")
        for error in hardening_results["errors"]:
            console.print(f"- {error['action']}: {error.get('error', 'Unknown error')}")

    console.print(f"✓ Hardening results saved to: {results_file}", style="green")

@app.command()
def scan_malware(
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file for scan results"),
    full_scan: bool = typer.Option(False, "--full", "-f", help="Perform full system scan"),
    custom_path: Optional[Path] = typer.Option(None, "--path", "-p", help="Custom path to scan")
):
    """Perform malware scan using Windows Defender"""

    if not output:
        output = Path("D:/DevOptimizer/security/malware_scan.json")

    output.parent.mkdir(parents=True, exist_ok=True)

    scan_results = {
        "timestamp": "2025-04-10T00:00:00Z",
        "scan_type": "full" if full_scan else "quick",
        "scan_path": str(custom_path) if custom_path else "system",
        "threats_found": [],
        "scan_summary": {},
        "errors": []
    }

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:

        task = progress.add_task("Running malware scan...", total=None)

        try:
            # Build scan command
            if custom_path:
                scan_cmd = ["MpCmdRun.exe", "-Scan", "-ScanType", "3", "-File", str(custom_path)]
            elif full_scan:
                scan_cmd = ["MpCmdRun.exe", "-Scan", "-ScanType", "2"]
            else:
                scan_cmd = ["MpCmdRun.exe", "-Scan", "-ScanType", "1"]

            # Run scan
            result = subprocess.run(scan_cmd, capture_output=True, text=True, check=True)

            # Parse results
            scan_output = result.stdout
            scan_results["scan_summary"]["raw_output"] = scan_output

            # Extract threat count
            if "Threats found:" in scan_output:
                threat_count = 0
                for line in scan_output.split('\n'):
                    if "Threats found:" in line:
                        try:
                            threat_count = int(line.split(":")[1].strip())
                            break
                        except:
                            pass

                scan_results["scan_summary"]["threats_found"] = threat_count

            # Get detailed threat information
            if scan_results["scan_summary"].get("threats_found", 0) > 0:
                try:
                    threat_result = subprocess.run(
                        ["MpCmdRun.exe", "-GetFiles"],
                        capture_output=True,
                        text=True,
                        check=True
                    )

                    scan_results["threats_found"] = threat_result.stdout.split('\n')

                except subprocess.CalledProcessError:
                    pass

            progress.update(task, completed=100)

            console.print("✓ Malware scan completed", style="green")

        except subprocess.CalledProcessError as e:
            scan_results["errors"].append({
                "action": "malware_scan",
                "error": str(e)
            })
            console.print(f"✗ Malware scan failed: {e}", style="red")

        except Exception as e:
            scan_results["errors"].append({
                "action": "malware_scan",
                "error": str(e)
            })
            console.print(f"✗ Unexpected error during scan: {e}", style="red")

    # Save results
    with safe_open_write(output) as f:
        json.dump(scan_results, f, indent=2)

    # Display summary
    console.print(f"\nMalware Scan Summary:", style="bold blue")
    console.print(f"Scan type: {scan_results['scan_type']}")
    console.print(f"Scan path: {scan_results['scan_path']}")
    console.print(f"Threats found: {scan_results['scan_summary'].get('threats_found', 0)}")

    if scan_results["threats_found"]:
        console.print(f"\nThreats detected:", style="red")
        for threat in scan_results["threats_found"][:5]:  # Show first 5
            console.print(f"- {threat}")

    console.print(f"✓ Scan results saved to: {output}", style="green")
