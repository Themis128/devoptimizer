"""Port of scripts/register-housekeeping-task.ps1 —
registers/unregisters \\DevOptimizer-Housekeeping (weekly Sat 05:30,
conhost --headless pwsh).
"""
# REQUIRES: admin
import ctypes
import subprocess
import sys
from pathlib import Path


def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required",
              file=sys.stderr)
        sys.exit(1)


TASK = "DevOptimizer-Housekeeping"
TASK_PATH = "\\"
SCRIPT = "devoptimizer-housekeeping.ps1"


def main():
    if "--unregister" in sys.argv:
        subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "Unregister-ScheduledTask -TaskName '" + TASK
             + "' -TaskPath '" + TASK_PATH
             + "' -Confirm:$false -ErrorAction SilentlyContinue"])
        print("Unregistered", TASK_PATH + TASK)
        return 0
    pwsh = "D:" + chr(92) + "DevOptimizer" + chr(92) + "pwsh" \
        + chr(92) + "pwsh.exe"
    if not Path(pwsh).exists():
        pwsh = "pwsh.exe"
    script = "D:" + chr(92) + "DevOptimizer" + chr(92) + "scripts" \
        + chr(92) + SCRIPT
    arg = ("--headless " + chr(34) + pwsh + chr(34)
           + " -NoProfile -ExecutionPolicy Bypass -File " + chr(34)
           + script + chr(34))
    ps = (
        "$nextSat = (Get-Date).Date\n"
        "$nextSat = $nextSat.AddDays((6 - [int]$nextSat.DayOfWeek) % 7)\n"
        "$at = $nextSat.AddHours(5).AddMinutes(30)\n"
        "$action   = New-ScheduledTaskAction -Execute "
        "'C:\\Windows\\System32\\conhost.exe' -Argument '" + arg + "'\n"
        "$trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek "
        "Saturday -At $at\n"
        "$settings = New-ScheduledTaskSettingsSet "
        "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
        "-StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 1) "
        "-Compatibility Win8\n"
        "$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME "
        "-LogonType Interactive -RunLevel Limited\n"
        "Register-ScheduledTask -TaskName '" + TASK + "' -TaskPath '"
        + TASK_PATH + "' -Action $action -Trigger $trigger -Settings "
        "$settings -Principal $principal -Force | Out-Null\n"
        "Get-ScheduledTask -TaskName '" + TASK + "' -TaskPath '"
        + TASK_PATH + "' -ErrorAction Stop | Out-Null\n"
        "Write-Output ('next run: ' + $at.ToString('yyyy-MM-dd HH:mm'))"
        "\n")
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr or "registration failed", file=sys.stderr)
        return r.returncode
    nxt = r.stdout.strip()
    print("Registered", TASK_PATH + TASK,
          "(weekly Saturday 05:30" + (", " + nxt if nxt else "") + ")")
    print("Runs:", script)
    print("Remove with: scripts/py/register-housekeeping-task.py"
          " --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
