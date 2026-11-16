"""Port of scripts/network-soft-reset.ps1 — flush DNS + ARP caches and
restart physical adapters (~10s blip). Once per calendar day via stamp.
--register-task registers the on-demand \\DevOptimizer\\Net-Soft-Reset
task (elevated, far-future trigger, fired via schtasks /run).
"""
# REQUIRES: admin
import ctypes
import datetime
import subprocess
import sys
import time
from pathlib import Path


def _is_admin():
    return bool(ctypes.windll.shell32.IsUserAnAdmin())


LOG = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs"
           + chr(92) + "net-soft-reset.log")
STAMP = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs"
             + chr(92) + ".net-soft-reset-fired")


def log(msg):
    line = time.strftime("%Y-%m-%d %H:%M:%S") + " " + msg
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")
    print(line)


def notify(severity, title, message):
    ps = (
        ". 'D:\\DevOptimizer\\scripts\\lib\\Notify.ps1'\n"
        "Send-DevOptAlert -Severity " + severity + " -Title '" + title
        + "' -Message '" + message + "' -Tags 'network','wsl'"
        " -ErrorAction SilentlyContinue")
    subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                   capture_output=True)


def main():
    elevated = _is_admin()
    if "--register-task" in sys.argv:
        if not elevated:
            log("[task] --register-task needs elevation")
            return 3
        ps = (
            "$act = New-ScheduledTaskAction -Execute "
            "'C:\\Windows\\System32\\conhost.exe' -Argument "
            "'--headless powershell.exe -NoProfile -ExecutionPolicy "
            "Bypass -File \"D:\\DevOptimizer\\scripts"
            "\\network-soft-reset.ps1\"'\n"
            "$trg = New-ScheduledTaskTrigger -Once -At "
            "(Get-Date '2030-01-01')\n"
            "$pri = New-ScheduledTaskPrincipal -UserId $env:USERNAME"
            " -LogonType Interactive -RunLevel Highest\n"
            "Register-ScheduledTask -TaskPath '\\DevOptimizer\\'"
            " -TaskName 'Net-Soft-Reset' -Action $act -Trigger $trg"
            " -Principal $pri -Force | Out-Null")
        r = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                           capture_output=True, text=True)
        if r.returncode != 0:
            log("[task] registration failed: " + (r.stderr or ""))
            return r.returncode
        log("[task] \\DevOptimizer\\Net-Soft-Reset registered "
            "(on-demand, headless, elevated)")
        return 0

    log("=== net-soft-reset start ===")
    if not elevated:
        log("not elevated - adapter restart impossible, aborting")
        return 3
    today = datetime.date.today().isoformat()
    if STAMP.exists() and STAMP.read_text().strip() == today:
        log("already ran today - skipping")
        return 0
    notify("Warning", "Network soft reset",
           "Heal-resistant vsock wedge - flushing DNS/ARP and "
           "restarting physical adapters (~10s blip).")
    subprocess.run(["ipconfig.exe", "/flushdns"], capture_output=True)
    subprocess.run(["netsh.exe", "interface", "ip", "delete",
                    "arpcache"], capture_output=True)
    log("dns resolver + arp cache flushed")
    q = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Get-NetAdapter -Physical -ErrorAction SilentlyContinue"
         " | Where-Object { $_.Status -eq 'Up' -and"
         " $_.InterfaceDescription -notmatch 'Hyper-V|Virtual"
         "|Bluetooth' } | Select-Object -ExpandProperty Name"],
        capture_output=True, text=True)
    adapters = [a.strip() for a in q.stdout.splitlines() if a.strip()]
    for name in adapters:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "Restart-NetAdapter -Name '" + name
             + "' -Confirm:$false"], capture_output=True, text=True)
        if r.returncode == 0:
            log(f"restarting adapter: {name}")
        else:
            log(f"adapter {name} restart failed: "
                + (r.stderr or "").strip())
    time.sleep(8)
    q2 = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "(Get-NetAdapter -Physical -ErrorAction SilentlyContinue"
         " | Where-Object { $_.Status -eq 'Up' }).Count"],
        capture_output=True, text=True)
    back = q2.stdout.strip() or "0"
    subprocess.run(["ipconfig.exe", "/renew"], capture_output=True)
    log(f"adapters back up: {back}/{len(adapters)}")
    STAMP.write_text(today)
    notify("Info", "Network soft reset done",
           f"{back}/{len(adapters)} adapters restarted. If the vsock "
           "wedge persists past this, the remaining fix is a reboot.")
    log("=== net-soft-reset done ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
