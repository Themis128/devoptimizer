"""Port of tools/Variants/ENHANCED-SYSTEM-DIAGNOSTICS-NoAdmin.bat.

Interactive 12-option diagnostics menu; each option runs a fixed
sequence of system commands, writing results into
%USERPROFILE%\\Desktop\\DevOptimizer\\Diagnostics\\.
"""

import os
import subprocess
from datetime import datetime
import sys
from pathlib import Path

DIAG = (Path(os.environ.get("USERPROFILE", "."))
        / "Desktop" / "DevOptimizer" / "Diagnostics")


def _step(cmd, outfile):
    """Run cmd (list) capturing combined output into outfile."""
    DIAG.mkdir(parents=True, exist_ok=True)
    try:
        r = subprocess.run(cmd, capture_output=True,
                           text=True, timeout=600)
        out = r.stdout + r.stderr
    except FileNotFoundError:
        out = f"command not found: {cmd[0]}"
    except subprocess.TimeoutExpired:
        out = "command timed out"
    (DIAG / outfile).write_text(out, errors="replace",
                               encoding="utf-8")


def run_steps(name, steps):
    print(f"\n{'=' * 64}")
    print(f"{name:^64}")
    print("=" * 64 + "\n")
    for i, (label, cmd, out) in enumerate(steps, 1):
        print(f"[{i}/{len(steps)}] {label}...")
        _step(cmd, out)
        print(f"[SUCCESS] {label}")
    print(f"\n[SUCCESS] {name.title()} completed!")


def _wmic(*args):
    return ["wmic"] + [a for a in args]


def system_information():
    run_steps("SYSTEM INFORMATION", [
        ("Getting system information",
         ["systeminfo"], "system-info.txt"),
        ("Getting OS information",
         _wmic("os", "get",
               "Caption,Version,Architecture,"
               "TotalVisibleMemorySize,FreePhysicalMemory",
               "/format:table"), "os-info.txt"),
        ("Getting computer information",
         _wmic("computersystem", "get",
               "Name,Domain,Manufacturer,Model,"
               "TotalPhysicalMemory", "/format:table"),
         "computer-info.txt"),
        ("Getting processor information",
         _wmic("cpu", "get",
               "Name,NumberOfCores,"
               "NumberOfLogicalProcessors,MaxClockSpeed",
               "/format:table"), "processor-info.txt"),
        ("Getting memory information",
         _wmic("memorychip", "get",
               "Capacity,Speed,Manufacturer,PartNumber",
               "/format:table"), "memory-info.txt"),
        ("Getting disk information",
         _wmic("diskdrive", "get",
               "Model,Size,InterfaceType,MediaType",
               "/format:table"), "disk-info.txt"),
        ("Getting network information",
         ["ipconfig", "/all"], "network-info.txt"),
        ("Getting installed programs",
         _wmic("product", "get", "Name,Version,Vendor",
               "/format:table"), "installed-programs.txt"),
    ])


def hardware_analysis():
    run_steps("HARDWARE ANALYSIS", [
        ("Getting CPU usage",
         _wmic("cpu", "get", "LoadPercentage",
               "/format:table"), "cpu-usage.txt"),
        ("Getting memory usage",
         _wmic("OS", "get",
               "TotalVisibleMemorySize,FreePhysicalMemory",
               "/format:table"), "memory-usage.txt"),
        ("Getting disk usage", ["cmd", "/c", "dir /-c | "
                                "findstr /C:\"bytes free\""],
         "disk-usage.txt"),
        ("Getting temperature information",
         _wmic("/namespace:\\\\root\\wmi", "path",
               "MSAcpi_ThermalZoneTemperature", "get",
               "CurrentTemperature", "/format:table"),
         "temperature-info.txt"),
        ("Getting power information",
         ["powercfg", "/query"], "power-info.txt"),
        ("Getting hardware errors",
         _wmic("path", "win32_systemdriver", "where",
               'state="running"', "get", "name,state",
               "/format:table"), "hardware-errors.txt"),
    ])


