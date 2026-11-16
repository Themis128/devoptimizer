"""Manage Devin sessions (Python port of manage-devin-sessions.ps1).

Reads the Devin CLI sessions SQLite DB plus Devin Desktop processes:
max 2 concurrent, auto-close CLI sessions idle >4h, never touch recently
started Desktop processes (main-window processes only). Mutating;
--dry-run reports only.
"""

import argparse
import ctypes
import datetime
import json
import os
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, sessions, watchdog

DB_PATH = Path(r"C:\Users\tbaltzakis\AppData\Roaming\Devin\cli\sessions.db")
CLI_PATH = Path(r"C:\Users\tbaltzakis\AppData\Local\Programs\Devin\resources"
                r"\app\extensions\windsurf\devin\bin\devin.exe")
LOG_PATH = Path(r"D:\DevOptimizer\logs\devin-session-manager.log")


def log(msg: str, level: str = "INFO") -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    line = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] [{level}] {msg}"
    with LOG_PATH.open("a", encoding="utf-8") as f:
        f.write(line + "\n")
    print(line, file=sys.stderr)


def cli_sessions() -> list[dict]:
    if not DB_PATH.exists():
        log(f"CLI sessions db not found at {DB_PATH}", "WARN")
        return []
    try:
        conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
        rows = conn.execute(
            "SELECT id, created_at, last_activity_at, title, hidden,"
            " working_directory FROM sessions WHERE hidden=0"
            " ORDER BY last_activity_at DESC").fetchall()
        conn.close()
        return [{"id": r[0], "created_at": r[1], "last_activity_at": r[2],
                 "title": r[3], "working_directory": r[5]} for r in rows]
    except sqlite3.Error as e:
        log(f"error reading CLI sessions: {e}", "ERROR")
        return []


def devin_procs() -> list[dict]:
    out = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Get-Process Devin -ErrorAction SilentlyContinue | "
         "Where-Object { $_.MainWindowHandle -ne 0 } | "
         "Select-Object Id,StartTime,MainWindowTitle | "
         "ConvertTo-Json -Compress"],
        capture_output=True, text=True, timeout=30).stdout.strip()
    if not out:
        return []
    data = json.loads(out)
    return data if isinstance(data, list) else [data]


def last_input_age_min() -> float:
    class LASTINPUTINFO(ctypes.Structure):
        _fields_ = [("cbSize", ctypes.c_uint), ("dwTime", ctypes.c_ulong)]
    lii = LASTINPUTINFO()
    lii.cbSize = ctypes.sizeof(lii)
    if not ctypes.windll.user32.GetLastInputInfo(ctypes.byref(lii)):
        return 0.0
    tick = ctypes.windll.kernel32.GetTickCount()
    return (tick - lii.dwTime) / 60000.0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--max-concurrent", type=int, default=2)
    parser.add_argument("--idle-timeout-hours", type=int, default=4)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    log("=== session manager run ===")
    sessions = cli_sessions()
    procs = devin_procs()
    now = time.time()
    cutoff = now - args.idle_timeout_hours * 3600
    idle_age = last_input_age_min()

    actions = []

    # CLI sessions: close ones idle past the timeout (keep max-concurrent newest)
    for s in sessions[args.max_concurrent:]:
        last = s["last_activity_at"] or 0
        # timestamps are epoch seconds or ms
        last_s = last / 1000 if last > 1e12 else last
        if last_s < cutoff:
            actions.append({
                "kind": "close-cli-session", "id": s["id"],
                "title": s["title"],
                "reason": f"idle > {args.idle_timeout_hours}h"})

    # Desktop processes: report only (never kill active main windows)
    for p in procs:
        actions.append({"kind": "desktop-process", "id": p["Id"],
                        "title": p.get("MainWindowTitle", ""),
                        "reason": "observed (not managed)"})

    log(f"sessions={len(sessions)} procs={len(procs)} "
        f"user_idle={idle_age:.0f}min actions={sum(1 for a in actions if a['kind']=='close-cli-session')}")

    if args.json:
        print(json.dumps({"sessions": len(sessions), "procs": procs,
                          "actions": actions}, indent=2))
        return

    for a in actions:
        if a["kind"] == "close-cli-session":
            log(f"closing idle session {a['id']} ({a['title']}) — {a['reason']}")
            if not args.dry_run:
                r = subprocess.run([str(CLI_PATH), "session", "close", a["id"]],
                                   capture_output=True, text=True, timeout=30)
                log(f"  close rc={r.returncode}")
        else:
            log(f"  desktop pid {a['id']}: {a['title']} — left alone")


if __name__ == "__main__":
    main()
