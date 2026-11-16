"""Port of scripts/repair-phone-notifications.ps1 — keep the Nextcloud
Android app under Android's 50-notification cap: force-stop + relaunch
when posted NotificationRecords >= threshold.
"""
# REQUIRES: admin
import ctypes
import os
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
           + chr(92) + "phone-notify-watchdog.log")


def log(msg):
    line = time.strftime("%Y-%m-%d %H:%M:%S") + " " + msg
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        if LOG.exists() and LOG.stat().st_size > 1_048_576:
            tail = LOG.read_text(encoding="utf-8",
                                 errors="replace").splitlines()[-2000:]
            LOG.write_text("\n".join(tail) + "\n", encoding="utf-8")
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass
    print(line)


def find_adb():
    cands = [
        os.path.join(os.environ.get("LOCALAPPDATA", ""),
                     "Android", "Sdk", "platform-tools", "adb.exe"),
        os.path.join(os.environ.get("ANDROID_HOME", ""),
                     "platform-tools", "adb.exe"),
        os.path.join(os.environ.get("ANDROID_SDK_ROOT", ""),
                     "platform-tools", "adb.exe"),
    ]
    for c in cands:
        if c and Path(c).exists():
            return c
    return "adb.exe"


def adb_shell(adb, serial, cmd):
    r = subprocess.run([adb, "-s", serial, "shell", cmd],
                       capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def main():
    _ensure_admin()
    serial, package = "RFCTA0AEKZP", "com.nextcloud.client"
    threshold, dry_run = 40, "--dry-run" in sys.argv
    for i, a in enumerate(sys.argv):
        if a == "--serial" and i + 1 < len(sys.argv):
            serial = sys.argv[i + 1]
        if a == "--package" and i + 1 < len(sys.argv):
            package = sys.argv[i + 1]
        if a == "--threshold" and i + 1 < len(sys.argv):
            threshold = int(sys.argv[i + 1])
    adb = find_adb()
    if not adb:
        log("[adb] not found - skipping")
        return 0
    log(f"=== phone notify check (dryRun={dry_run} serial={serial}"
        f" pkg={package}) ===")
    try:
        devices = subprocess.run([adb, "devices"], capture_output=True,
                                 text=True, timeout=25).stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        log("[adb] not found - skipping")
        return 0
    if not re.search(r"(?m)^" + re.escape(serial) + r"\s+device",
                     devices):
        log(f"[{serial}] not connected - skipping")
        return 0
    code, dump = adb_shell(adb, serial,
                           "dumpsys notification --noredact")
    if code != 0:
        log(f"[dumpsys] failed exit={code} - skipping")
        return 0
    pat = ("NotificationRecord\\(0x[0-9a-fA-F]+: pkg="
           + re.escape(package))
    count = len(re.findall(pat, dump))
    log(f"[notify] {package} records={count} threshold={threshold}")
    if count < threshold:
        log("=== phone notify check done (healthy) ===")
        return 0
    log(f"[notify] OVER THRESHOLD - clearing {package} notifications")
    if dry_run:
        log("[notify] dryRun - would force-stop and relaunch")
        log("=== phone notify check done ===")
        return 0
    stop_code, _ = adb_shell(adb, serial, f"am force-stop {package}")
    time.sleep(2)
    launch_code, _ = adb_shell(
        adb, serial,
        f"monkey -p {package} -c android.intent.category.LAUNCHER 1")
    time.sleep(5)
    _, recount = adb_shell(adb, serial,
                           "dumpsys notification --noredact")
    after = len(re.findall(pat, recount))
    log(f"[notify] cleared: forceStopExit={stop_code}"
        f" launchExit={launch_code} records {count} -> {after}")
    log("=== phone notify check done ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
