"""Port of scripts/popup-flash-watch.ps1.

Console-flash catcher: samples for visible console-class
processes in the interactive session and logs each once
(ts/pid/name/title/parent/cmdline) as JSON lines to
logs\\popup-flashes.log.
"""

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

LOG = Path("D:/DevOptimizer/logs/popup-flashes.log")
NAMES = {"cmd", "powershell", "pwsh", "conhost", "wsl",
         "wscript", "cscript", "bash", "schtasks", "netsh",
         "ipconfig", "tasklist", "wslhost", "vmmem"}


def ps_procs():
    """Processes with a main window + parent + cmdline, via CIM."""
    cmd = (
        "Get-CimInstance Win32_Process | Where-Object { "
        "$_.ExecutablePath } | ForEach-Object { $mw = "
        "(Get-Process -Id $_.ProcessId -ErrorAction "
        "SilentlyContinue).MainWindowHandle; if ($mw -and $mw"
        " -ne 0) { [pscustomobject]@{ Pid=$_.ProcessId; Name="
        "([IO.Path]::GetFileNameWithoutExtension("
        "$_.ExecutablePath)); Title=(Get-Process -Id "
        "$_.ProcessId).MainWindowTitle; Ppid="
        "$_.ParentProcessId; Cmd=$_.CommandLine } } } | "
        "ConvertTo-Json -Compress")
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", cmd],
        capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        return []
    return data if isinstance(data, list) else [data]


def parent_name(ppid, procs):
    for p in procs:
        if p.get("Pid") == ppid:
            return p.get("Name")
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         f"(Get-Process -Id {ppid} -ErrorAction "
         f"SilentlyContinue).ProcessName"],
        capture_output=True, text=True)
    n = r.stdout.strip()
    return n or None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-DurationMin", type=int, default=60)
    ap.add_argument("-IntervalSec", type=int, default=2)
    a = ap.parse_args()

    deadline = datetime.now() + timedelta(
        minutes=a.DurationMin)
    seen = {}
    while datetime.now() < deadline:
        procs = ps_procs()
        for p in procs:
            name = (p.get("Name") or "").lower()
            if name not in NAMES or p.get("Pid") in seen:
                continue
            seen[p["Pid"]] = datetime.now()
            ppid = p.get("Ppid")
            pn = parent_name(ppid, procs)
            rec = {
                "ts": f"{datetime.now():%Y-%m-%d %H:%M:%S}",
                "pid": p["Pid"], "name": name,
                "title": p.get("Title") or "",
                "parent": (f"{pn}({ppid})" if pn
                           else "unknown"),
                "cmdline": p.get("Cmd") or "",
            }
            LOG.parent.mkdir(exist_ok=True)
            with open(LOG, "a", encoding="utf-8") as f:
                f.write(json.dumps(rec) + "\n")
        time.sleep(a.IntervalSec)
    print(f"popup-flash-watch done: {len(seen)} "
          f"visible-console process(es) logged to {LOG}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
