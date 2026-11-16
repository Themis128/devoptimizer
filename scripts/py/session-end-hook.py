"""SessionEnd hook (Python port of devin/hooks/session-end.ps1).

Reads the session event JSON on stdin, logs the end to sessions.log,
posts to DEVIN_WEBHOOK_URL when set, raises a msg.exe toast, and verifies
the devin-queue state file persisted.
"""

import json
import os
import subprocess
import sys
import urllib.request
from datetime import datetime
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, hook, session, queue

QUEUE_DIR = Path(r"C:\Users\tbaltzakis\devin-queue")
QUEUE_MANAGER = QUEUE_DIR / "hooks" / "queue-manager.ps1"


def append_log(name: str, line: str) -> None:
    try:
        with (QUEUE_DIR / name).open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def main() -> None:
    raw = sys.stdin.read()
    try:
        event = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        event = {}

    msg = (f"Devin session {event.get('session_id')} ended at "
           f"{datetime.now():%Y-%m-%d %H:%M}")
    append_log("sessions.log", msg)

    webhook = os.environ.get("DEVIN_WEBHOOK_URL")
    if webhook:
        try:
            req = urllib.request.Request(
                webhook, data=json.dumps({"text": msg}).encode(),
                headers={"Content-Type": "application/json"}, method="POST")
            urllib.request.urlopen(req, timeout=10)
        except Exception:
            pass

    try:
        subprocess.run(["msg.exe", "*", "/TIME:30", msg],
                       capture_output=True, timeout=15)
    except Exception:
        pass

    if QUEUE_MANAGER.exists():
        state = QUEUE_DIR / "queue-state.json"
        if state.exists():
            try:
                json.loads(state.read_text(encoding="utf-8"))
                append_log("sessions.log",
                           "[Queue] Queue state verified and persisted at session end")
            except (json.JSONDecodeError, OSError):
                append_log("sessions.log",
                           "[Queue] WARNING: Queue state file exists but is "
                           "invalid JSON at session end")
        else:
            append_log("sessions.log", "[Queue] No queue state file at session end")

    sys.exit(0)


if __name__ == "__main__":
    main()
