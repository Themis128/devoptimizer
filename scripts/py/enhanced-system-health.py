"""Port of scripts/enhanced-system-health.ps1 — system health report:
OS info, WU service, disk free %, memory, CPU, temperature
(WMI/OHM/HWiNFO), network, Defender+firewall, sfc /verifyonly.
--generate-report writes an HTML report next to cwd.
"""
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

issues, warnings_, recs = [], [], []


def ps(cmd):
    r = subprocess.run(["powershell", "-NoProfile", "-Command", cmd],
                       capture_output=True, text=True)
    return r.stdout.strip()


def ps_json(cmd):
    out = ps(cmd + " | ConvertTo-Json -Depth 3 -Compress")
    try:
        return json.loads(out) if out else None
    except ValueError:
        return None


def main():
    gen_report = "--generate-report" in sys.argv
    print("Enhanced System Health Check")
    print("=================================\n")

    info = ps_json(
        "$os = Get-WmiObject Win32_OperatingSystem; "
        "@{OS=$os.Caption; Version=$os.Version;"
        "Arch=$os.OSArchitecture}") or {}
    info["ComputerName"] = os.environ.get("COMPUTERNAME", "")
    info["Username"] = os.environ.get("USERNAME", "")
    info["CheckTime"] = time.strftime("%Y-%m-%d %H:%M:%S")
    print("System Information:")
    print(f"OS: {info.get('OS')}")
    print(f"Version: {info.get('Version')}")
    print(f"Architecture: {info.get('Arch')}")
    print(f"Computer: {info['ComputerName']}")
    print(f"User: {info['Username']}")
    print(f"Check Time: {info['CheckTime']}\n")

    print("1. Windows Update Service Check...")
    svc = ps_json("Get-Service -Name 'wuauserv' -ErrorAction"
                  " SilentlyContinue | Select-Object Status")
    if svc:
        if svc.get("Status") == 4 or svc.get("Status") == "Running":
            print("   Windows Update Service: RUNNING")
        else:
            print(f"   Windows Update Service: {svc.get('Status')}")
            warnings_.append("Windows Update Service is not running")
    else:
        print("   Windows Update Service: ERROR")
        issues.append("Cannot access Windows Update Service")

    print("2. Disk Health Check...")
    disks = ps_json("Get-WmiObject Win32_LogicalDisk | Where-Object"
                    " {$_.DriveType -eq 3} | Select-Object DeviceID,"
                    "Size,FreeSpace") or []
    if isinstance(disks, dict):
        disks = [disks]
    for d in disks:
        try:
            pct = round(d["FreeSpace"] / d["Size"] * 100, 2)
            fg, tg = round(d["FreeSpace"] / 1e9, 2), \
                round(d["Size"] / 1e9, 2)
            if pct < 10:
                print(f"   Drive {d['DeviceID']}: CRITICAL - Only"
                      f" {pct}% free ({fg} GB / {tg} GB)")
                issues.append(f"Drive {d['DeviceID']} has"
                              " critically low free space")
            elif pct < 20:
                print(f"   Drive {d['DeviceID']}: WARNING - {pct}%"
                      f" free ({fg} GB / {tg} GB)")
                warnings_.append(f"Drive {d['DeviceID']} has low"
                                 " free space")
            else:
                print(f"   Drive {d['DeviceID']}: OK - {pct}% free"
                      f" ({fg} GB / {tg} GB)")
        except (KeyError, ZeroDivisionError, TypeError):
            issues.append("Cannot access disk information")

    print("3. Memory Check...")
    mem = ps_json(
        "$t = (Get-WmiObject Win32_ComputerSystem)"
        ".TotalPhysicalMemory; "
        "$a = (Get-Counter '\\Memory\\Available MBytes')"
        ".CounterSamples[0].CookedValue; "
        "@{Total=$t; AvailMB=$a}")
    if mem:
        total_gb = round(mem["Total"] / 1e9, 2)
        avail_gb = round(mem["AvailMB"] / 1024, 2)
        used = total_gb - avail_gb
        pct = round(used / total_gb * 100, 2)
        if pct > 90:
            print(f"   Memory Usage: CRITICAL - {pct}% used"
                  f" ({used} GB / {total_gb} GB)")
            issues.append("Memory usage is critically high")
        elif pct > 80:
            print(f"   Memory Usage: WARNING - {pct}% used"
                  f" ({used} GB / {total_gb} GB)")
            warnings_.append("Memory usage is high")
        else:
            print(f"   Memory Usage: OK - {pct}% used"
                  f" ({used} GB / {total_gb} GB)")
    else:
        print("   Memory Check: ERROR")
        issues.append("Cannot access memory information")

    print("4. CPU Check...")
    cpu = ps_json(
        "$c = Get-Counter '\\Processor(_Total)\\% Processor Time'"
        " -SampleInterval 2 -MaxSamples 3; "
        "@{Avg=($c.CounterSamples | Measure-Object CookedValue"
        " -Average).Average}")
    if cpu:
        avg = round(cpu["Avg"], 2)
        if avg > 90:
            print(f"   CPU Usage: CRITICAL - {avg}% average")
            issues.append("CPU usage is critically high")
        elif avg > 80:
            print(f"   CPU Usage: WARNING - {avg}% average")
            warnings_.append("CPU usage is high")
        else:
            print(f"   CPU Usage: OK - {avg}% average")
    else:
        print("   CPU Check: ERROR")
        issues.append("Cannot access CPU information")

    print("5. Temperature Check...")
    temp = None
    t = ps("(Get-WmiObject -Namespace root/wmi -Class"
           " MSAcpi_ThermalZoneTemperature -ErrorAction"
           " SilentlyContinue | Select-Object -First 1"
           " -ExpandProperty CurrentTemperature)")
    if t and re.match(r"^\d+$", t):
        temp = round(int(t) / 10 - 273.15, 2)
        print(f"   Temperature: {temp}°C (WMI)")
    else:
        t2 = ps("(Get-WmiObject -Namespace root\\OpenHardwareMonitor"
                " -Class Sensor -ErrorAction SilentlyContinue |"
                " Where-Object {$_.SensorType -eq 'Temperature'} |"
                " Select-Object -First 1 -ExpandProperty Value)")
        if t2 and re.match(r"^[\d.]+$", t2):
            temp = round(float(t2), 2)
            print(f"   Temperature: {temp}°C (OpenHardwareMonitor)")
        else:
            t3 = ps("(Get-WmiObject -Namespace root\\HWiNFO64"
                    " -Class Sensor -ErrorAction SilentlyContinue |"
                    " Where-Object {$_.SensorType -eq 'Temperature'}"
                    " | Select-Object -First 1 -ExpandProperty"
                    " Value)")
            if t3 and re.match(r"^[\d.]+$", t3):
                temp = round(float(t3), 2)
                print(f"   Temperature: {temp}°C (HWiNFO)")
            else:
                print("   Temperature: Not available (no compatible"
                      " monitoring software)")
                warnings_.append("Temperature monitoring not"
                                 " available")
    if temp is not None:
        if temp > 85:
            print(f"   Temperature: CRITICAL - {temp}°C")
            issues.append("System temperature is critically high")
        elif temp > 75:
            print(f"   Temperature: WARNING - {temp}°C")
            warnings_.append("System temperature is high")

    print("6. Network Check...")
    adapters = ps_json("Get-NetAdapter | Where-Object {$_.Status -eq"
                       " 'Up' -and $_.InterfaceDescription -notlike"
                       " '*Loopback*'} | Measure-Object")
    if adapters and adapters.get("Count", 0) > 0:
        print(f"   Network: {adapters['Count']} active adapter(s)")
        r = subprocess.run(["powershell", "-NoProfile", "-Command",
                            "Test-Connection -ComputerName 8.8.8.8"
                            " -Count 1 -Quiet"],
                           capture_output=True, text=True)
        if r.stdout.strip().lower() == "true":
            print("   Internet: Connected")
        else:
            print("   Internet: No connectivity")
            warnings_.append("No internet connectivity")
    else:
        print("   Network: No active adapters")
        issues.append("No active network adapters")

    print("7. Security Check...")
    defender = ps_json("Get-MpComputerStatus -ErrorAction"
                       " SilentlyContinue | Select-Object"
                       " AntivirusEnabled")
    if defender:
        if defender.get("AntivirusEnabled"):
            print("   Windows Defender: Enabled")
        else:
            print("   Windows Defender: Disabled")
            warnings_.append("Windows Defender is disabled")
    else:
        print("   Windows Defender: Status unknown")
    fw = ps_json("Get-NetFirewallProfile | Where-Object"
                 " {$_.Enabled -eq $false} | Measure-Object")
    if fw and fw.get("Count", 0) > 0:
        print("   Firewall: Some profiles disabled")
        warnings_.append("Some firewall profiles are disabled")
    else:
        print("   Firewall: All profiles enabled")

    print("8. System File Check...")
    r = subprocess.run(["sfc", "/verifyonly"], capture_output=True,
                       text=True)
    if r.returncode == 0:
        print("   System Files: No integrity violations")
    else:
        print("   System Files: Integrity violations detected")
        warnings_.append("System file integrity violations"
                         " detected")
        recs.append("Run 'sfc /scannow' to repair system files")

    print("\nHEALTH SUMMARY\n=================")
    if not issues and not warnings_:
        overall = "Excellent"
        print("Overall Health: EXCELLENT")
        print("Your system is in great condition!")
    elif not issues:
        overall = "Good"
        print("Overall Health: GOOD")
        print("Minor warnings detected, but system is healthy.")
    elif len(issues) <= 2:
        overall = "Fair"
        print("Overall Health: FAIR")
        print("Some issues detected that should be addressed.")
    else:
        overall = "Poor"
        print("Overall Health: POOR")
        print("Multiple issues detected that need immediate"
              " attention.")
    if issues:
        print("\nISSUES DETECTED:")
        for i in issues:
            print(f"   - {i}")
    if warnings_:
        print("\nWARNINGS:")
        for w in warnings_:
            print(f"   - {w}")
    if recs:
        print("\nRECOMMENDATIONS:")
        for r_ in recs:
            print(f"   - {r_}")

    if gen_report:
        path = Path("health-report-"
                    + time.strftime("%Y-%m-%d-%H-%M-%S") + ".html")
        def lis(items, empty):
            return ("".join(f"<div class='{cls}'>- {i}</div>"
                            for i in items)
                    if items else f"<p>{empty}</p>")
        html = f"""<!DOCTYPE html>
<html><head><title>System Health Report</title>
<style>
body {{ font-family: Arial, sans-serif; margin: 20px; }}
.header {{ background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }}
.issue {{ background-color: #e74c3c; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }}
.warning {{ background-color: #f39c12; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }}
.recommendation {{ background-color: #3498db; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }}
</style></head><body>
<div class="header"><h1>System Health Report</h1>
<p>Generated: {info['CheckTime']}</p>
<p>Computer: {info['ComputerName']} | User: {info['Username']}</p></div>
<h2>System Information</h2>
<p><b>OS:</b> {info.get('OS')}</p>
<p><b>Version:</b> {info.get('Version')}</p>
<p><b>Architecture:</b> {info.get('Arch')}</p>
<h2>Health Assessment</h2>
<p class="{overall.lower()}"><b>Overall Health:</b> {overall.upper()}</p>
<h2>Issues ({len(issues)})</h2>
{"".join(f"<div class='issue'>- {i}</div>" for i in issues) if issues else "<p>No issues detected.</p>"}
<h2>Warnings ({len(warnings_)})</h2>
{"".join(f"<div class='warning'>- {w}</div>" for w in warnings_) if warnings_ else "<p>No warnings.</p>"}
<h2>Recommendations ({len(recs)})</h2>
{"".join(f"<div class='recommendation'>- {r}</div>" for r in recs) if recs else "<p>No recommendations.</p>"}
</body></html>"""
        path.write_text(html, encoding="utf-8")
        print(f"\nHealth report generated: {path}")
    print("\nEnhanced System Health Check completed!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
