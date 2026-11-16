"""Port of scripts/register-health-dashboard.ps1 — registers the
\\DevOptimizer\\Health-Dashboard task (logon + every 2 min, hidden,
72h limit).
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


TASK = "Health-Dashboard"
TASK_PATH = chr(92) + "DevOptimizer" + chr(92)


def main():
    _ensure_admin()
    if "--unregister" in sys.argv:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "Unregister-ScheduledTask -TaskName '" + TASK
             + "' -TaskPath '" + TASK_PATH
             + "' -Confirm:$false -ErrorAction SilentlyContinue"])
        print("Unregistered", TASK_PATH + TASK)
        return 0
    ps = (
        "$action   = New-ScheduledTaskAction -Execute 'pwsh.exe'"
        " -Argument '-NoProfile -ExecutionPolicy Bypass -File "
        "\"D:\\DevOptimizer\\scripts\\health-dashboard.ps1\"'\n"
        "$trigger1 = New-ScheduledTaskTrigger -AtLogOn\n"
        "$trigger2 = New-ScheduledTaskTrigger -Once -At "
        "(Get-Date).AddMinutes(2) -RepetitionInterval "
        "(New-TimeSpan -Minutes 2) -RepetitionDuration "
        "(New-TimeSpan -Days 3650)\n"
        "$settings = New-ScheduledTaskSettingsSet "
        "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
        "-StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 72) "
        "-Compatibility Win8\n"
        "$principal = New-ScheduledTaskPrincipal -UserId "
        "(Get-CimInstance Win32_ComputerSystem).UserName "
        "-LogonType Interactive -RunLevel Highest\n"
        "Register-ScheduledTask -TaskName '" + TASK + "' -TaskPath '"
        + TASK_PATH + "' -Action $action -Trigger $trigger1,"
        "$trigger2 -Settings $settings -Principal $principal "
        "-Force | Out-Null\n")
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr or "registration failed", file=sys.stderr)
        return r.returncode
    print("Registered", TASK_PATH + TASK)
    print("Runs: D:\\DevOptimizer\\scripts\\health-dashboard.ps1")
    print("Remove with: scripts/py/register-health-dashboard.py"
          " --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
