"""Port of scripts/register-admin-cleanup-weekly.ps1 — Registers the DevOptimizer\Admin-Cleanup-Weekly task (Sundays 03:00, elevated); logs the result.
"""
# REQUIRES: admin
import ctypes

def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required", file=sys.stderr)
        sys.exit(1)

import datetime
import os
import subprocess
import sys

TASK = "Admin-Cleanup-Weekly"
TASK_PATH = chr(92).join(["", "DevOptimizer", ""])[:-2] if "DevOptimizer" else chr(92)


def main():
    _ensure_admin()
    if "--unregister" in sys.argv:
        subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "Unregister-ScheduledTask -TaskName '" + TASK + "'"
             " -Confirm:$false -ErrorAction SilentlyContinue"])
        print("Unregistered " + TASK_PATH + TASK)
        return 0
    ps = """
$action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\win11-admin-cleanup-scheduled.ps1"')
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '2026-10-11T03:00:00+03:00'
$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId 'tbaltzakis' -LogonType Interactive -RunLevel HighestRegisters the DevOptimizer\Admin-Cleanup-Weekly task (Sundays 03:00, elevated); logs the result.R
Register-ScheduledTask -TaskPath '" + TASK_PATH + "' -TaskName '" + TASK + "' -Action $action -Trigger $trigger -Settings $settings -Principal $principalRegisters the DevOptimizer\Admin-Cleanup-Weekly task (Sundays 03:00, elevated); logs the result.ARG -Force | Out-Null
"""
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True, text=True)
    log = r"D:\DevOptimizer\logs\register-admin-cleanup-weekly.log"
    os.makedirs(os.path.dirname(log), exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(log, "a", encoding="utf-8") as fh:
        fh.write("{stamp} " + ("OK" if r.returncode == 0 else "FAIL " + (r.stderr or "").strip()) + "\n")
    if r.returncode != 0:
        print(r.stderr or "registration failed", file=sys.stderr)
        return r.returncode
    print("Registered " + TASK_PATH + TASK)
    print("Remove with: scripts/py/register-admin-cleanup-weekly.py --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
