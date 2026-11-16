"""Port of scripts/reregister-staggered-tasks.ps1 — re-register all
DevOptimizer scheduled tasks in the 02:15-06:00 window with
staggering, raised ExecutionTimeLimit and headless conhost actions.
Elevated only; --dry-run prints without registering.
"""
# REQUIRES: admin
import ctypes
import os
import shutil
import subprocess
import sys
from pathlib import Path


def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] This script must run elevated (Run as"
              " Administrator)", file=sys.stderr)
        sys.exit(1)


SCRIPT_ROOT = "D:" + chr(92) + "DevOptimizer" + chr(92) + "scripts"
CONHOST = ("C:" + chr(92) + "Windows" + chr(92) + "System32"
           + chr(92) + "conhost.exe")
TASKS = [
    # (name, script, sched, time, days/interval, limit_h, user,
    #  ignore_new, description)
    ("Safe-Cleanup-Daily", "win11-safe-cleanup.ps1", "Daily",
     "02:15", None, 1, "tbaltzakis", False,
     "Daily user-level safe cleanup (temp files, caches, recycle"
     " bin). Runs at 02:15."),
    ("Extended-Cleanup", "extended-cleanup.ps1", "Weekly", "02:45",
     "Monday", 2, "tbaltzakis", False,
     "Weekly extended cleanup (Mon 02:45): age-gated caches, Docker"
     " prune, browser caches."),
    ("DevOptimizer-Elevated-Cleanup", "elevated-complete-cleanup.ps1",
     "DailyInterval", "03:15", 15, 4, "SYSTEM", False,
     "Elevated cleanup every 15 days at 03:15: DISM RestoreHealth,"
     " component store, WU cache, restore points, VHDX analysis."),
    ("WSL-Ubuntu-Cleanup", "wsl-ubuntu-cleanup.ps1", "Daily", "03:30",
     None, 1, "tbaltzakis", False,
     "Daily WSL Ubuntu cleanup (03:30): journal, apt, uv caches."
     " Staggered after elevated cleanup."),
    ("SocialAuto-Maintenance",
     "socialauto" + chr(92) + "Maintain-SocialAuto.ps1", "Daily",
     "04:00", None, 2, "tbaltzakis", False,
     "Daily SocialAuto container health check (04:00). Staggered"
     " after WSL cleanup."),
    ("Devin-Daily-Maintenance",
     "devin" + chr(92) + "Invoke-DevinDailyMaintenance.ps1", "Daily",
     "04:30", None, 1, "tbaltzakis", False,
     "Daily Devin maintenance (04:30): cache sweep, log retention,"
     " bundle-orphan repair."),
    ("Nas-Backup", "backup-docker-nas.ps1", "Daily", "05:30", None, 2,
     "tbaltzakis", False,
     "Nightly Docker + WSL config backup to OMV NAS (05:30)."
     " Size-tiered: nightly <2GB volumes + pg_dumpall, weekly large"
     " volumes + broad home."),
    ("WSL-Vhdx-Compact", "Invoke-VhdxCompaction.ps1", "Daily", "06:00",
     None, 2, "SYSTEM", True,
     "Daily WSL/Docker VHDX compaction (06:00): runs AFTER NAS"
     " backup. Built-in Devin protection gates."),
    ("Admin-Cleanup-Weekly", "win11-admin-cleanup-scheduled.ps1",
     "Weekly", "03:15", "Sunday", 2, "tbaltzakis", True,
     "Weekly elevated Windows admin cleanup (Sun 03:15): DISM"
     " component store + RestoreHealth + SFC + WU cache."),
    ("Devin-Weekly-Restart", "restart-devin-weekly.ps1", "Weekly",
     "03:30", "Sunday", 1, "tbaltzakis", True,
     "Weekly Devin Desktop restart (Sun 03:30) to prevent memory"
     " leaks."),
]


def ps(cmd):
    return subprocess.run(["powershell", "-NoProfile", "-Command",
                           cmd], capture_output=True, text=True)


