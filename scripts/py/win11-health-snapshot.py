"""Port of scripts/win11-health-snapshot.ps1.

11-section Win11 health snapshot: storage, pending reboots, WU,
Defender, error devices, 48h events, crashed services, RAM,
DNS, restore points, dirty bit.
"""

import os
import shutil
import subprocess
import sys
from datetime import datetime

PS = None


def ps():
    global PS
    if PS is None:
        PS = (shutil.which("pwsh") or
              shutil.which("powershell") or "powershell")
    return PS


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=120)
    except Exception as e:
        return subprocess.CompletedProcess(cmd, 1, "",
                                           str(e))


def psout(expr):
    return run([ps(), "-NoProfile", "-Command", expr]).stdout


def step(n, label):
    print(f"[VERBOSE] {label}")


def main():
    # 1. Disks / storage health
    step(1, "Checking disk/Storage health...")
    print("\n-- Storage --")
    print(psout(
        "Get-PhysicalDisk | ForEach-Object { '{0}: Health={1} "
        "Op={2} Size={3:N0}GB' -f $_.FriendlyName,"
        "$_.HealthStatus,$_.OperationalStatus,($_.Size/1GB) };"
        " Get-Volume | Where-Object DriveLetter | ForEach-Object"
        " { '{0}: {1} free {2}% of {3:N0}GB' -f $_.DriveLetter,"
        "$_.FileSystem,(if ($_.Size) { [math]::Round(100*$_.SizeRemaining/"
        "$_.Size,0) } else { 0 }),($_.Size/1GB) }"))

    # 2. Pending reboot?
    step(2, "Checking pending reboots...")
    rb = []
    r = run(["reg", "query",
             r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion"
             r"\Component Based Servicing\RebootPending"])
    if r.returncode == 0:
        rb.append("CBS")
    r = run(["reg", "query",
             r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion"
             r"\WindowsUpdate\Auto Update\RebootRequired"])
    if r.returncode == 0:
        rb.append("WU")
    r = run(["reg", "query",
             r"HKLM\SYSTEM\CurrentControlSet\Control"
             r"\Session Manager",
             "/v", "PendingFileRenameOperations"])
    if r.returncode == 0 and "PendingFileRenameOperations" \
            in r.stdout:
        rb.append("FileRename")
    print(f"\n-- Reboot pending: {', '.join(rb) if rb else 'no'}"
          f" --")

    # 3. Windows Update service
    step(3, "Checking Windows Update service...")
    r = run(["sc", "query", "wuauserv"])
    print("WU service: "
          + next((l.strip() for l in r.stdout.splitlines()
                  if "STATE" in l), "unknown"))

    # 4. Defender
    step(4, "Checking Defender...")
    print("\n-- Defender --")
    print(psout(
        "$mp = Get-MpComputerStatus; 'RealTime={0} "
        "Definitions={1} ({2})' -f $mp.RealTimeProtectionEnabled"
        ",$mp.AntivirusSignatureVersion,"
        "$mp.AntivirusSignatureLastUpdated"))

    # 5. Devices in error state
    step(5, "Checking devices in error state...")
    print(psout(
        "$errDev = Get-PnpDevice | Where-Object { $_.Status -eq "
        "'Error' }; 'Devices with errors: {0}' -f ($errDev | "
        "Measure-Object).Count; $errDev | Select-Object -First 8"
        " | ForEach-Object { '  {0} [{1}]: {2}' -f "
        "$_.FriendlyName,$_.InstanceId,$_.Problem }"))

    # 6. Critical/Error events last 48h
    step(6, "Checking critical/error events (48h)...")
    print("\n-- Critical/Error events (48h) --")
    print(psout(
        "$crit = Get-WinEvent -FilterHashtable @{LogName="
        "'System'; Level=1,2; StartTime=(Get-Date).AddHours(-48"
        ")} -MaxEvents 40; $crit | Group-Object ProviderName,Id"
        " | Sort-Object Count -Descending | Select-Object "
        "-First 10 | ForEach-Object { $s = ($_.Group | "
        "Select-Object -First 1).Message; if ($s) { $s = ($s"
        " -split \"`n\")[0].Trim() }; '  {0}x {1} [{2}] {3}'"
        " -f $_.Count,$_.Name,$_.Group[0].TimeCreated."
        "ToString('MM-dd HH:mm'),$s }"))

    # 7. Services crashed (SCM 7031/7034, 48h)
    step(7, "Checking crashed services (48h)...")
    print(psout(
        "$svcFail = Get-WinEvent -FilterHashtable @{LogName="
        "'System'; ProviderName='Service Control Manager'; Id"
        "=7031,7034; StartTime=(Get-Date).AddHours(-48)} "
        "-ErrorAction SilentlyContinue; 'Services crashed in"
        " 48h: {0} events' -f ($svcFail | Measure-Object)."
        "Count; $svcFail | Group-Object { ($_.Message -replace"
        " '.*service\\s+','' -replace '\\s+terminated.*','') }"
        " | Sort-Object Count -Descending | Select-Object "
        "-First 5 | ForEach-Object { '  {0}x {1}' -f $_.Count,"
        "$_.Name }"))

    # 8. Memory / pagefile
    step(8, "Checking RAM/pagefile...")
    osinfo = psout(
        "$os = Get-CimInstance Win32_OperatingSystem; '{0:N1}"
        "|{1:N1}|{2:MM-dd HH:mm}' -f ($os.TotalVisibleMemorySize"
        "/1MB),($os.FreePhysicalMemory/1MB),$os.LastBootUpTime")
    parts = osinfo.strip().split("|")
    if len(parts) == 3:
        print(f"\n-- RAM: {parts[0]}GB total, {parts[1]}GB free"
              f" | Last boot: {parts[2]} --")
    else:
        print(osinfo.strip())

    # 9. DNS resolution
    r = run(["nslookup", "microsoft.com"])
    if r.returncode == 0:
        print("DNS resolution: OK")
    else:
        print("DNS resolution: FAILED")

    # 10. System Restore on C:?
    sr = run(["wmic", "/namespace:\\\\root\\default", "path",
              "SystemRestore", "get", "SequenceNumber",
              "/format:csv"])
    vss = run(["vssadmin", "list", "shadows"])
    have = (any(l.strip().split(",")[-1].strip().isdigit()
                for l in sr.stdout.splitlines()
                if "," in l and "Node" not in l)
            or "shadow" in vss.stdout.lower())
    print(f"System restore/shadows present: {have}")

    # 11. Dirty bit
    sysdrive = os.environ.get("SystemDrive", "C:")
    r = run(["fsutil", "dirty", "query", sysdrive])
    dirty = r.stdout.replace("Dirty Bit Set : ", "").strip()
    print(f"{sysdrive} dirty bit: {dirty}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
