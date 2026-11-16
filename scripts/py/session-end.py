"""Port of scripts/devin/hooks/session-end.ps1.

Devin SessionEnd hook: reads the JSON event on stdin,
logs the session end to devin-queue sessions.log,
fires an optional DEVIN_WEBHOOK_URL POST + msg.exe
toast, and verifies queue-state.json stays valid JSON.
"""

import json
import os
import subprocess
import sys
import urllib.request
from datetime import datetime
from pathlib import Path

Q = Path("C:/Users/tbaltzakis/devin-queue")


def main():
    raw = sys.stdin.read()
    try:
        e = json.loads(raw)
    except Exception:
        e = None
    msg = (f"Devin session "
           f"{(e or {}).get('session_id')} ended at "
           f"{datetime.now():%Y-%m-%d %H:%M}")
    try:
        Q.mkdir(exist_ok=True)
        with open(Q / "sessions.log", "a",
                  encoding="utf-8") as f:
            f.write(msg + "\n")
    except OSError:
        pass
    url = os.environ.get("DEVIN_WEBHOOK_URL")
    if url:
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps({"text": msg}).encode(),
                headers={"Content-Type":
                         "application/json"},
                method="POST")
            urllib.request.urlopen(req, timeout=10)
        except Exception:
            pass
    try:
        subprocess.run(["msg.exe", "*", "/TIME:30",
                        msg], capture_output=True,
                       timeout=10)
    except Exception:
        pass
    state = Q / "queue-state.json"
    if state.exists():
        try:
            json.loads(state.read_text(
                encoding="utf-8", errors="replace"))
            note = ("[Queue] Queue state verified and "
                    "persisted at session end")
        except Exception:
            note = ("[Queue] WARNING: Queue state file "
                    "exists but is invalid JSON at "
                    "session end")
    else:
        note = ("[Queue] No queue state file at "
                "session end")
    try:
        with open(Q / "sessions.log", "a",
                  encoding="utf-8") as f:
            f.write(note + "\n")
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