def main():
    _ensure_admin()
    dry = "--dry-run" in sys.argv
    portable = "D:" + chr(92) + "DevOptimizer" + chr(92) + "pwsh" \
        + chr(92) + "pwsh.exe"
    ps_exe = portable if Path(portable).exists() \
        else shutil.which("powershell.exe") or "powershell.exe"
    print("=== Re-registering DevOptimizer tasks with staggered"
          " schedule ===")
    print(f"Elevated as: {os.environ.get('USERNAME')}")

    def headless(script_file, extra=""):
        return ("--headless " + ps_exe
                + " -NoProfile -ExecutionPolicy Bypass -File \""
                + SCRIPT_ROOT + chr(92) + script_file + "\""
                + (" " + extra if extra else ""))

    for (name, script, sched, at, days, limit_h, user, ignore_new,
         desc) in TASKS:
        arg = headless(script)
        if sched == "Daily":
            trig = f"New-ScheduledTaskTrigger -Daily -At '{at}'"
        elif sched == "Weekly":
            trig = (f"New-ScheduledTaskTrigger -Weekly -DaysOfWeek"
                    f" {days} -At '{at}'")
        else:
            trig = (f"New-ScheduledTaskTrigger -Daily -DaysInterval"
                    f" {days} -At '{at}'")
        mi = " -MultipleInstances IgnoreNew" if ignore_new else ""
        cmd = (
            "$act = New-ScheduledTaskAction -Execute '" + CONHOST
            + "' -Argument '" + arg + "'\n"
            "$trg = " + trig + "\n"
            "$set = New-ScheduledTaskSettingsSet -WakeToRun"
            " -StartWhenAvailable -AllowStartIfOnBatteries"
            " -DontStopIfGoingOnBatteries -ExecutionTimeLimit"
            f" (New-TimeSpan -Hours {limit_h}){mi}\n"
            "$pri = New-ScheduledTaskPrincipal -UserId '" + user
            + "' -LogonType Interactive -RunLevel Highest\n"
            "Register-ScheduledTask -TaskPath '\\DevOptimizer\\'"
            " -TaskName '" + name
            + "' -Action $act -Trigger $trg -Settings $set"
            " -Principal $pri -Description '" + desc
            + "' -Force -ErrorAction Stop | Out-Null")
        print(f"Registering: {name} | {sched} {at} | Limit:"
              f" {limit_h}h | User: {user}")
        if not dry:
            r = ps(cmd)
            if r.returncode == 0 and not r.stderr.strip():
                print(f"  [OK] {name}")
            else:
                print(f"  [FAIL] {name}:"
                      f" {r.stderr.strip()[:200]}")

    # WSL-Memory-Watchdog: every 30 min, 10 min timeout
    arg = headless("check-wsl-memory-pressure.ps1")
    cmd = (
        "$act = New-ScheduledTaskAction -Execute '" + CONHOST
        + "' -Argument '" + arg + "'\n"
        "$trg = New-ScheduledTaskTrigger -Once -At"
        " (Get-Date).AddMinutes(1) -RepetitionInterval"
        " (New-TimeSpan -Minutes 30) -RepetitionDuration"
        " (New-TimeSpan -Days 3650)\n"
        "$set = New-ScheduledTaskSettingsSet -WakeToRun"
        " -StartWhenAvailable -AllowStartIfOnBatteries"
        " -DontStopIfGoingOnBatteries -ExecutionTimeLimit"
        " (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew\n"
        "$pri = New-ScheduledTaskPrincipal -UserId 'tbaltzakis'"
        " -LogonType Interactive -RunLevel Highest\n"
        "Register-ScheduledTask -TaskPath '\\DevOptimizer\\'"
        " -TaskName 'WSL-Memory-Watchdog' -Action $act -Trigger"
        " $trg -Settings $set -Principal $pri -Description 'WSL"
        " swap pressure monitor every 30 min (10 min timeout).'"
        " -Force | Out-Null")
    if not dry:
        ps(cmd)
        print("  [OK] WSL-Memory-Watchdog (every 30 min,"
              " 10 min timeout)")

    # Docker-WSL-Sync daily 04:45
    arg = headless("sync-docker-wsl.ps1")
    cmd = (
        "$act = New-ScheduledTaskAction -Execute '" + CONHOST
        + "' -Argument '" + arg + "'\n"
        "$trg = New-ScheduledTaskTrigger -Daily -At '04:45'\n"
        "$set = New-ScheduledTaskSettingsSet -WakeToRun"
        " -StartWhenAvailable -AllowStartIfOnBatteries"
        " -DontStopIfGoingOnBatteries -ExecutionTimeLimit"
        " (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew\n"
        "$pri = New-ScheduledTaskPrincipal -UserId 'tbaltzakis'"
        " -LogonType Interactive -RunLevel Highest\n"
        "Register-ScheduledTask -TaskPath '\\DevOptimizer\\'"
        " -TaskName 'Docker-WSL-Sync' -Action $act -Trigger $trg"
        " -Settings $set -Principal $pri -Description 'Daily"
        " Docker-WSL sync (04:45): verify bind mounts, restart"
        " on-demand containers.' -Force | Out-Null")
    if not dry:
        ps(cmd)
        print("  [OK] Docker-WSL-Sync (daily 04:45, 30 min timeout)")

    if not dry:
        ps("Get-ScheduledTask -TaskPath '\\DevOptimizer\\'"
           " -ErrorAction SilentlyContinue | Select-Object TaskName,"
           "State | Format-Table -AutoSize")
        print("\n=== Task Schedule Summary ===")
        print("02:15  Safe-Cleanup-Daily (daily, 1h limit)")
        print("02:45  Extended-Cleanup (Mon, 2h limit)")
        print("03:15  DevOptimizer-Elevated-Cleanup (every 15 days,"
              " 4h limit, SYSTEM)")
        print("03:15  Admin-Cleanup-Weekly (Sun, 2h limit)")
        print("03:30  WSL-Ubuntu-Cleanup (daily, 1h limit)")
        print("03:30  Devin-Weekly-Restart (Sun, 1h limit)")
        print("04:00  SocialAuto-Maintenance (daily, 2h limit)")
        print("04:30  Devin-Daily-Maintenance (daily, 1h limit)")
        print("04:45  Docker-WSL-Sync (daily, 30m limit)")
        print("05:30  Nas-Backup (daily, 2h limit)")
        print("06:00  WSL-Vhdx-Compact (daily, 2h limit, SYSTEM)")
        print("\nWSL-Memory-Watchdog: every 30 min (10 min timeout)")
        print("Host-Guard: every 5 min (existing)")
    else:
        print("[DRY RUN] No tasks were actually registered")
    print("\n=== Registration complete ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
