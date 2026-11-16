"""Port of tools/Variants/06-System-Health-Check-NoAdmin.bat —
banner + retry wrapper around one inline PowerShell CIM health
report (CPU/memory/disk/network/top-procs/OS). Retries the PS call
up to 3 times; exit = error count.
"""
import ctypes
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
LOG_FILE = SCRIPT_DIR / "logs" / "system-health-check.log"
MAX_RETRIES = 3

PS_CMD = r"""
try {
  Write-Host '=== SYSTEM HEALTH CHECK ===' -ForegroundColor Green
  $cpu = Get-CimInstance Win32_Processor
  Write-Host "`nCPU: $($cpu.Name)" -ForegroundColor Yellow
  Write-Host "Cores: $($cpu.NumberOfCores) | Logical Processors: $($cpu.NumberOfLogicalProcessors)"
  $memory = Get-CimInstance Win32_ComputerSystem
  $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
  $availableMemoryGB = [math]::Round((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue / 1024, 2)
  $usedMemoryGB = $totalMemoryGB - $availableMemoryGB
  $memoryPercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)
  Write-Host "`nMemory: $totalMemoryGB GB Total" -ForegroundColor Yellow
  Write-Host "Used: $usedMemoryGB GB ($memoryPercent%) | Available: $availableMemoryGB GB"
  $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
  Write-Host "`nDisk Usage:" -ForegroundColor Yellow
  foreach ($disk in $disks) {
    $usedSpace = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
    $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
    $totalSpace = [math]::Round($disk.Size / 1GB, 2)
    $usedPercent = [math]::Round(($usedSpace / $totalSpace) * 100, 2)
    Write-Host "Drive $($disk.DeviceID) - Used: $usedSpace GB ($usedPercent%) | Free: $freeSpace GB | Total: $totalSpace GB"
  }
  $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
  Write-Host "`nActive Network Adapters:" -ForegroundColor Yellow
  foreach ($adapter in $adapters) {
    Write-Host "$($adapter.Name) - $($adapter.LinkSpeed)"
  }
  Write-Host "`nTop 10 Processes by CPU Usage:" -ForegroundColor Yellow
  Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | ForEach-Object {
    Write-Host "$($_.ProcessName): $([math]::Round($_.CPU, 2))s CPU"
  }
  $osVersion = Get-CimInstance Win32_OperatingSystem
  Write-Host "`nWindows Version: $($osVersion.Caption) $($osVersion.Version)" -ForegroundColor Yellow
  Write-Host "Build: $($osVersion.BuildNumber)"
  Write-Host "`n=== HEALTH CHECK COMPLETE ===" -ForegroundColor Green
} catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
"""


def log(kind, msg, errs):
    (SCRIPT_DIR / "logs").mkdir(exist_ok=True)
    prefix = (f"ERROR #{errs[0]}: " if kind == "err" else "")
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as fh:
            fh.write(time.strftime("[%Y-%m-%d %H:%M:%S] ")
                     + prefix + msg + "\n")
    except OSError:
        pass


def main():
    (SCRIPT_DIR / "logs").mkdir(exist_ok=True)
    errs = [0]
    log("msg", "Starting system health check", errs)
    print("\n" + "=" * 60)
    print("[INFO] Running in standard mode without Administrator"
          " privileges")
    print("[INFO] Some system-level features may be limited")
    print("                System Health Check - Advanced Error"
          " Handling")
    print("=" * 60)
    print("Version: 2.0")
    print(f"Log file: {LOG_FILE}")
    print(f"Max retries: {MAX_RETRIES}\n")

    retries = 0
    while True:
        r = subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass",
             "-Command", PS_CMD])
        if r.returncode == 0:
            retries = 0
            break
        errs[0] += 1
        log("err", "Command failed: PowerShell health check"
            " script", errs)
        print("ERROR: PowerShell health check script")
        retries += 1
        if retries >= MAX_RETRIES:
            print("MAX RETRIES REACHED for: PowerShell health"
                  " check script")
            log("err", "MAX RETRIES REACHED for: PowerShell"
                " health check script", errs)
            break
        print(f"Retrying in 2 seconds... (Attempt"
              f" {retries}/{MAX_RETRIES})")
        time.sleep(2)

    if errs[0]:
        log("msg", f"Health check completed with {errs[0]}"
            " error(s)", errs)
        if sys.stdin.isatty():
            input("Press Enter to exit...")
        return errs[0]
    log("msg", "Health check completed successfully", errs)
    if sys.stdin.isatty():
        input("Press Enter to exit...")
    return 0


if __name__ == "__main__":
    sys.exit(main())
