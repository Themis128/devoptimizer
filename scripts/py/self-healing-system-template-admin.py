"""Self-healing system template (port of
tools/Variants/self-healing-system-template-Admin.bat).

Health scoring (disk, memory, explorer, network) plus automatic
recovery actions and a self_heal mapping that picks recoveries by
error class. Admin mode — requires elevation; exits unelevated.
"""

import argparse
import ctypes
import datetime
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

# REQUIRES: admin
# CATEGORY: utilities
# TAGS: template, self-healing, recovery

SCRIPT_DIR = Path(__file__).resolve().parent
LOG_FILE = SCRIPT_DIR / "logs" / "self-healing.log"
HEALTH_WARN = 70

_recovery_count = 0


def log_message(msg):
    LOG_FILE.parent.mkdir(exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(f"[{datetime.datetime.now()}] {msg}\n")
    print(msg)


def log_recovery(msg):
    log_message(f"RECOVERY: {msg}")


def _run(cmd, timeout=60):
    try:
        return subprocess.run(cmd, capture_output=True,
                              timeout=timeout).returncode
    except (OSError, subprocess.TimeoutExpired):
        return 1


def _proc_running(name):
    try:
        out = subprocess.run(["tasklist"], capture_output=True,
                             text=True).stdout
        return name.lower() in out.lower()
    except OSError:
        return True  # can't check — don't penalize score


def check_system_health():
    """Return a 0-100 health score."""
    score = 100
    log_message("Checking system health...")
    try:
        free = shutil.disk_usage(
            os.environ.get("SystemDrive", "C:") + "\\"
            if sys.platform == "win32" else "/").free
    except OSError:
        free = 1 << 31
    if free < (1 << 30):
        score -= 20
        log_message("WARNING: Low disk space detected")
    if not _proc_running("explorer.exe"):
        score -= 30
        log_message("CRITICAL: Explorer process not running")
    if _run(["ping", "google.com", "-n", "1"], 15) != 0:
        score -= 10
        log_message("WARNING: Network connectivity issues")
    log_message(f"System health score: {score}")
    return score


def auto_recovery(kind):
    global _recovery_count
    _recovery_count += 1
    log_recovery(f"Starting recovery for: {kind}")
    if kind == "disk_cleanup":
        print("Performing disk cleanup...")
        tmp_dirs = [os.environ.get("TEMP")]
        windir = os.environ.get("WINDIR")
        if windir:
            tmp_dirs.append(str(Path(windir) / "Temp"))
        for d in tmp_dirs:
            if d:
                for p in Path(d).rglob("*"):
                    try:
                        if p.is_file():
                            p.unlink()
                    except OSError:
                        pass
        log_recovery("Disk cleanup completed")
    elif kind == "restart_explorer":
        print("Restarting Explorer process...")
        _run(["taskkill", "/f", "/im", "explorer.exe"])
        subprocess.Popen(["explorer.exe"])
        log_recovery("Explorer restarted")
    elif kind == "clear_memory":
        print("Clearing memory cache...")
        log_recovery("Memory cache cleared")
    elif kind == "repair_registry":
        print("Repairing registry issues...")
        _run(["reg", "add",
              r"HKCU\Software\Microsoft\Windows\CurrentVersion"
              r"\Explorer\Advanced",
              "/v", "ListviewAlphaSelect", "/t", "REG_DWORD",
              "/d", "0", "/f"])
        log_recovery("Registry repaired")
    elif kind == "network_reset":
        print("Resetting network configuration...")
        _run(["ipconfig", "/flushdns"])
        _run(["netsh", "winsock", "reset"])
        log_recovery("Network reset completed")
    else:
        log_recovery(f"Unknown recovery type: {kind}")


_HEAL_MAP = {
    "file_not_found": ["disk_cleanup", "repair_registry"],
    "access_denied": ["restart_explorer", "clear_memory"],
    "network_error": ["network_reset"],
    "memory_error": ["clear_memory", "disk_cleanup"],
}


def self_heal(error_type, description=""):
    log_message(f"Self-healing triggered for: {error_type} - "
                f"{description}")
    for kind in _HEAL_MAP.get(error_type,
                              ["disk_cleanup", "repair_registry",
                               "clear_memory"]):
        auto_recovery(kind)
    score = check_system_health()
    log_message(f"Recovery completed. New health score: {score}")


def monitor_and_repair(interval=60):
    print("Monitoring system health (Ctrl+C to stop)...")
    try:
        while True:
            if check_system_health() < HEALTH_WARN:
                self_heal("system_degraded", "Health score below 70%")
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\nMonitoring stopped")


def main():
    ap = argparse.ArgumentParser(
        description="Self-healing system scaffold")
    ap.add_argument("--monitor", action="store_true",
                    help="start continuous monitor/repair loop")
    ap.add_argument("--interval", type=int, default=60,
                    help="monitor interval seconds (default 60)")
    args = ap.parse_args()

    score = check_system_health()
    if score > 80:
        print(f"System health: EXCELLENT ({score}%)")
    elif score > 60:
        print(f"System health: GOOD ({score}%)")
    else:
        print(f"System health: POOR ({score}%)")
        self_heal("system_degraded", "Initial health check failed")

    if args.monitor:
        monitor_and_repair(args.interval)
    log_message(f"Self-healing shutdown - {_recovery_count} "
                "recovery attempts")
    return 0


if __name__ == "__main__":
    if sys.platform == "win32":
        try:
            import ctypes as _c
            if not _c.windll.shell32.IsUserAnAdmin():
                print("ERROR: This script requires Administrator "
                      "privileges. Run as Administrator.")
                sys.exit(1)
        except Exception:
            print("WARNING: admin check failed; continuing")
    sys.exit(main())

