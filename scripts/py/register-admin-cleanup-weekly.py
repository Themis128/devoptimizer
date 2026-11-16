"""Port of scripts/register-admin-cleanup-weekly.ps1 — registers the
\\DevOptimizer\\Admin-Cleanup-Weekly task (Sundays 03:00, elevated);
appends the result to logs\\register-admin-cleanup-weekly.log.
"""
# REQUIRES: admin
import ctypes
import datetime
import os
import subprocess
import sys


def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required",
              file=sys.stderr)
        sys.exit(1)


TASK = "Admin-Cleanup-Weekly"
TASK_PATH = chr(92) + "DevOptimizer" + chr(92)
LOG = "D:" + chr(92) + "DevOptimizer" + chr(92) + "logs" + chr(92) \
    + "register-admin-cleanup-weekly.log"


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
    descr = ("Weekly elevated Windows admin cleanup (DISM component "
             "store + RestoreHealth + SFC + WU cache). Sundays 03:00.")
    ps = (
        "$action   = New-ScheduledTaskAction -Execute 'powershell.exe'"
        " -Argument '-NoProfile -ExecutionPolicy Bypass -File "
        "\"D:\\DevOptimizer\\scripts"
        "\\win11-admin-cleanup-scheduled.ps1\"'\n"
        "$trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek "
        "Sunday -At '2026-10-11T03:00:00+03:00'\n"
        "$settings = New-ScheduledTaskSettingsSet -WakeToRun "
        "-StartWhenAvailable "
        "-ExecutionTimeLimit (New-TimeSpan -Hours 2) "
        "-MultipleInstances IgnoreNew\n"
        "$principal = New-ScheduledTaskPrincipal -UserId 'tbaltzakis' "
        "-LogonType Interactive -RunLevel Highest\n"
        "$descr = '" + descr + "'\n"
        "Register-ScheduledTask -TaskPath '" + TASK_PATH
        + "' -TaskName '" + TASK + "' -Action $action -Trigger "
        "$trigger -Settings $settings -Principal $principal "
        "-Description $descr -Force | Out-Null\n")
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True, text=True)
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(stamp + " " + (
            "OK" if r.returncode == 0
            else "FAIL " + (r.stderr or "").strip()) + "\n")
    if r.returncode != 0:
        print(r.stderr or "registration failed", file=sys.stderr)
        return r.returncode
    print("Registered", TASK_PATH + TASK)
    print("Runs: "
          "D:\\DevOptimizer\\scripts\\win11-admin-cleanup-scheduled.ps1")
    print("Remove with: scripts/py/register-admin-cleanup-weekly.py"
          " --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
