"""Port of scripts/real-time-monitoring.ps1.

Modes: dashboard (refreshing console view), report (HTML),
metrics (JSON to stdout), alerts (history). Counters come from
typeperf (native Windows), process list from tasklist.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta

CONFIG = {"cpu": 80, "mem": 85, "disk": 90, "temp": 80}
ALERTS = []


def run(cmd, timeout=30):
    try:
        return subprocess.run(cmd, capture_output=True, text=True,
                              timeout=timeout)
    except Exception:
        return None


def counter(path):
    r = run(["typeperf", path, "-sc", "1"])
    if not r or r.returncode != 0:
        return None
    m = re.findall(r'"(-?[\d.]+)"', r.stdout)
    try:
        return float(m[-1])
    except Exception:
        return None


def ps_json(cmd):
    r = run(["powershell", "-NoProfile", "-Command", cmd])
    try:
        return json.loads(r.stdout) if r and r.stdout.strip() \
            else None
    except Exception:
        return None


def parse_boot(raw):
    """Return uptime timedelta or None.

    Handles ISO strings (pwsh) and /Date(<ms>)/ emitted by
    Windows PowerShell ConvertTo-Json.
    """
    try:
        text = str(raw)
        dm = re.search(r"/Date\((-?\d+)\)/", text)
        if dm:
            boot = datetime.fromtimestamp(
                int(dm.group(1)) / 1000)
            return datetime.now() - boot
        return (datetime.now()
                - datetime.fromisoformat(
                    text.split(".")[0].split("+")[0]))
    except Exception:
        return None


def get_metrics():
    m = {}
    m["cpu"] = counter(r"\Processor(_Total)\% Processor Time")
    osinfo = ps_json(
        "Get-CimInstance Win32_OperatingSystem | Select-Object "
        "FreePhysicalMemory,TotalVisibleMemorySize,"
        "LastBootUpTime | ConvertTo-Json")
    if osinfo:
        tot = osinfo.get("TotalVisibleMemorySize") or 0
        free = osinfo.get("FreePhysicalMemory") or 0
        if tot:
            m["mem"] = round((tot - free) / tot * 100, 2)
            m["mem_avail"] = round(free / 2**20, 2)
            m["mem_total"] = round(tot / 2**20, 2)
        m["uptime"] = parse_boot(
            osinfo.get("LastBootUpTime"))
    disk = ps_json(
        "Get-CimInstance Win32_LogicalDisk -Filter "
        "\"DeviceID='C:'\" | Select-Object Size,FreeSpace "
        "| ConvertTo-Json")
    if disk and disk.get("Size"):
        m["disk"] = round((disk["Size"] - disk["FreeSpace"])
                          / disk["Size"] * 100, 2)
        m["disk_free"] = round(disk["FreeSpace"] / 2**30, 2)
        m["disk_total"] = round(disk["Size"] / 2**30, 2)
    sent = counter(r"\Network Interface(*)\Bytes Sent/sec")
    recv = counter(r"\Network Interface(*)\Bytes Received/sec")
    m["net_sent"] = round((sent or 0) / 1024, 2)
    m["net_recv"] = round((recv or 0) / 1024, 2)
    m["processes"] = counter(r"\System\Processes")
    m["threads"] = counter(r"\System\Threads")
    top = ps_json(
        "Get-Process | Sort-Object CPU -Descending | "
        "Select-Object -First 5 Name,CPU,WorkingSet64 | "
        "ConvertTo-Json")
    m["top"] = top if isinstance(top, list) else \
        ([top] if top else [])
    return m


def bar(value, width=20):
    pct = (value or 0)
    filled = round(pct / 100 * width)
    return "[" + "█" * filled + "░" * (width - filled) + \
        f"] {pct}%"


def check_alerts(m):
    out = []
    if m.get("cpu") and m["cpu"] > CONFIG["cpu"]:
        out.append(f"High CPU Usage: {m['cpu']}%")
    if m.get("mem") and m["mem"] > CONFIG["mem"]:
        out.append(f"High Memory Usage: {m['mem']}%")
    if m.get("disk") and m["disk"] > CONFIG["disk"]:
        out.append(f"Low Disk Space: {m['disk']}% used")
    for a_ in out:
        ALERTS.append({"ts": str(datetime.now()),
                       "msg": a_})
    return out


def show_dashboard(m):
    print("=" * 64)
    print("           REAL-TIME SYSTEM MONITORING DASHBOARD")
    print("=" * 64)
    print(f"Last Updated: {datetime.now():%Y-%m-%d %H:%M:%S}\n")
    print("SYSTEM OVERVIEW")
    print("-" * 48)
    print(f"CPU Usage: {m.get('cpu')}% {bar(m.get('cpu'))}")
    print(f"Memory:    {m.get('mem')}% ({m.get('mem_avail')}GB /"
          f" {m.get('mem_total')}GB) {bar(m.get('mem'))}")
    print(f"Disk:      {m.get('disk')}% ({m.get('disk_free')}GB /"
          f" {m.get('disk_total')}GB) {bar(m.get('disk'))}")
    print(f"Network:   up {m.get('net_sent')}KB/s "
          f"down {m.get('net_recv')}KB/s")
    if m.get("uptime"):
        u = m["uptime"]
        print(f"Uptime:    {u.days}d {u.seconds // 3600}h "
              f"{(u.seconds % 3600) // 60}m")
    print("\nTOP PROCESSES")
    print("-" * 48)
    print(f'{"Name":<24}{"CPU":<12}{"Memory (MB)":<15}')
    for p in m.get("top", []):
        pname = str(p.get("Name"))[:23]
        pcpu = round(p.get("CPU") or 0)
        pmem = round((p.get("WorkingSet64") or 0) / 2**20, 1)
        print(f"{pname:<24}{pcpu:<12}{pmem:<15}")
    alerts = check_alerts(m)
    if alerts:
        print("\nALERTS")
        print("-" * 48)
        for a_ in alerts:
            print(a_)
    print("\nCtrl+C to quit")


def report(path):
    m = get_metrics()
    ts = f"{datetime.now():%Y-%m-%d %H:%M:%S}"
    procs = "".join(
        f"<li><strong>{p.get('Name')}:</strong> CPU: "
        f"{round(p.get('CPU') or 0)}, Memory: "
        f"{round((p.get('WorkingSet64') or 0) / 2**20, 2)}MB</li>"
        for p in m.get("top", []))
    html = f"""<!DOCTYPE html>
