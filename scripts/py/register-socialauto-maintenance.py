"""Port of scripts/socialauto/Register-SocialAuto-Maintenance.ps1 —
registers/removes \\DevOptimizer\\SocialAuto-Maintenance (daily 04:00).
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


TASK = "SocialAuto-Maintenance"
TASK_PATH = "\\DevOptimizer\\"
SCRIPT = "D:" + chr(92) + "DevOptimizer" + chr(92) + "scripts" \
    + chr(92) + "socialauto" + chr(92) + "Maintain-SocialAuto.ps1"


def main():
    if "--remove" in sys.argv or "--unregister" in sys.argv:
        subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "Unregister-ScheduledTask -TaskPath '" + TASK_PATH
             + "' -TaskName '" + TASK
             + "' -Confirm:$false -ErrorAction SilentlyContinue"])
        print("Removed", TASK_PATH + TASK)
        return 0
    if not Path(SCRIPT).exists():
        print(f"[FAIL] {SCRIPT} not found - install the Hub first.",
              file=sys.stderr)
        return 1
    arg = ("-NoProfile -ExecutionPolicy Bypass -File " + chr(34)
           + SCRIPT + chr(34))
    ps = (
        "$action = New-ScheduledTaskAction -Execute 'C:\\Windows\\System32\\conhost.exe'"
        " -Argument '" + arg + "'\n"
        "$trigger = New-ScheduledTaskTrigger -Daily -At '04:00'\n"
        "$settings = New-ScheduledTaskSettingsSet "
        "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
        "-StartWhenAvailable "
        "-ExecutionTimeLimit (New-TimeSpan -Minutes 30) "
        "-MultipleInstances IgnoreNew\n"
        "$principal = New-ScheduledTaskPrincipal -UserId "
        '"$env:USERDOMAIN\\$env:USERNAME" -LogonType Interactive\n'
        "Register-ScheduledTask -TaskPath '" + TASK_PATH
        + "' -TaskName '" + TASK + "' -Action $action -Trigger "
        "$trigger -Settings $settings -Principal $principal -Force "
        "| Out-Null\n")
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr or "registration failed", file=sys.stderr)
        return r.returncode
    print("Registered", TASK_PATH + TASK,
          "- runs Maintain-SocialAuto.ps1 daily at 04:00.")
    print("Zero-downtime by design: prunes exited containers/dangling "
          "images/old build")
    print("cache, reports unhealthy containers and DMR health. "
          "No healthy container is")
    print("ever restarted; -Remediate stays opt-in via a manual Hub "
          "run.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
