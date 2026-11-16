"""Port of scripts/register-vhdx-devin-exit-task.ps1 —
registers/unregisters the \\Vhdx-Compact-DevinExit task (every 5 min,
limited rights).
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


TASK = "Vhdx-Compact-DevinExit"
TASK_PATH = chr(92)


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
        "$action   = New-ScheduledTaskAction -Execute 'C:\\Windows\\System32\\conhost.exe'"
        " -Argument '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass "
        "-WindowStyle Hidden -File "
        "\"D:\\DevOptimizer\\scripts\\vhdx-compact-on-devin-exit.ps1\"'"
        "\n"
        "$trigger  = New-ScheduledTaskTrigger -Once -At (Get-Date)"
        " -RepetitionInterval (New-TimeSpan -Minutes 5)\n"
        "$settings = New-ScheduledTaskSettingsSet "
        "-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries "
        "-StartWhenAvailable -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Minutes 10) "
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
    print("Registered", TASK_PATH + TASK, "(every 5 min)")
    print("Runs: "
          "D:\\DevOptimizer\\scripts\\vhdx-compact-on-devin-exit.ps1")
    print("Remove with: scripts/py/register-vhdx-devin-exit-task.py"
          " --unregister")
    return 0


if __name__ == "__main__":
    sys.exit(main())
