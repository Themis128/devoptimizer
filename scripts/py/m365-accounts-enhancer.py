"""M365 accounts enhancer (port of
tools/Variants/M365-ACCOUNTS-ENHANCER-*.bat).

10-item menu: login fix, services reset, outlook config, teams
optimization, onedrive sync fix, security settings, health check,
office repair, complete reset, account report. --choice N for
non-interactive; --admin variant. Mutating; --dry-run.
"""

import argparse
import subprocess
import sys

# CATEGORY: utilities
# TAGS: m365, office, menu

OFFICE_SVC = ["Office 16 Click-to-Run Service",
              "Microsoft Office Subscription Service"]


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def run(cmd, dry):
    if dry:
        print("[dry-run] " + " ".join(cmd))
        return 0
    return subprocess.run(cmd).returncode


def m365_login_fix(dry):
    for svc in OFFICE_SVC:
        run(["net", "stop", svc], dry)
    run(["powershell", "-Command",
         "Get-AppxPackage Microsoft.AAD.BrokerPlugin | "
         "Reset-AppxPackage"], dry)
    run(["powershell", "-Command",
         r"Remove-Item -Path "
         r"'HKCU:\Software\Microsoft\Office\16.0\Common\Identity\Identities' "
         "-Recurse -Force -ErrorAction SilentlyContinue"], dry)
    for svc in OFFICE_SVC:
        run(["net", "start", svc], dry)


def services_reset(dry):
    for svc in OFFICE_SVC:
        run(["net", "stop", svc], dry)
        run(["net", "start", svc], dry)


def outlook_config(dry):
    run(["taskkill", "/f", "/im", "outlook.exe"], dry)
    run(["powershell", "-Command",
         "Start-Process outlook -ArgumentList '/safe'"], dry)


def teams_optimization(dry):
    for im in ("teams.exe", "Teams.exe"):
        run(["taskkill", "/f", "/im", im], dry)
    run(["powershell", "-Command",
         "Remove-Item -Path \"$env:APPDATA\\Microsoft\\Teams\\Cache\" "
         "-Recurse -Force -ErrorAction SilentlyContinue"], dry)


def onedrive_sync_fix(dry):
    for im in ("OneDrive.exe", "OneDriveSetup.exe"):
        run(["taskkill", "/f", "/im", im], dry)
    run(["powershell", "-Command",
         "Start-Process \"$env:LOCALAPPDATA\\Microsoft\\OneDrive"
         "\\OneDrive.exe\" -ArgumentList '/reset'"], dry)


def security_settings(dry):
    run(["powershell", "-Command",
         "Set-MpPreference -DisableRealtimeMonitoring $false"], dry)
    run(["reg", "add",
         r"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU",
         "/v", "NoAutoUpdate", "/t", "REG_DWORD", "/d", "0", "/f"], dry)
    run(["reg", "add",
         r"HKCU\Software\Microsoft\Office\16.0\Common\Security",
         "/v", "DisableInternetFilesInPV", "/t", "REG_DWORD", "/d", "0",
         "/f"], dry)


def health_check(dry):
    run(["powershell", "-Command",
         "Get-Service | Where-Object {$_.DisplayName -like '*Office*' "
         "-or $_.DisplayName -like '*Microsoft*365*'} | "
         "Format-Table -AutoSize"], dry)


def office_repair(dry):
    run(["net", "stop", "Microsoft Office Click-to-Run Service"], dry)
    run(["powershell", "-Command",
         "Start-Process \"C:\\Program Files\\Common Files\\microsoft "
         "shared\\ClickToRun\\OfficeClickToRun.exe\" -ArgumentList "
         "'scenario=Repair','RepairType=QuickRepair'"], dry)


def account_report(dry):
    run(["powershell", "-Command",
         r"Get-ItemProperty 'HKCU:\Software\Microsoft\Office\16.0"
         r"\Common\Identity\*' -ErrorAction SilentlyContinue | "
         "Select-Object * | Format-List"], dry)


ACTIONS = [("M365 Login Fix", m365_login_fix),
           ("M365 Services Reset", services_reset),
           ("Outlook Configuration", outlook_config),
           ("Teams Optimization", teams_optimization),
           ("OneDrive Sync Fix", onedrive_sync_fix),
           ("Security Settings", security_settings),
           ("Account Health Check", health_check),
           ("Office Repair", office_repair),
           ("Complete M365 Reset", None),
           ("Account Report", account_report)]


def apply(choice, dry):
    if choice == 9:
        for fn in (m365_login_fix, services_reset, outlook_config,
                   teams_optimization, onedrive_sync_fix,
                   security_settings, office_repair):
            fn(dry)
        return
    ACTIONS[choice - 1][1](dry)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--choice", default="")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)

    if args.choice:
        if args.choice.isdigit() and 1 <= int(args.choice) <= 10:
            apply(int(args.choice), args.dry_run)
        return
    if not sys.stdin.isatty():
        for i, (name, _) in enumerate(ACTIONS, 1):
            print(f"{i}. {name}")
        print("(non-interactive: pass --choice N)", file=sys.stderr)
        return
    for i, (name, _) in enumerate(ACTIONS, 1):
        print(f"{i}. {name}")
    c = input("Enter your choice (0-10): ").strip()
    if c.isdigit() and 1 <= int(c) <= 10:
        apply(int(c), args.dry_run)


if __name__ == "__main__":
    main()
