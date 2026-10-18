#!/usr/bin/env python3
"""
ADVANCED-DIAGNOSTICS.py - Python version of the Advanced Diagnostics Suite
Secure version with proper path validation to prevent traversal attacks.
"""

import os
import sys
import json
import subprocess
import datetime
import platform
from pathlib import Path

def is_safe_path(path, base_path):
    """Check if a path is within the base path to prevent directory traversal."""
    try:
        # Convert to Path objects and resolve to absolute paths
        path_obj = Path(path).resolve()
        base_obj = Path(base_path).resolve()
        
        # Check if the path is within the base path
        return base_obj in path_obj.parents or base_obj == path_obj
    except Exception:
        return False

def safe_join(base_path, *paths):
    """Safely join paths and ensure the result is within base_path."""
    try:
        base = Path(base_path).resolve()
        full_path = (base / Path(*paths)).resolve()
        
        # Check if the joined path is still within base
        if base in full_path.parents or base == full_path:
            return str(full_path)
        else:
            return None
    except Exception:
        return None

def main():
    """Main function - secure version with full diagnostics functionality."""
    print("ADVANCED-DIAGNOSTICS Python version")
    print("Secure diagnostic suite with path validation")
    
    # Set the base directory for all operations
    DEVOPT_HOME = Path(r'D:\DevOptimizer').resolve()
    
    # Basic system info
    print(f"Computer: {platform.node()}")
    print(f"Platform: {platform.system()} {platform.release()}")
    print(f"Python: {platform.python_version()}")
    
    # Initialize results
    diagnostic_results = {
        "Timestamp": datetime.datetime.now().isoformat(),
        "PowerShellVersion": get_powershell_version(),
        "IsAdmin": check_admin_status(),
        "ComputerName": platform.node(),
        "UserName": os.getenv('USERNAME', 'unknown')
    }
    
    # Run diagnostic tests (simplified for security)
    try:
        # PowerShell integration test
        diagnostic_results["PowerShellIntegration"] = test_powershell_integration(DEVOPT_HOME)
        
        # System resources test
        diagnostic_results["SystemResources"] = test_system_resources()
        
        # File system structure test
        diagnostic_results["FileSystemStructure"] = test_file_system_structure(DEVOPT_HOME)
        
        # Script integrity test
        diagnostic_results["ScriptIntegrity"] = test_script_integrity(DEVOPT_HOME)
        
    except Exception as e:
        print(f"Error during diagnostics: {e}")
        diagnostic_results["Error"] = str(e)
    
    # Output results
    print("\n=== Diagnostic Results ===")
    print(json.dumps(diagnostic_results, indent=2, default=str))
    
    return 0

