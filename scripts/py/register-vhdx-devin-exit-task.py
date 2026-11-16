"""Port of scripts/register-vhdx-devin-exit-task.ps1 — Registers/unregisters the Vhdx-Compact-DevinExit task (every 5 min, limited rights).
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

TASK = "Vhdx-Compact-DevinExit"
TASK_PATH = chr(92).join(["", "", ""])[:-2] if "" else chr(92)


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
$action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\DevOptimizer\scripts\vhdx-compact-on-devin-exit.ps1"')
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel LimitedRegisters/unregisters the Vhdx-Compact-DevinExit task (every 5 min, limited rights).R
Register-ScheduledTask -TaskPath '" + TASK_PATH + "' -TaskName '" + TASK + "' -Action $action -Trigger $trigger -Settings $settings -Principal $principalRegisters/unregisters the Vhdx-Compact-DevinExit task (every 5 min, limited rights).ARG -Force | Out-Null
"""
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr or "registration failed", file=sys.stderr)
        return r.returncode
    print("Registered " + TASK_PATH + TASK)
    print("Remove with: scripts/py/register-vhdx-devin-exit-task.py --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