<html><head><title>DevOptimizer Performance Report</title>
<style>body {{ font-family: Arial, sans-serif; margin: 20px; }}
.header {{ background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }}
.metric {{ background-color: #ecf0f1; padding: 15px; margin: 10px 0; border-radius: 5px; }}
</style></head><body>
<div class="header"><h1>DevOptimizer Performance Report</h1>
<p>Generated: {ts}</p></div>
<div class="metric"><h3>System Overview</h3>
<p><strong>CPU Usage:</strong> {m.get('cpu')}%</p>
<p><strong>Memory Usage:</strong> {m.get('mem')}% ({m.get('mem_avail')}GB / {m.get('mem_total')}GB)</p>
<p><strong>Disk Usage:</strong> {m.get('disk')}% ({m.get('disk_free')}GB / {m.get('disk_total')}GB)</p>
<p><strong>Uptime:</strong> {m.get('uptime')}</p></div>
<div class="metric"><h3>Top Processes</h3><ul>{procs}</ul></div>
<div class="metric"><h3>Network Activity</h3>
<p><strong>Sent:</strong> {m.get('net_sent')} KB/s</p>
<p><strong>Received:</strong> {m.get('net_recv')} KB/s</p></div>
</body></html>"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Performance report generated: {path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Mode", default="dashboard",
                    choices=["dashboard", "report", "metrics",
                             "alerts"])
    ap.add_argument("-RefreshInterval", type=int, default=5)
    ap.add_argument("-Output", default="performance-report.html")
    a = ap.parse_args()
    if a.Mode == "metrics":
        m = get_metrics()
        u = m.get("uptime")
        out = {
            "CPU_Usage": m.get("cpu"),
            "Memory_Usage": m.get("mem"),
            "Memory_Available": m.get("mem_avail"),
            "Memory_Total": m.get("mem_total"),
            "Disk_Usage": m.get("disk"),
            "Disk_Free": m.get("disk_free"),
            "Disk_Total": m.get("disk_total"),
            "Network_Sent": m.get("net_sent"),
            "Network_Received": m.get("net_recv"),
            "Process_Count": m.get("processes"),
            "Thread_Count": m.get("threads"),
            "Top_Processes": m.get("top"),
            "Temperature": m.get("temp"),
            "Uptime": ({
                "Days": u.days,
                "Hours": u.seconds // 3600,
                "Minutes": (u.seconds % 3600) // 60,
                "Seconds": u.seconds % 60,
                "TotalSeconds": u.total_seconds(),
            } if u else None),
        }
        print(json.dumps(out, indent=2))
        return 0
    if a.Mode == "report":
        report(a.Output)
        return 0
    if a.Mode == "alerts":
        for x in ALERTS:
            print(f"{x['ts']}: {x['msg']}")
        if not ALERTS:
            print("No alerts recorded.")
        return 0
    try:
        while True:
            m = get_metrics()
            os.system("cls" if os.name == "nt" else "clear")
            show_dashboard(m)
            time.sleep(a.RefreshInterval)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(main())
