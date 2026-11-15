#!/usr/bin/env python3
"""ntfy-windows-bridge.py — stream self-hosted ntfy topics -> native Windows toasts.

Subscribes (read-only) to the cloudless ntfy topics on ntfy.cloudless.gr and
raises a Windows toast per message. Runs under pythonw.exe (no console) via the
Startup-folder vbs launcher installed by install-startup-launchers.ps1.

Auth: %APPDATA%/devin/secrets/ntfy-phone-token (phone user: rw cloudless-*,
ro devoptimizer-alerts). Reconnects forever with backoff; logs to
logs/ntfy-bridge.log next to this script's repo root.
"""

import json
import os
import sys
import time
import urllib.request

from windows_toasts import Toast, WindowsToaster, ToastScenario, ToastDuration

BASE = "https://ntfy.cloudless.gr"
TOPICS = [
    "cloudless-alerts",
    "cloudless-ops",
    "nextcloud-ops",
    "devoptimizer-alerts",
]
TOKEN_FILE = os.path.expandvars(r"%APPDATA%\devin\secrets\ntfy-phone-token")
LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "logs", "ntfy-bridge.log")
SEEN_MAX = 500


def log(msg: str) -> None:
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}\n")
    except OSError:
        pass


def load_token() -> str:
    with open(TOKEN_FILE, "r", encoding="utf-8") as f:
        return f.read().strip()


def toast_for(topic: str, msg: dict) -> None:
    title = (msg.get("title") or "").strip() or topic
    body = (msg.get("message") or "").strip()
    if not body:
        return
    try:
        pri = int(msg.get("priority") or 3)
    except (TypeError, ValueError):
        pri = 3
    scenario = ToastScenario.Alarm if pri >= 4 else ToastScenario.Default
    duration = ToastDuration.Long if pri >= 4 else ToastDuration.Default
    t = Toast()
    t.text_fields = [title[:64], body[:250]]
    t.scenario = scenario
    t.duration = duration
    t.tag = str(msg.get("id") or "")[:64] or None
    try:
        WindowsToaster("ntfy-bridge").show_toast(t)
    except Exception as e:  # notifier hiccup must not kill the stream
        log(f"toast error: {e}")


def stream_topic(toaster: WindowsToaster, topic: str, token: str, seen: set) -> None:
    since = str(int(time.time()) - 120)  # catch the last 2 min on (re)connect
    url = f"{BASE}/{topic}/json?since={since}"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ntfy-windows-bridge/1.0",
    })
    while True:
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                log(f"stream open: {topic}")
                for raw in r:
                    line = raw.decode("utf-8", "replace").strip()
                    if not line:
                        continue
                    try:
                        ev = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if ev.get("event") != "message":
                        continue
                    mid = ev.get("id")
                    if mid and mid in seen:
                        continue
                    if mid:
                        seen.add(mid)
                        if len(seen) > SEEN_MAX:
                            seen.clear()
                            seen.add(mid)
                    toast_for(topic, ev)
        except Exception as e:
            log(f"stream error {topic}: {e}")
            time.sleep(15)


def main() -> int:
    try:
        token = load_token()
    except OSError as e:
        log(f"token load failed: {e}")
        return 2
    import threading

    toaster = WindowsToaster("ntfy-bridge")
    seen: set = set()
    threads = [
        threading.Thread(target=stream_topic, args=(toaster, t, token, seen), daemon=True)
        for t in TOPICS
    ]
    for th in threads:
        th.start()
    log(f"bridge started topics={TOPICS}")
    while True:
        time.sleep(3600)


if __name__ == "__main__":
    sys.exit(main())
