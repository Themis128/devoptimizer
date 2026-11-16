"""Port of scripts/register-diskspaceguard-task.ps1.

Registers/unregisters the DevOptimizer-DiskSpaceGuard scheduled task
(schtasks /create|delete; -Unregister removes it).
"""

import argparse
import os
import subprocess
import sys

TASK_NAME = "DevOptimizer-DiskSpaceGuard"
TASK_PATH = "\\"
ACTION = '"pythonw.exe" "D:\\DevOptimizer\\scripts\\check-drive-space.py"'
SCHED = ["/sc", "hourly", "/mo", "1", "/rl", "LIMITED"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Unregister", action="store_true")
    a = ap.parse_args()
    if a.Unregister:
        subprocess.run(["schtasks", "/delete", "/f",
                        "/tn", TASK_PATH + TASK_NAME],
                       capture_output=True)
        print(f"Unregistered {TASK_PATH}{TASK_NAME}")
        return 0
    user = os.environ.get("USERNAME", "")
    r = subprocess.run(
        ["schtasks", "/create", "/f", "/tn",
         TASK_PATH + TASK_NAME, "/tr", ACTION,
         "/ru", user, "/it", *SCHED],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(f"Register failed: {r.stderr or r.stdout}")
        return 1
    settings = (
        "Set-ScheduledTask -TaskName '" + TASK_NAME +
        "' -TaskPath '" + TASK_PATH +
        "' -Settings (New-ScheduledTaskSettingsSet "
        "-AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries "
        "-StartWhenAvailable)")
    subprocess.run(["powershell", "-NoProfile",
                    "-Command", settings],
                   capture_output=True, text=True)
    print(f"Registered {TASK_PATH}{TASK_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