def get_powershell_version():
    """Get the PowerShell version."""
    try:
        result = subprocess.run(
            ['powershell', '-Command', '$PSVersionTable.PSVersion.ToString()'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    return "Unknown"

def check_admin_status():
    """Check if the current process has administrator privileges."""
    try:
        # For Windows, we can check via PowerShell
        result = subprocess.run(
            ['powershell', '-Command', 
             '[System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            return result.stdout.strip().lower() == 'true'
    except Exception:
        pass
    # Fallback method
    return os.getuid() == 0 if hasattr(os, 'getuid') else False

def test_powershell_integration(base_path):
    """Test PowerShell integration capabilities securely."""
    results = {}
    
    # Test execution policy
    try:
        result = subprocess.run(
            ['powershell', '-Command', 'Get-ExecutionPolicy'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            results["ExecutionPolicy"] = {
                "Value": result.stdout.strip(),
                "Success": True
            }
        else:
            results["ExecutionPolicy"] = {
                "Value": None,
                "Success": False,
                "Error": result.stderr.strip()
            }
    except Exception as e:
        results["ExecutionPolicy"] = {
            "Value": None,
            "Success": False,
            "Error": str(e)
        }
    
    # Test module loading
    try:
        result = subprocess.run(
            ['powershell', '-Command', 'Get-Module -ListAvailable | Where-Object { $_.Name -match "Microsoft|Windows" } | Measure-Object'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout.strip():
            try:
                count = int(result.stdout.strip())
                results["AvailableModules"] = {
                    "Count": count,
                    "Success": True
                }
            except ValueError:
                results["AvailableModules"] = {
                    "Count": 0,
                    "Success": False,
                    "Error": "Invalid count output"
                }
        else:
            results["AvailableModules"] = {
                "Count": 0,
                "Success": False,
                "Error": result.stderr.strip() if result.returncode != 0 else "No output"
            }
    except Exception as e:
        results["AvailableModules"] = {
            "Count": 0,
            "Success": False,
            "Error": str(e)
        }
    
    # Test .NET Framework version
    try:
        result = subprocess.run(
            ['powershell', '-Command', '[System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            results["DotNetVersion"] = {
                "Value": result.stdout.strip(),
                "Success": True
            }
        else:
            results["DotNetVersion"] = {
                "Value": None,
                "Success": False,
                "Error": result.stderr.strip()
            }
    except Exception as e:
        results["DotNetVersion"] = {
            "Value": None,
            "Success": False,
            "Error": str(e)
        }
    
    return results

def test_system_resources():
    """Analyze system resources and performance."""
    results = {}
    
    # CPU Information
    try:
        result = subprocess.run(
            ['powershell', '-Command', 'Get-WmiObject -Class Win32_Processor | Select-Object -First 1 | ConvertTo-JSON'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout.strip():
            try:
                cpu_data = json.loads(result.stdout.strip())
                results["CPU"] = {
                    "Name": cpu_data.get("Name", "Unknown"),
                    "Cores": cpu_data.get("NumberOfCores", 0),
                    "LogicalProcessors": cpu_data.get("NumberOfLogicalProcessors", 0),
                    "MaxClockSpeed": cpu_data.get("MaxClockSpeed", 0)
                }
            except (json.JSONDecodeError, KeyError):
                results["CPU"] = {
                    "Name": "Unknown",
                    "Cores": 0,
                    "LogicalProcessors": 0,
                    "MaxClockSpeed": 0
                }
        else:
            results["CPU"] = {
                "Name": "Unknown",
                "Cores": 0,
                "LogicalProcessors": 0,
                "MaxClockSpeed": 0
            }
    except Exception as e:
        results["CPU"] = {
            "Name": "Unknown",
            "Cores": 0,
            "LogicalProcessors": 0,
            "MaxClockSpeed": 0
        }
    
    # Memory Information
    try:
        result = subprocess.run(
            ['powershell', '-Command', 'Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory | ConvertTo-JSON'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout.strip():
            try:
                mem_data = json.loads(result.stdout.strip())
                total_visible = float(mem_data.get("TotalVisibleMemorySize", 0))
                free_physical = float(mem_data.get("FreePhysicalMemory", 0))
                
                total_gb = round(total_visible / 1024 / 1024, 2)
                free_gb = round(free_physical / 1024 / 1024, 2)
                used_gb = total_gb - free_gb
                usage_percent = round((used_gb / total_gb) * 100, 2) if total_gb > 0 else 0
                
                results["Memory"] = {
                    "TotalGB": total_gb,
                    "FreeGB": free_gb,
                    "UsedGB": used_gb,
                    "UsagePercent": usage_percent
                }
            except (json.JSONDecodeError, ValueError, KeyError):
                results["Memory"] = {
                    "TotalGB": 0,
                    "FreeGB": 0,
                    "UsedGB": 0,
                    "UsagePercent": 0
                }
        else:
            results["Memory"] = {
                "TotalGB": 0,
                "FreeGB": 0,
                "UsedGB": 0,
                "UsagePercent": 0
            }
    except Exception as e:
        results["Memory"] = {
            "TotalGB": 0,
            "FreeGB": 0,
            "UsedGB": 0,
            "UsagePercent": 0
        }
    
    # Disk Information
    try:
        result = subprocess.run(
            ['powershell', '-Command', 'Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,Size,FreeSpace | ConvertTo-JSON'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout.strip():
            try:
                disks_data = json.loads(result.stdout.strip())
                if not isinstance(disks_data, list):
                    disks_data = [disks_data] if disks_data else []
                
                disks = []
                for disk in disks_data:
                    try:
                        size = float(disk.get("Size", 0))
                        free_space = float(disk.get("FreeSpace", 0))
                        disk_id = disk.get("DeviceID", "Unknown")
                        
                        total_gb = round(size / 1024 / 1024 / 1024, 2)
                        free_gb = round(free_space / 1024 / 1024 / 1024, 2)
                        usage_percent = round(((total_gb - free_gb) / total_gb) * 100, 2) if total_gb > 0 else 0
                        
                        disks.append({
                            "Drive": disk_id,
                            "TotalGB": total_gb,
                            "FreeGB": free_gb,
                            "UsagePercent": usage_percent
                        })
                    except (ValueError, KeyError):
                        continue
                
                results["Disks"] = disks
            except (json.JSONDecodeError, TypeError):
                results["Disks"] = []
        else:
            results["Disks"] = []
    except Exception as e:
        results["Disks"] = []
    
    return results

def test_file_system_structure(base_path):
    """Analyze DevOptimizer file system structure securely."""
    results = {
        "ExpectedDirectories": {},
        "FileInventory": {},
        "Issues": []
    }
    
    expected_directories = [
        "scripts", "logs", "config", "backups", "templates", 
        "categories", "generators", "registry", "docs", "tools"
    ]
    
    # Check expected directories
    for dir_name in expected_directories:
        dir_path = safe_join(base_path, dir_name)
        if dir_path and os.path.isdir(dir_path):
            try:
                item_count = len([item for item in Path(dir_path).iterdir()])
                results["ExpectedDirectories"][dir_name] = {
                    "Exists": True,
                    "ItemCount": item_count
                }
            except Exception:
                results["ExpectedDirectories"][dir_name] = {
                    "Exists": True,
                    "ItemCount": 0
                }
        else:
            results["ExpectedDirectories"][dir_name] = {
                "Exists": False,
                "ItemCount": 0
            }
            results["Issues"].append(f"Missing directory: {dir_name}")
    
    # File inventory
    file_types = ["*.bat", "*.ps1", "*.json", "*.md", "*.txt", "*.log"]
    for file_type in file_types:
        extension = file_type.replace("*", "")
        try:
            files = list(base_path.glob(file_type))
            total_size = sum(f.stat().st_size for f in files if f.is_file())
            
            results["FileInventory"][extension] = {
                "Count": len(files),
                "TotalSize": total_size
            }
        except Exception:
            results["FileInventory"][extension] = {
                "Count": 0,
                "TotalSize": 0
            }
    
    return results

def test_script_integrity(base_path):
    """Test script integrity and dependencies securely."""
    results = {
        "BATFiles": {},
        "PowerShellFiles": {},
        "Issues": []
    }
    
    # Test BAT files
    bat_files = list(base_path.glob("*.bat")) + list(base_path.glob("*.cmd"))
    for bat_file in bat_files:
        # Ensure the file is within base path
        if not is_safe_path(bat_file, base_path):
            continue
            
        try:
            stat = bat_file.stat()
            accessible = os.access(bat_file, os.R_OK)
            
            analysis = {
                "Name": bat_file.name,
                "Size": stat.st_size,
                "LastModified": datetime.datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "Accessible": accessible,
                "Locked": False,  # Simplified - Windows file locking check would be more complex
                "HasEchoOff": False,
                "HasTitle": False,
                "HasPowerShellCall": False,
                "LineCount": 0
            }
            
            # Try to read content for analysis
            if accessible:
                try:
                    content = bat_file.read_text(encoding='utf-8', errors='ignore')
                    lines = content.splitlines()
                    analysis["LineCount"] = len(lines)
                    analysis["HasEchoOff"] = any("@echo off" in line.lower() for line in lines)
                    analysis["HasTitle"] = any("title " in line for line in lines)
                    analysis["HasPowerShellCall"] = any("powershell" in line.lower() for line in lines)
                except Exception:
                    pass  # Keep default values
            
            results["BATFiles"][bat_file.name] = analysis
            
        except Exception as e:
            results["Issues"].append(f"Error processing {bat_file.name}: {str(e)}")
    
    # Test PowerShell files
    ps1_files = list(base_path.glob("*.ps1"))
    for ps1_file in ps1_files:
        # Ensure the file is within base path
        if not is_safe_path(ps1_file, base_path):
            continue
            
        try:
            stat = ps1_file.stat()
            accessible = os.access(ps1_file, os.R_OK)
            
            analysis = {
                "Name": ps1_file.name,
                "Size": stat.st_size,
                "LastModified": datetime.datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "Accessible": accessible,
                "Locked": False,  # Simplified
            }
            
            if accessible:
                try:
                    # Try to parse the PowerShell file for syntax errors
                    result = subprocess.run(
                        ['powershell', '-Command', f"& {{ param($path) try {{ [System.Management.Automation.PSParser]::Tokenize((Get-Content $path -Raw), [ref]$errors) | Out-Null; $errors.Count }} catch {{ -1 }} }}", str(ps1_file)],
                        capture_output=True, text=True, timeout=10
                    )
                    if result.returncode == 0 and result.stdout.strip().lstrip('-').isdigit():
                        error_count = int(result.stdout.strip())
                        analysis["SyntaxValid"] = error_count == 0
                        analysis["SyntaxErrors"] = error_count
                    else:
                        analysis["SyntaxValid"] = False
                        analysis["SyntaxErrors"] = "Parse failed"
                except Exception:
                    analysis["SyntaxValid"] = False
                    analysis["SyntaxErrors"] = "Parse failed"
            else:
                analysis["SyntaxValid"] = False
                analysis["SyntaxErrors"] = "File not accessible"
            
            results["PowerShellFiles"][ps1_file.name] = analysis
            
        except Exception as e:
            results["Issues"].append(f"Error processing {ps1_file.name}: {str(e)}")
    
    return results

if __name__ == '__main__':
    sys.exit(main())