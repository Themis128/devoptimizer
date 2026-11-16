"""Port of scripts/phone-tailnet-watch.ps1 — detect galaxy-s22 dropping
off the tailnet and relaunch its Tailscale app over ADB (30-min
cooldown, ntfy alert on remediation or unreachable adb).
"""
# REQUIRES: admin
import ctypes
import datetime
import json
import re
import subprocess
import sys
import time
from pathlib import Path


def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required",
              file=sys.stderr)
        sys.exit(1)


LOG = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs"
           + chr(92) + "phone-tailnet-watch.log")
STAMP = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs"
             + chr(92) + ".phone-ts-lastfix")
ADB = ("C:" + chr(92) + "Users" + chr(92) + "tbaltzakis" + chr(92)
       + "AppData" + chr(92) + "Local" + chr(92) + "Android" + chr(92)
       + "Sdk" + chr(92) + "platform-tools" + chr(92) + "adb.exe")
PKG = "com.tailscale.ipn"
PEER = "galaxy-s22"
ENDPOINTS = ["RFCTA0AEKZP", "192.168.1.235:5555",
             "192.168.1.77:5555", "100.84.31.85:5555"]


def log(msg):
    line = time.strftime("%Y-%m-%d %H:%M:%S") + " " + msg
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def notify(severity, message):
    subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         ". 'D:\\DevOptimizer\\scripts\\lib\\Notify.ps1'\n"
         "Send-DevOptAlert -Severity " + severity
         + " -Title 'Phone tailnet watch' -Message '" + message
         + "' -Tags 'phone','tailscale' -ErrorAction "
         "SilentlyContinue"], capture_output=True)


def adb_devices():
    try:
        r = subprocess.run([ADB, "devices"], capture_output=True,
                           text=True, timeout=20)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []
    return [l.split("\t")[0] for l in r.stdout.splitlines()
            if re.search(r"\tdevice$", l)]


def tailscale_peer():
    r = subprocess.run(["tailscale.exe", "status", "--json"],
                       capture_output=True, text=True)
    try:
        status = json.loads(r.stdout) if r.stdout.strip() else None
    except ValueError:
        return None, None
    if not status or status.get("BackendState") != "Running" \
            or not status.get("Peer"):
        return None, None
    for peer in status["Peer"].values():
        if re.search(r"galaxy|s22", peer.get("HostName", "")) \
                or (peer.get("DNSName") or "").startswith(
                    "galaxy-s22."):
            return status, peer
    return status, None


def main():
    _ensure_admin()
    dry = "--dry-run" in sys.argv
    _, peer = tailscale_peer()
    status, peer = tailscale_peer()
    if status is None:
        return 0
    if not peer:
        log(f"{PEER} not in tailnet peer list - node removed? alert")
        return 1
    if peer.get("Online"):
        return 0
    last_seen = peer.get("LastSeen")
    try:
        offline_min = round(
            (datetime.datetime.now(datetime.timezone.utc)
             - datetime.datetime.fromisoformat(
                 last_seen.replace("Z", "+00:00"))).total_seconds()
            / 60)
    except (AttributeError, TypeError, ValueError):
        offline_min = -1
    log(f"{PEER} offline {offline_min}m - attempting adb remediation")
    devs = adb_devices()
    endpoint = next((e for e in ENDPOINTS if e in devs), None)
    if not endpoint:
        endpoint = next(
            (d for d in devs if ":" not in d and d != "emulator-5554"),
            None)
        if not endpoint:
            endpoint = next(
                (d for d in devs
                 if re.match(r"^\d+\.\d+\.\d+\.\d+:\d+$", d)), None)
    if not endpoint:
        for ep in (e for e in ENDPOINTS if ":" in e):
            subprocess.run([ADB, "connect", ep], capture_output=True)
        devs = adb_devices()
        endpoint = next((e for e in ENDPOINTS if e in devs), None)
        if not endpoint:
            endpoint = next(
                (d for d in devs
                 if re.match(r"^\d+\.\d+\.\d+\.\d+:\d+$", d)), None)
    if STAMP.exists() and datetime.datetime.fromtimestamp(
            STAMP.stat().st_mtime) > datetime.datetime.now() \
            - datetime.timedelta(minutes=30):
        log("remediation in 30-min cooldown - skip")
        return 0
    if not endpoint:
        log("adb unreachable (USB + LAN + tailnet endpoints all "
            "failed) - manual check needed")
        notify("Warning",
               f"galaxy-s22 offline {offline_min}m and no adb endpoint"
               " reachable - check wireless debugging / USB.")
        STAMP.touch()
        return 2
    pid = subprocess.run(
        [ADB, "-s", endpoint, "shell", "pidof", PKG],
        capture_output=True, text=True).stdout.strip()
    if pid:
        log(f"app alive (pid {pid}) via {endpoint} but peer offline"
            " - not an app-death; skipping relaunch")
        return 0
    log(f"app dead via {endpoint} - relaunching")
    if not dry:
        subprocess.run(
            [ADB, "-s", endpoint, "shell", "monkey", "-p", PKG,
             "-c", "android.intent.category.LAUNCHER", "1"],
            capture_output=True)
        time.sleep(8)
        aon = subprocess.run(
            [ADB, "-s", endpoint, "shell", "settings", "get",
             "global", "always_on_vpn_app"],
            capture_output=True, text=True).stdout.strip()
        if aon != PKG:
            subprocess.run(
                [ADB, "-s", endpoint, "shell", "settings", "put",
                 "global", "always_on_vpn_app", PKG],
                capture_output=True)
            log(f"pinned always_on_vpn_app -> {PKG}")
    time.sleep(10)
    _, peer2 = tailscale_peer()
    ok = bool(peer2 and peer2.get("Online"))
    STAMP.touch()
    if ok:
        notify("Info",
               f"galaxy-s22 tailscale app was dead - relaunched via "
               f"{endpoint}, node back online.")
    else:
        notify("Warning",
               f"galaxy-s22 relaunched via {endpoint} but node still "
               "offline - may need app UI check.")
    log(f"remediation done via {endpoint} - peer online: {ok}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
