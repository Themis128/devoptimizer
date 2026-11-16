"""Port of scripts/register-daily-cleanup-task.ps1 — registers/unregisters
the \\DevOptimizer\\Daily-Full-Cleanup task (daily 06:30, conhost --headless).
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


TASK = "Daily-Full-Cleanup"
TASK_PATH = "\\DevOptimizer\\"


def main():
    _ensure_admin()
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
    arg = ("--headless " + chr(34) + pwsh + chr(34)
           + " -NoProfile -ExecutionPolicy Bypass -File " + chr(34)
           + "D:" + chr(92) + "DevOptimizer" + chr(92) + "scripts"
           + chr(92) + "daily-full-cleanup.ps1" + chr(34))
    ps = (
        "$action   = New-ScheduledTaskAction -Execute "
        "'C:\\Windows\\System32\\conhost.exe' -Argument '" + arg + "'\n"
        "$trigger  = New-ScheduledTaskTrigger -Daily -At '06:30'\n"
        "$settings = New-ScheduledTaskSettingsSet "
        "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
        "-StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 2) "
        "-Compatibility Win8\n"
        "$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME "
        "-LogonType Interactive -RunLevel Limited\n"
        "Register-ScheduledTask -TaskName '" + TASK + "' -TaskPath '"
        + TASK_PATH + "' -Action $action -Trigger $trigger -Settings "
        "$settings -Principal $principal -Force | Out-Null\n")
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr or "registration failed", file=sys.stderr)
        return r.returncode
    print("Registered", TASK_PATH + TASK, "(daily 06:30)")
    print("Runs: D:\\DevOptimizer\\scripts\\daily-full-cleanup.ps1")
    print("Remove with: scripts/py/register-daily-cleanup-task.py"
          " --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
