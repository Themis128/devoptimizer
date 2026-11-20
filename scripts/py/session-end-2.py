"""Port of scripts/devin/hooks/session-end.ps1.

Devin SessionEnd hook: reads the JSON event on stdin,
logs the session end to devin-queue sessions.log,
fires an optional DEVIN_WEBHOOK_URL POST + msg.exe
toast, and verifies queue-state.json stays valid JSON.
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

Q = Path("C:/Users/tbaltzakis/devin-queue")


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
    if url and _webhook_url_ok(url):
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