def network_diagnostics():
    run_steps("NETWORK DIAGNOSTICS", [
        ("Testing connectivity",
         ["ping", "-n", "4", "8.8.8.8"], "ping-test.txt"),
        ("Getting network configuration",
         ["ipconfig", "/all"], "network-config.txt"),
        ("Getting network statistics",
         ["netstat", "-an"], "network-stats.txt"),
        ("Getting routing table",
         ["route", "print"], "routing-table.txt"),
        ("Getting DNS information",
         ["nslookup", "google.com"], "dns-test.txt"),
        ("Getting network adapters",
         _wmic("path", "win32_networkadapter", "get",
               "name,adaptertype,netconnectionstatus",
               "/format:table"), "network-adapters.txt"),
    ])


def security_analysis():
    run_steps("SECURITY ANALYSIS", [
        ("Checking Windows Defender",
         ["powershell", "-Command", "Get-MpComputerStatus"],
         "windows-defender.txt"),
        ("Checking firewall",
         ["netsh", "advfirewall", "show", "allprofiles"],
         "firewall-status.txt"),
        ("Checking UAC",
         ["reg", "query",
          "HKLM\\SOFTWARE\\Microsoft\\Windows\\"
          "CurrentVersion\\Policies\\System",
          "/v", "EnableLUA"], "uac-status.txt"),
        ("Checking Windows Update",
         ["powershell", "-Command", "Get-WindowsUpdate"],
         "windows-update.txt"),
        ("Checking security policies",
         ["secedit", "/export", "/cfg",
          str(DIAG / "security-policies.txt")],
         "security-policies-export.log"),
    ])


def performance_metrics():
    run_steps("PERFORMANCE METRICS", [
        ("Getting CPU performance",
         _wmic("cpu", "get", "LoadPercentage",
               "/format:table"), "cpu-performance.txt"),
        ("Getting memory performance",
         _wmic("OS", "get",
               "TotalVisibleMemorySize,FreePhysicalMemory",
               "/format:table"), "memory-performance.txt"),
        ("Getting disk performance",
         _wmic("logicaldisk", "get", "size,freespace",
               "/format:table"), "disk-performance.txt"),
        ("Getting process performance",
         ["tasklist", "/fo", "csv"],
         "process-performance.txt"),
        ("Getting service performance",
         ["sc", "query", "state=", "all"],
         "service-performance.txt"),
    ])


def service_status():
    run_steps("SERVICE STATUS", [
        ("Getting all services",
         ["sc", "query", "state=", "all"], "all-services.txt"),
        ("Getting running services",
         ["sc", "query", "state=", "running"],
         "running-services.txt"),
        ("Getting stopped services",
         ["sc", "query", "state=", "stopped"],
         "stopped-services.txt"),
    ])


def disk_analysis():
    run_steps("DISK ANALYSIS", [
        ("Getting disk information",
         _wmic("logicaldisk", "get",
               "deviceid,size,freespace,volumename",
               "/format:table"), "disk-info.txt"),
        ("Checking disk health",
         ["chkdsk"], "disk-health.txt"),
        ("Getting disk usage",
         ["cmd", "/c", "dir C:\\ /s /-c | findstr bytes"],
         "disk-usage.txt"),
        ("Getting disk errors",
         _wmic("path", "win32_logicaldisk", "get",
               "deviceid,size,freespace,volumename",
               "/format:table"), "disk-errors.txt"),
    ])


def registry_health():
    run_steps("REGISTRY HEALTH", [
        ("Checking registry integrity",
         ["sfc", "/scannow"], "registry-integrity.txt"),
        ("Getting registry size",
         ["reg", "query", "HKLM\\SOFTWARE", "/s"],
         "registry-size.txt"),
        ("Checking registry errors",
         ["reg", "query",
          "HKLM\\SOFTWARE\\Microsoft\\Windows\\"
          "CurrentVersion\\Run"], "registry-errors.txt"),
    ])


def event_log_analysis():
    run_steps("EVENT LOG ANALYSIS", [
        ("Getting system events",
         ["wevtutil", "qe", "System", "/c:10", "/rd:true",
          "/f:text"], "system-events.txt"),
        ("Getting application events",
         ["wevtutil", "qe", "Application", "/c:10",
          "/rd:true", "/f:text"], "application-events.txt"),
        ("Getting security events",
         ["wevtutil", "qe", "Security", "/c:10",
          "/rd:true", "/f:text"], "security-events.txt"),
        ("Getting error events",
         ["wevtutil", "qe", "System", "/c:10", "/rd:true",
          "/f:text", "/q:*[System[Level=2]]"],
         "error-events.txt"),
    ])


