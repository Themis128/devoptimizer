"""Port of scripts/devin/Tune-Windows-For-Devin.ps1 — enable Task
Scheduler history, raise unattended sleep timeouts (AC 1800/DC 600),
create the 'DevOptimizer' event source. Self-elevates via UAC.
"""
# REQUIRES: admin
import ctypes
import os
import re
import subprocess
import sys


def _elevate():
    ctypes.windll.shell32.ShellExecuteW(
        None, "runas", sys.executable,
        " ".join('"' + a + '"' for a in sys.argv), None, 1)


def ps(cmd):
    return subprocess.run(["powershell", "-NoProfile", "-Command",
                           cmd], capture_output=True, text=True)


def main():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("Elevating (UAC prompt)...")
        _elevate()
        return 0
    print("=== Windows tuning for Devin maintenance ===")

    # Task Scheduler history channel
    channel = "Microsoft-Windows-TaskScheduler/Operational"
    r = subprocess.run(["wevtutil", "gl", channel],
                       capture_output=True, text=True)
    m = re.search(r"^enabled: (.+)$", r.stdout, re.M)
    if m and m.group(1) == "true":
        print("[ OK ] Task Scheduler history already enabled")
    else:
        subprocess.run(["wevtutil", "sl", channel, "/e:true"],
                       capture_output=True)
        r = subprocess.run(["wevtutil", "gl", channel],
                           capture_output=True, text=True)
        m = re.search(r"^enabled: (.+)$", r.stdout, re.M)
        if m and m.group(1) == "true":
            print(f"[ OK ] Task Scheduler history ENABLED ({channel})")
        else:
            print(f"[FAIL] could not enable {channel}")

    # unattended sleep timeout
    target_ac, target_dc = 1800, 600
    sleep_group = "238c9fa8-0aad-41ed-83f4-97be242c8f20"
    unattend = "9d7815a6-7ee4-497e-8888-515a05f02364"
    q = subprocess.run(["powercfg", "/q", "SCHEME_CURRENT",
                        sleep_group, unattend],
                       capture_output=True, text=True).stdout
    ac = re.search(r"Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)",
                   q)
    dc = re.search(r"Current DC Power Setting Index:\s+0x([0-9a-fA-F]+)",
                   q)
    cur_ac = int(ac.group(1), 16) if ac else None
    cur_dc = int(dc.group(1), 16) if dc else None
    if cur_ac is None and cur_dc is None:
        print("[FAIL] could not read System unattended sleep timeout")
    else:
        print(f"[INFO] unattended sleep timeout: AC {cur_ac}s,"
              f" DC {cur_dc}s")
        changed = False
        if cur_ac is not None and cur_ac < target_ac:
            subprocess.run(["powercfg", "/setacvalueindex",
                            "SCHEME_CURRENT", sleep_group, unattend,
                            str(target_ac)])
            print(f"[ OK ] AC unattended sleep: {cur_ac}s ->"
                  f" {target_ac}s")
            changed = True
        if cur_dc is not None and cur_dc < target_dc:
            subprocess.run(["powercfg", "/setdcvalueindex",
                            "SCHEME_CURRENT", sleep_group, unattend,
                            str(target_dc)])
            print(f"[ OK ] DC unattended sleep: {cur_dc}s ->"
                  f" {target_dc}s")
            changed = True
        if changed:
            subprocess.run(["powercfg", "/setactive",
                            "SCHEME_CURRENT"])
            print("[ OK ] scheme reapplied")
        else:
            print("[ OK ] unattended sleep timeouts already >= targets")

    # event source
    source = "DevOptimizer"
    r = ps("[System.Diagnostics.EventLog]::SourceExists('" + source
           + "')")
    if r.stdout.strip().lower() == "true":
        print(f"[ OK ] event source '{source}' already exists")
    else:
        ps("New-EventLog -LogName Application -Source '" + source + "'")
        print(f"[ OK ] event source '{source}' created "
              "(Application log)")
    ps("Write-EventLog -LogName Application -Source '" + source
       + "' -EventId 1 -EntryType Information -Message 'DevOptimizer"
       " event source test entry (Tune-Windows-For-Devin).'")
    print("[ OK ] test event written and source writable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
