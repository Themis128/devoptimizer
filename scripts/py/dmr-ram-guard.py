"""DMR RAM guard (Python port of dmr-ram-guard.ps1).

Evicts Docker Model Runner residents under host RAM pressure:
  free < warn (1800MB): evict non-pinned residents
  free < crit (1000MB): also evict the pinned set
Runs every 5 min via conhost --headless scheduled task. Pure stdlib.
"""

import argparse
import ctypes
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

# CATEGORY: utilities
# TAGS: docker, dmr, memory, watchdog, ntfy

LOG_FILE = Path(r"D:\DevOptimizer\logs\dmr-ram-guard.log")
NTFY_URL = "https://ntfy.cloudless.gr/devoptimizer-alerts"
PINNED = ("qwen3-4b-instruct", "embedding-0.6b")


def log(msg: str, level: str = "INFO") -> None:
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    # trim log over 1MB
    try:
        if LOG_FILE.exists() and LOG_FILE.stat().st_size > 1_000_000:
            lines = LOG_FILE.read_text(errors="replace").splitlines()
            LOG_FILE.write_text("\n".join(lines[-500:]) + "\n")
    except OSError:
        pass
    line = f"{time.strftime('%Y-%m-%d %H:%M:%S')} [{level}] {msg}"
    with LOG_FILE.open("a", encoding="ascii", errors="replace") as f:
        f.write(line + "\n")
    if level != "INFO":
        print(line, file=sys.stderr)


def notify(title: str, body: str) -> None:
    log(f"ALERT: {title} -- {body}", "WARN")
    try:
        headers = {"Title": title, "Priority": "default"}
        token_file = Path(os.environ.get("APPDATA", "")) / \
            r"devin\secrets\ntfy-devoptimizer-token"
        if token_file.exists():
            headers["Authorization"] = f"Bearer {token_file.read_text().strip()}"
        req = urllib.request.Request(NTFY_URL, data=body.encode(),
                                     headers=headers)
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:  # noqa: BLE001 - alerting must never crash the guard
        log(f"ntfy fail: {e}", "WARN")


def free_mb() -> int:
    class MEMORYSTATUSEX(ctypes.Structure):
        _fields_ = [
            ("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
            ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
            ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
            ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
            ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
        ]
    stat = MEMORYSTATUSEX()
    stat.dwLength = ctypes.sizeof(stat)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat))
    return int(stat.ullAvailPhys / 1_048_576)


def resident_models() -> list[str]:
    out = subprocess.run(["docker", "model", "ps"], capture_output=True,
                         text=True, timeout=60)
    if out.returncode != 0 or not out.stdout.strip():
        return []
    models = []
    for line in out.stdout.splitlines()[1:]:
        name = line.split()[0].strip() if line.split() else ""
        if name:
            models.append(name)
    return models


def kill_stray_llama_servers() -> int:
    out = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq com.docker.llama-server.exe",
         "/FO", "CSV", "/NH"], capture_output=True, text=True, timeout=30).stdout
    count = 0
    for line in out.splitlines():
        if "llama-server" in line.lower():
            pid = line.split('","')[1].rstrip('"')
            subprocess.run(["taskkill", "/F", "/PID", pid],
                           capture_output=True, timeout=15)
            count += 1
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--warn-mb", type=int, default=1800)
    parser.add_argument("--crit-mb", type=int, default=1000)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    free = free_mb()
    if args.json:
        state = {"freeMB": free, "crit": free < args.crit_mb}
        if free < args.warn_mb:
            state["models"] = resident_models()
        print(json.dumps(state))
        if free >= args.warn_mb:
            return

    if free >= args.warn_mb:
        sys.exit(0)  # headroom ok

    models = resident_models()
    if not models:
        log(f"free={free}MB but 'docker model ps' empty/failed - engine flap?",
            "WARN")
        sys.exit(1)

    crit = free < args.crit_mb
    evict = [m for m in models
             if crit or not any(p in m for p in PINNED)]
    if not evict:
        log(f"free={free}MB - only pinned residents left ({', '.join(models)})")
        sys.exit(0)

    log(f"free={free}MB crit={crit} - evicting {len(evict)}/{len(models)}: "
        f"{', '.join(evict)}", "WARN")
    if args.dry_run:
        sys.exit(0)
    for m in evict:
        r = subprocess.run(["docker", "model", "unload", m],
                           capture_output=True, text=True, timeout=60)
        log(f"unloaded {m} rc={r.returncode}")
    time.sleep(5)
    after = free_mb()
    log(f"free {free}MB -> {after}MB")

    if after < args.warn_mb:
        n = kill_stray_llama_servers()
        if n:
            log(f"still {after}MB - killed {n} stray llama-server proc(s)",
                "WARN")
            time.sleep(3)
            after = free_mb()
            log(f"post-kill free {after}MB")

    if crit:
        notify("dmr-ram-guard CRIT",
               f"host RAM {free}MB -> evicted {len(evict)} model(s) incl. "
               f"pinned set; now {after}MB free")


if __name__ == "__main__":
    main()
