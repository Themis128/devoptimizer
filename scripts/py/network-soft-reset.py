"""Port of scripts/network-soft-reset.ps1.

# REQUIRES: admin

Soft network-stack reset (the automatable `netsh winsock
reset` alternative): DNS flush + ARP clear + physical
adapter restart + DHCP renew. Once per calendar day via
stamp file. -RegisterTask registers the on-demand
\\DevOptimizer\\Net-Soft-Reset task (far-future Once,
Highest, headless conhost powershell). Exit 3 when not
elevated.
"""

import argparse
import ctypes
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

LOG = Path(r"D:\DevOptimizer\logs\net-soft-reset.log")
STAMP = Path(r"D:\DevOptimizer\logs\.net-soft-reset-fired")
NOTIFY = Path(r"D:\DevOptimizer\scripts\lib\Notify.ps1")


def log(m):
    line = f"{datetime.now():%Y-%m-%d %H:%M:%S} {m}"
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def run(cmd, timeout=120, env=None):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=timeout,
                              env=env)
    except Exception:
        return None


def alert(sev, title, msg, tags):
    env = dict(os.environ,
               DEVOPT_ALERT_TITLE=title,
               DEVOPT_ALERT_MSG=msg)
    run(["pwsh", "-NoProfile", "-Command",
         f". '{NOTIFY}'; Send-DevOptAlert -Severity {sev} "
         "-Title $env:DEVOPT_ALERT_TITLE "
         "-Message $env:DEVOPT_ALERT_MSG "
         f"-Tags {tags} -ErrorAction SilentlyContinue"],
        timeout=60, env=env)


def elevated():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def register_task():
    if not elevated():
        log("[task] -RegisterTask needs elevation")
        return 3
    action = ('"C:\\Windows\\System32\\conhost.exe" '
              '--headless powershell.exe -NoProfile '
              '-ExecutionPolicy Bypass -File '
              '"D:\\DevOptimizer\\scripts\\'
              'network-soft-reset.ps1"')
    user = os.environ.get("USERNAME", "")
    subprocess.run(
        ["schtasks", "/create", "/f", "/tn",
         "\\DevOptimizer\\Net-Soft-Reset", "/tr", action,
         "/ru", user, "/it", "/rl", "HIGHEST",
         "/sc", "once", "/st", "00:00", "/sd", "01/01/2030"],
        capture_output=True, text=True)
    log("[task] \\DevOptimizer\\Net-Soft-Reset registered "
        "(on-demand, headless, elevated)")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-RegisterTask", action="store_true")
    a = ap.parse_args()
    if a.RegisterTask:
        return register_task()

    log("=== net-soft-reset start ===")
    if not elevated():
        log("not elevated - adapter restart impossible, "
            "aborting")
        return 3

    today = datetime.now().strftime("%Y-%m-%d")
    if (STAMP.exists()
            and STAMP.read_text().strip() == today):
        log("already ran today - skipping")
        return 0

    alert("Warning", "Network soft reset",
          "Heal-resistant vsock wedge - flushing DNS/ARP "
          "and restarting physical adapters (~10s blip).",
          "'network','wsl'")

    run(["ipconfig.exe", "/flushdns"])
    run(["netsh.exe", "interface", "ip",
         "delete", "arpcache"])
    log("dns resolver + arp cache flushed")

    get_up = ("Get-NetAdapter -Physical "
              "-ErrorAction SilentlyContinue | "
              "Where-Object { $_.Status -eq 'Up' -and "
              "$_.InterfaceDescription -notmatch "
              "'Hyper-V|Virtual|Bluetooth' } | "
              "Select-Object -ExpandProperty Name")
    r = run(["powershell", "-NoProfile", "-Command",
             get_up])
    adapters = [x for x in (r.stdout if r else "")
                .splitlines() if x.strip()]
    for name in adapters:
        rr = run(["powershell", "-NoProfile", "-Command",
                  f"Restart-NetAdapter -Name '{name}' "
                  "-Confirm:$false -ErrorAction Stop"])
        if rr is None or rr.returncode != 0:
            log(f"adapter {name} restart failed: "
                f"{(rr.stderr if rr else 'timeout')}"
                .strip())
        else:
            log(f"restarting adapter: {name}")

    time.sleep(8)
    rb = run(["powershell", "-NoProfile", "-Command",
              "Get-NetAdapter -Physical "
              "-ErrorAction SilentlyContinue | "
              "Where-Object { $_.Status -eq 'Up' } | "
              "Select-Object -ExpandProperty Name"])
    back = [x for x in (rb.stdout if rb else "")
            .splitlines() if x.strip()]
    run(["ipconfig.exe", "/renew"])
    log(f"adapters back up: {len(back)}/{len(adapters)}")

    STAMP.write_text(today)
    alert("Info", "Network soft reset done",
          f"{len(back)}/{len(adapters)} adapters "
          "restarted. If the vsock wedge persists past "
          "this, the remaining fix is a reboot.",
          "'network','wsl'")
    log("=== net-soft-reset done ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
