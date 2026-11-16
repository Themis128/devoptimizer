"""Port of scripts/repair-phone-notifications.ps1.

Phone notification watchdog - keeps the Nextcloud Android
app under Android's 50-notifications-per-package cap.
Counts posted NotificationRecords via adb dumpsys; at
-Threshold (default 40) force-stops + relaunches the app.
-DryRun reports only. Log rotates at ~1 MB (tail 2000).
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

LOG = Path(r"D:\DevOptimizer\logs\phone-notify-watchdog.log")
ROOT = Path("D:/DevOptimizer")


def log(msg):
    line = f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}"
    try:
        if LOG.exists() and LOG.stat().st_size > 1_000_000:
            tail = LOG.read_text(
                encoding="utf-8",
                errors="replace").splitlines()[-2000:]
            LOG.write_text("\n".join(tail),
                           encoding="utf-8")
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass
    print(line)


def find_adb(custom):
    if custom:
        return custom if Path(custom).exists() else None
    local = os.environ.get("LOCALAPPDATA", "")
    for c in (local + r"\Android\Sdk\platform-tools\adb.exe",
              os.environ.get("ANDROID_HOME", "")
              + r"\platform-tools\adb.exe",
              os.environ.get("ANDROID_SDK_ROOT", "")
              + r"\platform-tools\adb.exe"):
        if c and Path(c).exists():
            return c
    return shutil.which("adb.exe") or shutil.which("adb")


def adb_shell(adb, serial, cmd):
    r = subprocess.run([adb, "-s", serial, "shell", cmd],
                       capture_output=True, text=True)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Serial", default="RFCTA0AEKZP")
    ap.add_argument("-Package",
                    default="com.nextcloud.client")
    ap.add_argument("-Threshold", type=int, default=40)
    ap.add_argument("-AdbPath", default="")
    ap.add_argument("-Root", default=r"D:\DevOptimizer")
    ap.add_argument("-DryRun", action="store_true")
    a = ap.parse_args()

    global LOG
    LOG = Path(a.Root) / "logs" / "phone-notify-watchdog.log"

    adb = find_adb(a.AdbPath)
    if not adb:
        log("[adb] not found - skipping")
        return 0

    log(f"=== phone notify check (dryRun={a.DryRun} "
        f"serial={a.Serial} pkg={a.Package}) ===")

    r = subprocess.run([adb, "devices"],
                       capture_output=True, text=True)
    devs = (r.stdout or "")
    if not re.search(rf"(?m)^{re.escape(a.Serial)}\s+device",
                     devs):
        log(f"[{a.Serial}] not connected - skipping")
        return 0

    code, dump = adb_shell(adb, a.Serial,
                           "dumpsys notification --noredact")
    if code != 0:
        log(f"[dumpsys] failed exit={code} - skipping")
        return 0
    pat = (r"NotificationRecord\(0x[0-9a-fA-F]+: pkg="
           + re.escape(a.Package))
    count = len(re.findall(pat, dump))
    log(f"[notify] {a.Package} records={count} "
        f"threshold={a.Threshold}")

    if count < a.Threshold:
        log("=== phone notify check done (healthy) ===")
        return 0

    log(f"[notify] OVER THRESHOLD - clearing "
        f"{a.Package} notifications")
    if a.DryRun:
        log("[notify] dryRun - would force-stop and "
            "relaunch")
        log("=== phone notify check done ===")
        return 0

    sc, _ = adb_shell(adb, a.Serial,
                      f"am force-stop {a.Package}")
    time.sleep(2)
    lc, _ = adb_shell(
        adb, a.Serial,
        f"monkey -p {a.Package} "
        "-c android.intent.category.LAUNCHER 1")
    time.sleep(5)
    _, recheck = adb_shell(
        adb, a.Serial, "dumpsys notification --noredact")
    after = len(re.findall(pat, recheck))
    log(f"[notify] cleared: forceStopExit={sc} "
        f"launchExit={lc} records {count} -> {after}")
    log("=== phone notify check done ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
