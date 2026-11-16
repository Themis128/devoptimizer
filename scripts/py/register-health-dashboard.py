"""Port of scripts/register-health-dashboard.ps1 — Registers the DevOptimizer\Health-Dashboard task (logon + every 2 min, hidden, 72h limit).
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

TASK = "Health-Dashboard"
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
$action   = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\health-dashboard.ps1"')
$trigger1 = New-ScheduledTaskTrigger -AtLogOn
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration (New-TimeSpan -Days 3650)
$trigger = @($trigger1,$trigger2)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance Win32_ComputerSystem).UserName -LogonType Interactive -RunLevel HighestRegisters the DevOptimizer\Health-Dashboard task (logon + every 2 min, hidden, 72h limit).R
Register-ScheduledTask -TaskPath '" + TASK_PATH + "' -TaskName '" + TASK + "' -Action $action -Trigger $trigger -Settings $settings -Principal $principalRegisters the DevOptimizer\Health-Dashboard task (logon + every 2 min, hidden, 72h limit).ARG -Force | Out-Null
"""
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr or "registration failed", file=sys.stderr)
        return r.returncode
    print("Registered " + TASK_PATH + TASK)
    print("Remove with: scripts/py/register-health-dashboard.py --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
