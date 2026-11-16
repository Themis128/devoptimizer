"""Port of scripts/Insider-Automation.ps1.

Operation dispatcher: autosetup / dailyhealth / weeklyscan /
preupdate / postupdate report through DevOptimizer-Core.ps1
primitives (still present, excluded from migration), while
scheduled-task install/remove is done natively via schtasks.
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = REPO_ROOT / "scripts"
SELF_PS1 = SCRIPTS / "Insider-Automation.ps1"
CORE = SCRIPTS / "DevOptimizer-Core.ps1"

TASK_DAILY = "DevOptimizer-DailyHealthCheck"
TASK_WEEKLY = "DevOptimizer-WeeklyDeepScan"


def pwsh(cmd, capture=True):
    exe = shutil.which("pwsh") or shutil.which("powershell")
    return subprocess.run(
        [exe, "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-Command", cmd],
        capture_output=capture, text=True)


def ps_op(operation):
    """Delegate module-dependent ops to the original script so
    every DevOptimizer-Core primitive resolves identically."""
    exe = shutil.which("pwsh") or shutil.which("powershell")
    return subprocess.run(
        [exe, "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-File", str(SELF_PS1),
         "-Operation", operation, "-Silent"]).returncode


def install_daily(time="09:00", force=False):
    if force:
        subprocess.run(["schtasks", "/delete", "/tn", TASK_DAILY,
                        "/f"], capture_output=True)
    action = ("conhost.exe --headless powershell.exe "
              f"-ExecutionPolicy Bypass -File \"{SELF_PS1}\" "
              "-Operation dailyhealth -Silent")
    r = subprocess.run(
        ["schtasks", "/create", "/tn", TASK_DAILY,
         "/tr", action, "/sc", "daily", "/st", time,
         "/ru", "SYSTEM", "/rl", "HIGHEST", "/f"],
        capture_output=True, text=True)
    ok = r.returncode == 0
    print(("SUCCESS" if ok else "ERROR")
          + f": daily health check scheduled for {time}")
    if not ok:
        print(r.stderr or r.stdout)
    return ok


def install_weekly(day="Sunday", time="02:00", force=False):
    if force:
        subprocess.run(["schtasks", "/delete", "/tn", TASK_WEEKLY,
                        "/f"], capture_output=True)
    action = ("conhost.exe --headless powershell.exe "
              f"-ExecutionPolicy Bypass -File \"{SELF_PS1}\" "
              "-Operation weeklyscan -Silent")
    r = subprocess.run(
        ["schtasks", "/create", "/tn", TASK_WEEKLY,
         "/tr", action, "/sc", "weekly", "/d", day[:3].upper(),
         "/st", time, "/ru", "SYSTEM", "/rl", "HIGHEST", "/f"],
        capture_output=True, text=True)
    ok = r.returncode == 0
    print(("SUCCESS" if ok else "ERROR")
          + f": weekly deep scan scheduled for {day} {time}")
    if not ok:
        print(r.stderr or r.stdout)
    return ok


def remove_schedules():
    ok = True
    for tn in (TASK_DAILY, TASK_WEEKLY):
        r = subprocess.run(["schtasks", "/delete", "/tn", tn,
                            "/f"], capture_output=True, text=True)
        if r.returncode == 0:
            print(f"Removed scheduled task: {tn}")
        else:
            ok = False
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-Operation", "--operation", default="")
    ap.add_argument("-Time", default=None)
    ap.add_argument("-Day", default=None)
    ap.add_argument("-Force", action="store_true")
    ap.add_argument("-Silent", action="store_true")
    args = ap.parse_args()
    op = args.operation.lower()
    if not op:
        print("Specify -Operation: autosetup|dailyhealth|"
              "weeklyscan|preupdate|postupdate|scheduledaily|"
              "scheduleweekly|removeschedules")
        return 1
    if op in ("autosetup", "dailyhealth", "weeklyscan",
              "preupdate", "postupdate"):
        if not CORE.exists():
            print(f"core module missing: {CORE}")
            return 1
        return ps_op(op)
    if op == "scheduledaily":
        return 0 if install_daily(args.Time or "09:00",
                                  args.Force) else 1
    if op == "scheduleweekly":
        return 0 if install_weekly(args.Day or "Sunday",
                                   args.Time or "02:00",
                                   args.Force) else 1
    if op == "removeschedules":
        return 0 if remove_schedules() else 1
    print(f"Unknown operation: {args.operation}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
