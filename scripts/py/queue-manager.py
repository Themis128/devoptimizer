"""Devin FCFS queue persistence manager (port of devin/queue/queue-manager.ps1).

File-backed queue at C:\\Users\\tbaltzakis\\devin-queue\\queue-state.json with
atomic lock file. Actions: enqueue, dequeue, peek, list, clear, send-next
(runs dequeued command via the Devin CLI).
"""

import argparse
import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, queue, fcfs

QUEUE_FILE = Path(r"C:\Users\tbaltzakis\devin-queue\queue-state.json")
LOCK_FILE = QUEUE_FILE.with_suffix(".json.lock")
DEVIN_CLI = Path(r"C:\Users\tbaltzakis\AppData\Local\Programs\Devin\resources"
                 r"\app\extensions\windsurf\devin\bin\devin.exe")


def _lock(timeout_ms: int = 5000) -> bool:
    deadline = time.time() + timeout_ms / 1000
    while time.time() < deadline:
        try:
            fd = os.open(LOCK_FILE, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.close(fd)
            return True
        except FileExistsError:
            time.sleep(0.05)
    return False


def _unlock() -> None:
    try:
        LOCK_FILE.unlink()
    except OSError:
        pass


def _read() -> dict:
    if not QUEUE_FILE.exists():
        return {"queue": [], "version": 1,
                "updated": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
    try:
        return json.loads(QUEUE_FILE.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {"queue": [], "version": 1}


def _write(q: dict) -> None:
    QUEUE_FILE.parent.mkdir(parents=True, exist_ok=True)
    q["updated"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    tmp = QUEUE_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(q, indent=2), encoding="utf-8")
    os.replace(tmp, QUEUE_FILE)


def enqueue(command: str, working_dir: str, description: str) -> dict:
    if not _lock():
        print("could not acquire queue lock", file=sys.stderr)
        sys.exit(1)
    try:
        q = _read()
        entry = {"id": str(uuid.uuid4()), "command": command,
                 "workingDir": working_dir, "description": description,
                 "enqueuedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                 "attempts": 0, "status": "pending"}
        q["queue"].append(entry)
        _write(q)
        return entry
    finally:
        _unlock()


def dequeue() -> dict | None:
    if not _lock():
        return None
    try:
        q = _read()
        for i, e in enumerate(q["queue"]):
            if e.get("status") == "pending":
                e["status"] = "running"
                e["dequeuedAt"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
                _write(q)
                return e
        return None
    finally:
        _unlock()


def _mark(entry_id: str, status: str, **extra) -> None:
    if not _lock():
        return
    try:
        q = _read()
        for e in q["queue"]:
            if e["id"] == entry_id:
                e["status"] = status
                e.update(extra)
        _write(q)
    finally:
        _unlock()


def send_next(max_retries: int) -> int:
    entry = dequeue()
    if not entry:
        print("No pending commands in queue")
        return 0
    print(f"=== Executing queued command [{entry['id'][:8]}] ===")
    print(f"Command: {entry['command']}  Dir: {entry.get('workingDir')}")
    cli = str(DEVIN_CLI) if DEVIN_CLI.exists() else "devin"
    cwd = entry.get("workingDir") or None
    cmd = f'"{cli}" -p --permission-mode=dangerous ' \
          f'--respect-workspace-trust=false -- "{entry["command"]}"'
    last = ""
    for attempt in range(1, max_retries + 1):
        print(f"Attempt {attempt}/{max_retries}...")
        r = subprocess.run(f"cmd.exe /c {cmd}", capture_output=True, text=True,
                           cwd=cwd)
        last = r.stdout + r.stderr
        if r.returncode == 0:
            _mark(entry["id"], "completed",
                  completedAt=time.strftime("%Y-%m-%dT%H:%M:%S%z"))
            print("Command completed successfully")
            return 0
        if attempt < max_retries:
            time.sleep(5)
    _mark(entry["id"], "failed",
          failedAt=time.strftime("%Y-%m-%dT%H:%M:%S%z"),
          error=f"Failed after {max_retries} attempts. Last error: {last}")
    print(f"Command failed after {max_retries} attempts")
    return 1


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("action", choices=["enqueue", "dequeue", "peek",
                                           "list", "clear", "send-next"])
    parser.add_argument("--command")
    parser.add_argument("--working-directory", default=os.getcwd())
    parser.add_argument("--description", default="")
    parser.add_argument("--max-retries", type=int, default=3)
    args = parser.parse_args()

    if args.action == "enqueue":
        if not args.command:
            print("Command required for enqueue", file=sys.stderr)
            sys.exit(1)
        e = enqueue(args.command, args.working_directory, args.description)
        print(f"enqueued [{e['id'][:8]}] {e['command']}")
    elif args.action == "dequeue":
        e = dequeue()
        print(json.dumps(e, indent=2) if e else "Queue empty")
    elif args.action == "peek":
        q = _read()
        e = next((x for x in q["queue"] if x.get("status") == "pending"), None)
        print(json.dumps(e, indent=2) if e else "Queue empty")
    elif args.action == "list":
        q = _read()
        for e in q["queue"]:
            print(f"[{e['id'][:8]}] {e.get('status','?'):10} {e['command']}  "
                  f"(enqueued {e.get('enqueuedAt','')})")
        print(f"{len(q['queue'])} entries")
    elif args.action == "clear":
        if _lock():
            try:
                _write({"queue": [], "version": 1})
            finally:
                _unlock()
        print("queue cleared")
    elif args.action == "send-next":
        sys.exit(send_next(args.max_retries))


if __name__ == "__main__":
    main()
