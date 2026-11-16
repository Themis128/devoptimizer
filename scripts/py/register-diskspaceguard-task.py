"""Port of scripts/register-diskspaceguard-task.ps1 —
registers/unregisters \\DevOptimizer-DiskSpaceGuard (hourly, pythonw.exe).
"""
# REQUIRES: admin
import ctypes
import subprocess
import sys


def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required",
              file=sys.stderr)
        sys.exit(1)


TASK = "DevOptimizer-DiskSpaceGuard"
TASK_PATH = "\\"
SCRIPT = "D:" + chr(92) + "DevOptimizer" + chr(92) + "scripts" \
    + chr(92) + "check-drive-space.py"


def main():
    if "--unregister" in sys.argv:
        subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "Unregister-ScheduledTask -TaskName '" + TASK
             + "' -TaskPath '" + TASK_PATH
             + "' -Confirm:$false -ErrorAction SilentlyContinue"])
        print("Unregistered", TASK_PATH + TASK)
        return 0
    ps = (
        "$action    = New-ScheduledTaskAction -Execute 'pythonw.exe'"
        " -Argument '" + chr(34) + SCRIPT + chr(34) + "'\n"
        "$trigger   = New-ScheduledTaskTrigger -Once -At "
        "(Get-Date).Date.AddHours(1) -RepetitionInterval "
        "(New-TimeSpan -Hours 1) -RepetitionDuration "
        "(New-TimeSpan -Days 3650)\n"
        "$settings  = New-ScheduledTaskSettingsSet "
        "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
        "-StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Minutes 30) "
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
    print("Registered", TASK_PATH + TASK, "(hourly)")
    print("Runs:", SCRIPT)
    print("Remove with: scripts/py/register-diskspaceguard-task.py"
          " --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