def startup_analysis():
    run_steps("STARTUP ANALYSIS", [
        ("Getting startup programs",
         _wmic("startup", "get", "command,caption",
               "/format:table"), "startup-programs.txt"),
        ("Getting startup services",
         ["cmd", "/c",
          "sc query state= all | findstr AUTO_START"],
         "startup-services.txt"),
        ("Getting startup registry",
         ["reg", "query",
          "HKLM\\SOFTWARE\\Microsoft\\Windows\\"
          "CurrentVersion\\Run"], "startup-registry.txt"),
    ])


def generate_report():
    print("\n[REPORT] Creating HTML report...")
    DIAG.mkdir(parents=True, exist_ok=True)
    html = f"""<!DOCTYPE html>
<html>
<head>
<title>System Diagnostic Report</title>
<style>
body {{ font-family: Arial, sans-serif; margin: 20px; }}
.header {{ background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }}
.section {{ margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }}
</style>
</head>
<body>
<div class="header">
<h1>System Diagnostic Report</h1>
<p>Generated: {datetime.now():%m/%d/%Y %H:%M:%S}</p>
</div>
<div class="section">
<h2>System Information</h2>
<p>Check system-info.txt for detailed information</p>
</div>
<div class="section">
<h2>Hardware Analysis</h2>
<p>Check hardware analysis files for detailed information</p>
</div>
<div class="section">
<h2>Network Diagnostics</h2>
<p>Check network diagnostics files for detailed information</p>
</div>
<div class="section">
<h2>Security Analysis</h2>
<p>Check security analysis files for detailed information</p>
</div>
</body>
</html>"""
    (DIAG / "diagnostic-report.html").write_text(
        html, encoding="utf-8")
    print("[SUCCESS] Diagnostic report generated!")
    print(f"[INFO] Report saved to: "
          f"{DIAG / 'diagnostic-report.html'}")


SECTIONS = {
    "1": system_information, "2": hardware_analysis,
    "3": network_diagnostics, "4": security_analysis,
    "5": performance_metrics, "6": service_status,
    "7": disk_analysis, "8": registry_health,
    "9": event_log_analysis, "10": startup_analysis,
    "12": generate_report,
}


def complete_diagnostics():
    print("\n" + "=" * 64)
    print("COMPLETE DIAGNOSTICS".center(64))
    print("=" * 64 + "\n")
    for k in "123456789":
        SECTIONS[k]()
    SECTIONS["10"]()
    print("\n[SUCCESS] Complete diagnostics completed!")


SECTIONS["11"] = complete_diagnostics


def menu():
    print("=" * 64)
    print("DIAGNOSTICS MENU".center(64))
    print("=" * 64 + "\n")
    labels = ["System Information", "Hardware Analysis",
              "Network Diagnostics", "Security Analysis",
              "Performance Metrics", "Service Status",
              "Disk Analysis", "Registry Health",
              "Event Log Analysis", "Startup Analysis",
              "Complete Diagnostics", "Generate Report"]
    for i, lab in enumerate(labels, 1):
        print(f"{i}.   {lab}")
    print("0.   Exit")
    print("\n" + "=" * 64)


def main():
    print("             ENHANCED SYSTEM DIAGNOSTICS")
    print("=" * 64)
    print("\nComprehensive system health and performance "
          "analysis\n")
    if not sys.stdin.isatty():
        print("[INFO] Interactive mode requires a terminal; "
              "run with a console to use the menu.")
        return 0
    while True:
        menu()
        choice = input("Enter your choice (0-12): ").strip()
        if choice == "0":
            print("\n" + "=" * 64)
            print("THANK YOU FOR USING".center(64))
            print("ENHANCED SYSTEM DIAGNOSTICS".center(64))
            print("=" * 64 + "\n")
            print("Your system has been thoroughly analyzed!\n")
            return 0
        fn = SECTIONS.get(choice)
        if fn is None:
            print("\n[ERROR] Invalid choice. Please select a "
                  "number between 0-12.\n")
            input("Press Enter to continue...")
            continue
        fn()
        input("\nPress Enter to continue...")


if __name__ == "__main__":
    sys.exit(main())
