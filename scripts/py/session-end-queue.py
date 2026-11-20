"""SessionEnd queue hook (Python port of devin/queue/session-end.ps1).

Identical behavior to the hooks copy: logs session end, optional
DEVIN_WEBHOOK_URL post, msg.exe toast, and queue-state verification.
"""

import ipaddress
import json
import os
import socket
import subprocess
import sys
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, queue, session

QUEUE_DIR = Path(r"C:\Users\tbaltzakis\devin-queue")
QUEUE_MANAGER = QUEUE_DIR / "hooks" / "queue-manager.ps1"


def append_log(name: str, line: str) -> None:
    try:
        with (QUEUE_DIR / name).open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def _webhook_url_ok(url: str) -> bool:
    """HTTPS + public host only; rejects loopback/private targets."""
    p = urllib.parse.urlparse(url)
    if p.scheme != "https" or not p.hostname:
        return False
    try:
        infos = socket.getaddrinfo(p.hostname, None)
    except OSError:
        return False
    for info in infos:
        try:
            ip = ipaddress.ip_address(info[4][0])
        except ValueError:
            return False
        if (ip.is_private or ip.is_loopback or ip.is_link_local
                or ip.is_reserved or ip.is_multicast):
            return False
    return True


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
    if webhook and _webhook_url_ok(webhook):
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
