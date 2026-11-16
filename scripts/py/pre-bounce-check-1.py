"""Port of scripts/pre-bounce-check.ps1.

Pre-bounce safety checklist - run before any WSL/Docker restart.
Checks active workloads, Devin sessions, running jobs and
estimates downtime. Exit: 0 safe, 1 forced/warnings, 2 blocked.
"""

import argparse
import ctypes
import json
import math
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

LOG_FILE = Path(os.environ.get("DEVOPT_HOME", "D:\\DevOptimizer")) \
    / "logs" / "pre-bounce-check.log"


def log(msg):
    try:
        LOG_FILE.parent.mkdir(exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}\n")
    except OSError:
        pass


def out(msg, quiet):
    if not quiet:
        print(msg)
    log(msg)


def run(cmd, timeout=15):
    try:
        return subprocess.run(cmd, capture_output=True, text=True,
                              timeout=timeout)
    except Exception:
        return None


def proc_running(name):
    r = run(["tasklist", "/FI", f"IMAGENAME eq {name}",
             "/FO", "CSV", "/NH"])
    return bool(r and name.lower() in r.stdout.lower())


def avail_mb():
    try:
        class MS(ctypes.Structure):
            _fields_ = [("dwLength", ctypes.c_ulong),
                        ("dwMemoryLoad", ctypes.c_ulong),
                        ("ullTotalPhys", ctypes.c_ulonglong),
                        ("ullAvailPhys", ctypes.c_ulonglong),
                        ("ullTotalPage", ctypes.c_ulonglong),
                        ("ullAvailPage", ctypes.c_ulonglong),
                        ("ullTotalVirtual", ctypes.c_ulonglong),
                        ("ullAvailVirtual", ctypes.c_ulonglong),
                        ("ullAvailExtended", ctypes.c_ulonglong)]
        m = MS()
        m.dwLength = ctypes.sizeof(m)
        ctypes.windll.kernel32.GlobalMemoryStatusEx(
            ctypes.byref(m))
        return int(m.ullAvailPhys // 2**20)
    except Exception:
        return -1


def docker(args):
    r = run(["docker"] + args)
    return r.stdout.strip() if r and r.returncode == 0 else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Force", action="store_true")
    ap.add_argument("-Quiet", action="store_true")
    ap.add_argument("-MaxDowntimeMinutes", type=int, default=10)
    a = ap.parse_args()
    quiet = a.Quiet
    issues, warnings, info = [], [], []

    out("=== Pre-Bounce Safety Checklist ===\n", quiet)

    out("[1/8] Checking Devin.exe...", quiet)
    if proc_running("Devin.exe"):
        issues.append("Devin.exe is RUNNING")
        out("  BLOCKER: Devin.exe is running. Bounce will "
            "disconnect active session.", quiet)
    else:
        out("  Devin.exe: NOT RUNNING", quiet)

    out("[2/8] Checking devin-server in WSL...", quiet)
    r = run(["wsl.exe", "-d", "Ubuntu-24.04", "-e", "sh", "-lc",
             'pgrep -fc "out/server-main.js" 2>/dev/null'])
    n = (r.stdout or "").strip() if r else ""
    if re.match(r"^[1-9]", n):
        warnings.append(f"devin-server alive in WSL ({n} procs)")
        out(f"  devin-server: RUNNING ({n} processes)", quiet)
    else:
        out("  devin-server: NOT RUNNING", quiet)

    out("[3/8] Checking stateful containers...", quiet)
    critical = [("social-postgres", "Primary database (5433)"),
                ("postgres", "Secondary database (5432)"),
                ("redis", "Cache/session store"),
                ("minio", "Object storage"),
                ("chroma", "Vector database"),
                ("social-api", "SocialAuto API"),
                ("social-frontend", "SocialAuto Frontend"),
                ("n8n", "Workflow automation")]
    for name, reason in critical:
        st = docker(["ps", "--filter", f"name=^/{name}$",
                     "--format", "{{.Status}}"])
        if st:
            info.append(f"{name}: {st} - {reason}")
            out(f"  {name}: {st}", quiet)

    out("[4/8] Checking n8n active executions...", quiet)
    r = run(["curl.exe", "-s", "-m", "5",
             "http://localhost:5678/api/v1/executions"
             "?status=running&limit=5"])
    try:
        data = json.loads(r.stdout).get("data", []) if r else []
        if data:
            warnings.append(f"n8n has {len(data)} running "
                            "execution(s)")
            out(f"  n8n: {len(data)} RUNNING execution(s)",
                quiet)
            for e in data[:3]:
                out(f"    - {e.get('workflowId')} "
                    f"(started: {e.get('startedAt')})", quiet)
        else:
            out("  n8n: No running executions", quiet)
    except Exception:
        out("  n8n: API not accessible (may be starting)", quiet)

    out("[5/8] Checking Docker operations...", quiet)
    transitional = docker(["ps", "--filter", "status=created",
                           "--filter", "status=restarting",
                           "--format", "{{.Names}}"])
    if transitional:
        warnings.append("Containers in transitional state: "
                        + transitional.replace("\n", ", "))
        out("  Transitional containers: " + transitional, quiet)
    else:
        out("  No containers in created/restarting state", quiet)

    out("[6/8] Checking host memory pressure...", quiet)
    mb = avail_mb()
    if mb < 0:
        out("  Memory check: unavailable", quiet)
    elif mb < 1200:
        issues.append(f"CRITICAL: Host available {mb} MB")
        out(f"  Available: {mb} MB (CRITICAL)", quiet)
    elif mb < 2500:
        warnings.append(f"LOW: Host available {mb} MB")
        out(f"  Available: {mb} MB (LOW)", quiet)
    else:
        out(f"  Available: {mb} MB (OK)", quiet)

    out("[7/8] Checking VRAM pressure...", quiet)
    r = run(["nvidia-smi",
             "--query-gpu=memory.used,memory.total",
             "--format=csv,noheader,nounits"])
    m = re.search(r"(\d+)\s*,\s*(\d+)",
                  r.stdout if r else "")
    if m:
        used, total = int(m[1]), int(m[2])
        pct = int(100 * used / total)
        if pct > 90:
            issues.append(f"CRITICAL: VRAM {pct}%")
            out(f"  VRAM: {pct}% ({used}/{total} MB) - CRITICAL",
                quiet)
        elif pct > 80:
            warnings.append(f"HIGH: VRAM {pct}%")
            out(f"  VRAM: {pct}% ({used}/{total} MB) - HIGH",
                quiet)
        else:
            out(f"  VRAM: {pct}% ({used}/{total} MB) - OK",
                quiet)
    else:
        out("  VRAM: nvidia-smi unavailable", quiet)

    out("[8/8] Estimating downtime...", quiet)
    containers = len([x for x in docker(["ps", "-q"]).splitlines()
                      if x.strip()])
    auto = len([x for x in docker(
        ["ps", "-a", "--format",
         "{{.Names}} {{.HostConfig.RestartPolicy.Name}}"]
    ).splitlines()
                if re.search(r"always|unless-stopped", x)])
    est_min = math.ceil((30 + containers * 2 + auto * 5) / 60)
    out(f"  Running containers: {containers}", quiet)
    out(f"  Auto-restart containers: {auto}", quiet)
    out(f"  Estimated bounce time: ~{est_min} minute(s)", quiet)
    if est_min > a.MaxDowntimeMinutes:
        warnings.append(f"Estimated downtime ({est_min} min) "
                        "exceeds threshold")

    out("\n=== SUMMARY ===", quiet)
    for i in issues:
        out(f"  BLOCKER: {i}", quiet)
    for w in warnings:
        out(f"  WARN: {w}", quiet)
    for i in info:
        out(f"  INFO: {i}", quiet)
    out("", quiet)
    if issues and not a.Force:
        out(f"BOUNCE BLOCKED: {len(issues)} blocker(s). "
            "Use -Force to override.", quiet)
        return 2
    if issues:
        out("BOUNCE ALLOWED (forced): blockers overridden.",
            quiet)
        return 1
    if warnings:
        out(f"BOUNCE CAUTION: {len(warnings)} warning(s).",
            quiet)
        return 1
    out("BOUNCE SAFE: No blockers or warnings.", quiet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
