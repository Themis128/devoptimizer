#!/usr/bin/env python3
"""check-drive-space.py — disk usage guard for fixed drives.

Runs hourly via the DevOptimizer-DiskSpaceGuard scheduled task.

- >=90% used: Telegram warning (once per crossing, re-arms below 88%)
- >=95% used: Telegram critical + automatic safe cleanup
  (Temp files older than 24h, npm/pip caches) and reports freed space

State persists in logs/diskguard-state.json so alerts don't spam.
Telegram creds: %APPDATA%/devin/secrets/tg-bot-token, chat_id below.
"""

import json
import os
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
LOG_DIR = REPO / "logs"
STATE_FILE = LOG_DIR / "diskguard-state.json"

WARN_PCT = 90.0
CRIT_PCT = 95.0
REARM_PCT = 88.0
TG_CHAT_ID = "7017840434"


def log(msg):
    LOG_DIR.mkdir(exist_ok=True)
    line = f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}"
    print(line)
    with open(LOG_DIR / "diskguard.log", "a", encoding="utf-8") as f:
        f.write(line + "\n")


def _env_val(name):
    v = os.environ.get(name)
    if v:
        return v
    env_file = Path(r"C:\Users\tbaltzakis\cu130-slim\.env")
    try:
        for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    except OSError:
        pass
    return ""


def ntfy(text):
    """Best-effort ntfy fan-out — mirrors ops alerts to the phone lane."""
    try:
        base = _env_val("NTFY_ALERT_BASE_URL").rstrip("/")
        tok = _env_val("NTFY_ALERT_TOKEN")
        topic = _env_val("NTFY_ALERT_TOPIC") or "cloudless-alerts"
        if not (base and tok):
            return
        req = urllib.request.Request(
            f"{base}/{topic}", data=text[:3900].encode(), method="POST",
            headers={
                "Authorization": f"Bearer {tok}",
                "Title": "[ops] diskguard",
                "Priority": "4",
                "Tags": "ops",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) ntfy-alert/1.0",
            })
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        log(f"ntfy send failed: {e}")


def telegram(text):
    ntfy(text)
    token_file = Path(os.environ["APPDATA"]) / "devin" / "secrets" / "tg-bot-token"
    if not token_file.exists():
        log("telegram skipped: no tg-bot-token")
        return
    bot = token_file.read_text(encoding="utf-8").strip()
    data = urllib.parse.urlencode({"chat_id": TG_CHAT_ID, "text": text}).encode()
    try:
        urllib.request.urlopen(
            f"https://api.telegram.org/bot{bot}/sendMessage", data=data, timeout=15
        )
    except Exception as e:
        log(f"telegram send failed: {e}")


def dir_size(path):
    total = 0
    try:
        for p in Path(path).rglob("*"):
            try:
                if p.is_file():
                    total += p.stat().st_size
            except OSError:
                pass
    except OSError:
        pass
    return total


def safe_cleanup():
    """Return (bytes_freed, notes). Conservative: temp>24h + package caches."""
    freed = 0
    notes = []
    cutoff = time.time() - 24 * 3600
    targets = [
        Path(os.environ.get("TEMP", "")),
        Path(os.environ.get("LOCALAPPDATA", "")) / "npm-cache" / "_cacache",
        Path(os.environ.get("LOCALAPPDATA", "")) / "pip" / "cache",
    ]
    for t in targets:
        if not t or not t.exists():
            continue
        name = t.name or str(t)
        before = dir_size(t) if t.is_dir() else 0
        try:
            if t == Path(os.environ.get("TEMP", "")) and t.is_dir():
                for child in t.iterdir():
                    try:
                        if child.stat().st_mtime < cutoff:
                            if child.is_dir():
                                shutil.rmtree(child, ignore_errors=True)
                            else:
                                child.unlink(missing_ok=True)
                    except OSError:
                        pass
            else:
                shutil.rmtree(t, ignore_errors=True)
        except OSError as e:
            notes.append(f"{name}: {e}")
            continue
        after = dir_size(t) if t.exists() else 0
        gained = max(0, before - after)
        freed += gained
        notes.append(f"{name}: -{gained / 1048576:.0f} MB")
    return freed, notes


def top_consumers():
    users = Path.home()
    candidates = {
        "Temp": users / "AppData/Local/Temp",
        "Docker(VHDX)": users / "AppData/Local/Docker",
        "Packages": users / "AppData/Local/Packages",
        "Downloads": users / "Downloads",
        "devin": users / "AppData/Roaming/devin",
        "npm-cache": users / "AppData/Local/npm-cache",
    }
    rows = []
    for name, p in candidates.items():
        if p.exists():
            rows.append((dir_size(p) / 1073741824, name))
    rows.sort(reverse=True)
    return ", ".join(f"{n} {g:.0f}GB" for g, n in rows[:4])


def main():
    LOG_DIR.mkdir(exist_ok=True)
    state = {}
    if STATE_FILE.exists():
        try:
            state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        except Exception:
            state = {}

    worst = 0.0
    report = []
    for letter in "CDE":
        path = f"{letter}:\\"
        if not Path(path).exists():
            continue
        u = shutil.disk_usage(path)
        pct = 100.0 * u.used / u.total
        worst = max(worst, pct)
        report.append(f"{letter}: {pct:.1f}% used, {u.free / 1073741824:.1f}GB free")
        key = letter
        prev = state.get(key, "ok")

        if pct >= CRIT_PCT:
            if prev != "crit":
                telegram(
                    f"🚨 DISK CRITICAL {letter}: {pct:.1f}% used "
                    f"({u.free / 1073741824:.1f}GB free)\n"
                    f"Top: {top_consumers()}\nAuto-cleanup running..."
                )
                freed, notes = safe_cleanup()
                u2 = shutil.disk_usage(path)
                telegram(
                    f"🧹 cleanup freed {freed / 1073741824:.1f}GB on {letter} "
                    f"({'; '.join(notes)})\nnow {u2.free / 1073741824:.1f}GB free"
                )
                # Escalate: fire the elevated AdminCleanupTask (DISM, WU cache,
                # shadow copy, VHDX compaction). Runs as the stored admin
                # principal; failure is non-fatal - the warning already went out.
                try:
                    # CREATE_NO_WINDOW: with pythonw as the task host (no
                    # console), a bare console child (schtasks) would allocate
                    # a VISIBLE window on the crit path. 2026-11-14.
                    subprocess.run(
                        ["schtasks", "/run", "/tn", "AdminCleanupTask"],
                        capture_output=True,
                        timeout=30,
                        creationflags=subprocess.CREATE_NO_WINDOW,
                    )
                    log("AdminCleanupTask triggered (crit disk)")
                except Exception as e:
                    log(f"AdminCleanupTask trigger failed: {e}")
                state[key] = "crit"
        elif pct >= WARN_PCT:
            if prev == "ok":
                telegram(
                    f"⚠️ DISK WARNING {letter}: {pct:.1f}% used "
                    f"({u.free / 1073741824:.1f}GB free)\nTop: {top_consumers()}"
                )
                state[key] = "warn"
        elif pct < REARM_PCT and prev != "ok":
            state[key] = "ok"

    STATE_FILE.write_text(json.dumps(state), encoding="utf-8")
    log(" | ".join(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
