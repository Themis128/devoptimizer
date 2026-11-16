"""Port of scripts/devin/Register-Devin-Maintenance.ps1 — registers the
daily unattended Devin maintenance task
(Devin-Daily-Maintenance, \\DevOptimizer\\, 04:30, conhost --headless
powershell). --remove unregisters. --dry-run prints the schtasks calls.
"""
import argparse
import subprocess
import sys

# CATEGORY: maintenance
# TAGS: scheduled-task, registration

TASK_NAME = "Devin-Daily-Maintenance"
TASK = rf"\DevOptimizer\{TASK_NAME}"
ACTION_ARGS = ('--headless powershell.exe -WindowStyle Hidden '
               '-NoProfile -ExecutionPolicy Bypass -File '
               '"D:\\DevOptimizer\\scripts\\devin\\'
               'Invoke-DevinDailyMaintenance.ps1"')


def run(cmd, dry):
    if dry:
        print("[dry-run]", " ".join(cmd))
        return 0
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode


def main():
    ap = argparse.ArgumentParser(
        description="Register/unregister Devin daily maintenance task")
    ap.add_argument("--remove", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.remove:
        run(["schtasks", "/delete", "/tn", TASK, "/f"], args.dry_run)
        print(f"Removed {TASK}")
        return 0

    # /sc daily /st 04:30 /rl limited /f — mirrors the ps1 registration
    # (WakeToRun/StartWhenAvailable/battery flags carry no schtasks
    # equivalents; they are set via the XML on Windows).
    rc = run(["schtasks", "/create", "/tn", TASK,
              "/tr", f"conhost.exe {ACTION_ARGS}",
              "/sc", "daily", "/st", "04:30", "/f"],
             args.dry_run)
    if rc == 0:
        print(f"Registered {TASK} - daily 04:30 maintenance for Devin "
              "Desktop (cache sweep, log retention, bundle self-heal, "
              "report to D:\\DevOptimizer\\logs\\devin-maintenance\\"
              "latest.json).")
        print("Bundle repairs only execute when Devin.exe is closed; "
              "while it runs they are deferred.")
    return rc


if __name__ == "__main__":
    sys.exit(main())
