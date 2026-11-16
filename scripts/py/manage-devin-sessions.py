"""Manage Devin sessions (Python port of manage-devin-sessions.ps1).

Reads the Devin CLI sessions SQLite DB plus Devin Desktop main-window
processes: closes CLI sessions and Desktop windows idle >4h, then enforces
the max-concurrent limit against whatever idle entries remain (active work
is never killed). Mutating; --dry-run reports only.
"""

import argparse
import datetime
import json
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


def close_cli_session(session_id: str) -> bool:
    r = subprocess.run([str(CLI_PATH), "rm", "--force", session_id],
                       capture_output=True, text=True, timeout=60)
    if r.returncode == 0:
        log(f"Closed CLI session: {session_id}")
        return True
    log(f"Failed to close CLI session {session_id}: "
        f"{r.stdout}{r.stderr}", "ERROR")
    return False


def close_desktop_proc(pid: int) -> bool:
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        f"Stop-Process -Id {pid} -Force"],
                       capture_output=True, text=True, timeout=30)
    if r.returncode == 0:
        log(f"Closed Desktop process: {pid}")
        return True
    log(f"Failed to close Desktop process {pid}: {r.stderr}", "ERROR")
    return False


def last_ts(val) -> float:
    return val / 1000 if val and val > 1e12 else (val or 0)


def proc_start_s(p: dict, default: float) -> float:
    """Parse a Devin process StartTime (ISO or /Date(ms)/ wire format)."""
    raw = str(p.get("StartTime", "") or "")
    if raw.startswith("/Date("):
        try:
            return int(raw[6:].rstrip(")/")) / 1000
        except (ValueError, IndexError):
            return default
    try:
        return datetime.datetime.fromisoformat(
            raw.replace("Z", "+00:00")).timestamp()
    except (ValueError, TypeError):
        return default


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--max-concurrent", type=int, default=2)
    parser.add_argument("--idle-timeout-hours", type=int, default=4)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    log("=== Devin Session Manager Started ===")
    sessions = cli_sessions()
    procs = devin_procs()
    now = time.time()
    cutoff = now - args.idle_timeout_hours * 3600
    log(f"Found {len(sessions)} active CLI sessions, "
        f"{len(procs)} Desktop processes")

    closed_sessions: list[str] = []
    closed_procs: list[int] = []
    actions = []

    # close every idle CLI session
    for s in sessions:
        idle_h = (now - last_ts(s["last_activity_at"])) / 3600
        if last_ts(s["last_activity_at"]) < cutoff:
            actions.append({"kind": "close-cli", "id": s["id"],
                            "idleH": round(idle_h, 1)})
            log(f"CLI session {s['id']} idle {idle_h:.1f}h - closing")
            if not args.dry_run and close_cli_session(s["id"]):
                closed_sessions.append(s["id"])
        else:
            log(f"CLI session {s['id']} active (idle {idle_h:.1f}h)")

    # close every idle Desktop process (main windows only)
    for p in procs:
        start_s = proc_start_s(p, now)
        idle_h = (now - start_s) / 3600
        if start_s < cutoff:
            actions.append({"kind": "close-desktop", "pid": p["Id"],
                            "idleH": round(idle_h, 1)})
            log(f"Desktop process {p['Id']} idle {idle_h:.1f}h - closing")
            if not args.dry_run and close_desktop_proc(p["Id"]):
                closed_procs.append(p["Id"])
        else:
            log(f"Desktop process {p['Id']} active (running {idle_h:.1f}h)")

    # enforce max-concurrent on whatever remains, idle entries only
    remaining_cli = [s for s in cli_sessions()
                     if s["id"] not in closed_sessions]
    remaining_procs = [p for p in devin_procs()
                       if p["Id"] not in closed_procs]
    total = len(remaining_cli) + len(remaining_procs)
    if total > args.max_concurrent:
        excess = total - args.max_concurrent
        log(f"Exceeded max concurrent ({args.max_concurrent}), need to close "
            f"{excess} idle session(s)", "WARN")
        idle_cli = sorted(
            (s for s in remaining_cli
             if last_ts(s["last_activity_at"]) < cutoff),
            key=lambda s: last_ts(s["last_activity_at"]))
        for s in idle_cli:
            if excess <= 0:
                break
            log(f"Closing excess idle CLI session: {s['id']}")
            actions.append({"kind": "close-cli-excess", "id": s["id"]})
            if not args.dry_run and close_cli_session(s["id"]):
                excess -= 1
        idle_procs = sorted(
            (p for p in remaining_procs
             if proc_start_s(p, now) < cutoff),
            key=lambda p: proc_start_s(p, now))
        for p in idle_procs:
            if excess <= 0:
                break
            log(f"Closing excess idle Desktop process: {p['Id']}")
            actions.append({"kind": "close-desktop-excess", "pid": p["Id"]})
            if not args.dry_run and close_desktop_proc(p["Id"]):
                excess -= 1
        if excess > 0:
            log(f"Still {excess} over limit after closing idle - "
                "keeping active work", "WARN")
    else:
        log(f"Concurrent count ({total}) within limit "
            f"({args.max_concurrent})")

    if args.json:
        print(json.dumps({"cliSessions": len(sessions), "procs": procs,
                          "closedSessions": closed_sessions,
                          "closedProcs": closed_procs,
                          "actions": actions}, indent=2))


if __name__ == "__main__":
    main()
