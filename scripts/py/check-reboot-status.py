"""Port of scripts/check-reboot-status.ps1.

Read-only: last boot/uptime, build, pending-reboot
markers (PendingFileRenameOperations, WU
RebootRequired, CBS RebootPending), drive free space,
key services, vmmemWSL working set, PRI-Driver start
type.
"""

import ctypes
import re
import shutil
import subprocess
import sys
import winreg
from datetime import datetime, timedelta

ROOT = r"D:\DevOptimizer"


def run(cmd, timeout=30):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=timeout)
    except Exception:
        return None


def reg_value(hive, sub, name):
    try:
        with winreg.OpenKey(hive, sub) as k:
            return winreg.QueryValueEx(k, name)[0]
    except OSError:
        return None


def reg_exists(hive, sub):
    try:
        with winreg.OpenKey(hive, sub):
            return True
    except OSError:
        return False


def main():
    r = run(["powershell", "-NoProfile", "-Command",
             "(Get-CimInstance Win32_OperatingSystem)"
             ".LastBootUpTime.ToString('o')"])
    boot_s = (r.stdout if r else "").strip()
    try:
        boot = datetime.fromisoformat(boot_s)
        up = datetime.now() - boot.replace(tzinfo=None)
        print(f"LastBoot: {boot_s}  Uptime: "
              f"{up.total_seconds()/3600:.1f}h")
    except ValueError:
        print(f"LastBoot: {boot_s}")

    cv = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion"
    print(f"Build: "
          f"{reg_value(winreg.HKEY_LOCAL_MACHINE, cv, 'CurrentBuildNumber')}"
          f".{reg_value(winreg.HKEY_LOCAL_MACHINE, cv, 'UBR')}"
          f" ({reg_value(winreg.HKEY_LOCAL_MACHINE, cv, 'DisplayVersion')})")

    pfr = reg_value(
        winreg.HKEY_LOCAL_MACHINE,
        r"SYSTEM\CurrentControlSet\Control\Session Manager",
        "PendingFileRenameOperations")
    if pfr:
        n = len([x for x in pfr if x])
        print(f"PENDING REBOOT: "
              f"PendingFileRenameOperations present "
              f"({n} entries)")
    else:
        print("PENDING REBOOT: none "
              "(PendingFileRenameOperations "
              "absent/empty)")
    wu = reg_exists(
        winreg.HKEY_LOCAL_MACHINE,
        r"SOFTWARE\Microsoft\Windows\CurrentVersion"
        r"\WindowsUpdate\Auto Update\RebootRequired")
    cbs = reg_exists(
        winreg.HKEY_LOCAL_MACHINE,
        r"SOFTWARE\Microsoft\Windows\CurrentVersion"
        r"\Component Based Servicing\RebootPending")
    print(f"WU RebootRequired key: {wu}  "
          f"CBS RebootPending key: {cbs}")

    bitmask = ctypes.windll.kernel32.GetLogicalDrives()
    letters = [chr(65 + i) for i in range(26)
               if bitmask & (1 << i)]
    for letter in letters:
        try:
            u = shutil.disk_usage(f"{letter}:\\")
            print(f"Drive {letter}: "
                  f"{u.free/2**30:.1f} GB free of "
                  f"{u.total/2**30:.1f} GB "
                  f"({100*u.free/u.total:.0f}% free)")
        except OSError:
            pass

    for svc in ("wuauserv", "BITS",
                "Docker Desktop Service",
                "com.docker.service"):
        r = run(["sc.exe", "query", svc])
        if r and r.returncode == 0:
            m = re.search(r"STATE\s+:\s+\d+\s+(\w+)",
                          r.stdout)
            if m:
                print(f"Service {svc}: {m[1]}")
    r = run(["tasklist", "/FI",
             "IMAGENAME eq vmmemWSL", "/FO", "CSV",
             "/NH"])
    if r and "vmmemWSL" in r.stdout:
        m = re.search(r'"vmmemWSL[^"]*".*?"([\d,\.]+)\s*K"',
                      r.stdout)
        if m:
            kb = float(m[1].replace(",", ""))
            print(f"vmmemWSL working set: "
                  f"{kb/2**20:.2f} GB")
    else:
        print("vmmemWSL: not running")
    r = run(["sc.exe", "qc", "PRI-Driver"])
    m = (re.search(r"START_TYPE\s+:.*",
                   r.stdout) if r else None)
    print("PRI-Driver: "
          + (m[0].strip() if m else "not found"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
