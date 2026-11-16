"""Port of scripts/register-housekeeping-task.ps1.

Registers/unregisters the DevOptimizer-Housekeeping scheduled task
(schtasks /create|delete; -Unregister removes it).
"""

import argparse
import os
import subprocess
import sys

TASK_NAME = "DevOptimizer-Housekeeping"
TASK_PATH = "\\"
ACTION = '"C:\\Windows\\System32\\conhost.exe" --headless "D:\\DevOptimizer\\pwsh\\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "D:\\DevOptimizer\\scripts\\devoptimizer-housekeeping.ps1"'
SCHED = ["/sc", "weekly", "/d", "SAT", "/st", "05:30", "/rl", "LIMITED"]


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
         "/ru", user, *SCHED],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(f"Register failed: {r.stderr or r.stdout}")
        return 1
    print(f"Registered {TASK_PATH}{TASK_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
