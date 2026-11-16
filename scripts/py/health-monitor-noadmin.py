"""Port of tools/Variants/HEALTH-MONITOR-NoAdmin.bat — real-time
health monitor: disk/memory/process/network/filesystem/PowerShell
checks, score-100 alerting, auto-repair via AUTO-RECOVERY-SYSTEM.bat
below 70. Menu: 1 single check, 2 continuous (30s), 3 exit.
"""
import ctypes
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
LOG_FILE = SCRIPT_DIR / "logs" / "health-monitor.log"


def log(kind, msg, alerts):
    try:
        (SCRIPT_DIR / "logs").mkdir(exist_ok=True)
    except OSError:
        pass
    line = time.strftime("[%Y-%m-%d %H:%M:%S] ") + \
        (f"ALERT: {msg}" if kind == "alert" else msg)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass
    if kind == "alert":
        alerts[0] += 1


def cycle():
    score = [100]
    alerts = [0]

    def alert(msg, pts):
        log("alert", msg, alerts)
        score[0] -= pts

    log("msg", "Health monitoring cycle started", alerts)

    log("msg", "Checking disk health...", alerts)
    try:
        sysdrive = os.environ.get("SystemDrive", "C:")
        free_gb = shutil.disk_usage(
            sysdrive + chr(92)).free // 2**30
        if free_gb < 1:
            alert(f"CRITICAL: Disk space below 1GB"
                  f" ({free_gb} GB free)", 30)
        elif free_gb < 5:
            alert(f"WARNING: Disk space below 5GB"
                  f" ({free_gb} GB free)", 15)
        else:
            log("msg", f"Disk health: OK ({free_gb} GB free)",
                alerts)
    except OSError:
        alert("WARNING: Disk space check failed", 10)

    log("msg", "Checking memory health...", alerts)
    try:
        r = subprocess.run(
            ["wmic", "OS", "get", "TotalVisibleMemorySize",
             "/value"], capture_output=True, text=True, timeout=15)
        total_kb = int(r.stdout.split("=")[-1].strip() or 0)
        total_gb = total_kb // 2**20
        if total_gb < 2:
            alert(f"WARNING: Low memory detected"
                  f" ({total_gb} GB total)", 20)
        else:
            log("msg",
                f"Memory health: OK ({total_gb} GB total)", alerts)
    except (OSError, ValueError, subprocess.SubprocessError):
        alert("WARNING: Memory check failed", 10)

    log("msg", "Checking process health...", alerts)
    try:
        r = subprocess.run(["tasklist", "/FI",
                            "IMAGENAME eq explorer.exe"],
                           capture_output=True, text=True,
                           timeout=15)
        if "explorer.exe" not in r.stdout.lower():
            alert("CRITICAL: Explorer process not running", 40)
        else:
            log("msg", "Explorer process: OK", alerts)
    except (OSError, subprocess.SubprocessError):
        alert("WARNING: Process check failed", 10)

    log("msg", "Checking network health...", alerts)
    try:
        r = subprocess.run(["ping", "google.com", "-n", "1"],
                           capture_output=True, timeout=15)
        if r.returncode != 0:
            alert("WARNING: Network connectivity issues", 15)
        else:
            log("msg", "Network health: OK", alerts)
    except (OSError, subprocess.SubprocessError):
        alert("WARNING: Network connectivity issues", 15)

    log("msg", "Checking file system health...", alerts)
    if not (SCRIPT_DIR / "logs").exists():
        alert("WARNING: Logs directory missing", 10)
    try:
        test = Path(str(LOG_FILE) + ".test")
        test.write_text("test")
        test.unlink()
    except OSError:
        alert("WARNING: Cannot write to log file", 15)

    log("msg", "Checking PowerShell health...", alerts)
    try:
        r = subprocess.run(
            ["powershell", "-Command", "Write-Host 'Test'"],
            capture_output=True, timeout=15)
        if r.returncode != 0:
            alert("WARNING: PowerShell execution issues", 20)
        else:
            log("msg", "PowerShell health: OK", alerts)
    except (OSError, subprocess.SubprocessError):
        alert("WARNING: PowerShell execution issues", 20)

    s = score[0]
    print("\n" + "=" * 60)
    print("                    HEALTH STATUS REPORT")
    print("=" * 60 + "\n")
    if s > 90:
        status = ("EXCELLENT", "All systems operating normally")
    elif s > 70:
        status = ("GOOD", "Minor issues detected")
    elif s > 50:
        status = ("FAIR", "Some issues require attention")
    else:
        status = ("POOR", "Critical issues detected")
    print(f"Overall Health: {status[0]} ({s}%)")
    print(f"Status: {status[1]}")
    print(f"\nAlerts generated: {alerts[0]}")
    print(f"Log file: {LOG_FILE}\n")

    if s < 70:
        print("Initiating automatic repair...")
        log("msg",
            "Initiating automatic repair due to low health score",
            alerts)
        rec = SCRIPT_DIR / "AUTO-RECOVERY-SYSTEM.bat"
        if rec.exists():
            subprocess.run(["cmd", "/c", str(rec)])
            log("msg", "Auto-recovery system executed", alerts)
        else:
            alert("Auto-recovery system not found", 0)

    log("msg", f"Health monitoring cycle completed - Score: {s}%",
        alerts)


def main():
    try:
        (SCRIPT_DIR / "logs").mkdir(exist_ok=True)
    except OSError:
        pass
    choice = ""
    if sys.stdin.isatty():
        print("\n1. Single health check")
        print("2. Continuous monitoring")
        print("3. Exit")
        choice = input("Enter your choice (1-3): ").strip()
    if choice == "3":
        return 0
    if choice == "2":
        while True:
            cycle()
            time.sleep(30)
    cycle()
    if sys.stdin.isatty():
        input("Press Enter to exit...")
    return 0


if __name__ == "__main__":
    sys.exit(main())
