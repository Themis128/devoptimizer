"""Port of scripts/devin/Register-Devin-Maintenance.ps1 — registers the
daily unattended Devin maintenance task
(Devin-Daily-Maintenance, \\DevOptimizer\\, 04:30, conhost --headless
powershell) with the original's full settings (WakeToRun,
StartWhenAvailable, battery flags, restart policy, 30min limit,
IgnoreNew). Runs the same ScheduledTask cmdlets via PowerShell.
--remove unregisters. --dry-run prints the script.
"""
import argparse
import subprocess
import sys

# CATEGORY: maintenance
# TAGS: scheduled-task, registration

TASK_PATH = "\\DevOptimizer\\"
TASK_NAME = "Devin-Daily-Maintenance"

REGISTER_PS = r'''
$action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument '--headless powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\devin\Invoke-DevinDailyMaintenance.ps1"' `
    -WorkingDirectory 'D:\DevOptimizer'
$trigger = New-ScheduledTaskTrigger -Daily -At '04:30'
$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
try {
Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Devin-Daily-Maintenance' -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction Stop | Out-Null
Write-Host "Registered"
} catch {
Write-Error $_.Exception.Message
exit 1
}
'''  # noqa: E501

REMOVE_PS = ("Unregister-ScheduledTask -TaskPath '\\DevOptimizer\\' "
             "-TaskName 'Devin-Daily-Maintenance' -Confirm:$false "
             "-ErrorAction SilentlyContinue")


def run_ps(script, dry):
    if dry:
        print("[dry-run] powershell:")
        print(script)
        return 0
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        script], capture_output=True, text=True)
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip(), file=sys.stderr)
    return r.returncode


def main():
    ap = argparse.ArgumentParser(
        description="Register/unregister Devin daily maintenance task")
    ap.add_argument("--remove", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.remove:
        run_ps(REMOVE_PS, args.dry_run)
        print(f"Removed {TASK_PATH}{TASK_NAME}")
        return 0

    rc = run_ps(REGISTER_PS, args.dry_run)
    if rc == 0:
        print(f"Registered {TASK_PATH}{TASK_NAME} - daily 04:30 "
              "maintenance for Devin Desktop (cache sweep, log "
              "retention, bundle self-heal, report to "
              "D:\\DevOptimizer\\logs\\devin-maintenance\\"
              "latest.json).")
        print("Bundle repairs only execute when Devin.exe is closed; "
              "while it runs they are deferred.")
    return rc


if __name__ == "__main__":
    sys.exit(main())
