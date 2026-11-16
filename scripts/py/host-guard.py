"""Port of scripts/host-guard.ps1.

Host memory/VRAM guard - tiered self-healing:
  T2  Available < soft           -> guest drop_caches (30 min)
  T3  VRAM > thresh AND low mem  -> restart docker-model-runner
  T4  Available < critical       -> llama cull; auto-bounce
                                  only when Devin.exe is closed.
Events 1006 (warning) / 1007 (critical). Log: logs/host-guard.log
"""

import argparse
import ctypes
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

HOME = Path(os.environ.get("DEVOPT_HOME", "D:\\DevOptimizer"))
LOG_FILE = HOME / "logs" / "host-guard.log"
STATE_FILE = HOME / "logs" / "host-guard-state.json"
NOTIFY_PS1 = Path(__file__).resolve().parents[1] / "lib" \
    / "Notify.ps1"


def log(msg):
    try:
        LOG_FILE.parent.mkdir(exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}\n")
    except OSError:
        pass


def alert(event_id, msg, severity):
    log(f"event{event_id}: {msg}")
    if NOTIFY_PS1.exists():
        subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             f'. "{NOTIFY_PS1}"; Send-DevOptAlert -Severity '
             f'{severity} -Title "Host Guard Event {event_id}" '
             f'-Message "{msg}" -Tags host-guard,memory,vram '
             f"-EventId {event_id}"],
            capture_output=True)


def run(cmd, timeout=30, inp=None):
    try:
        return subprocess.run(cmd, capture_output=True, text=True,
                              timeout=timeout, input=inp)
    except Exception:
        return None


def proc_running(name):
    r = run(["tasklist", "/FI", f"IMAGENAME eq {name}", "/NH"])
    return bool(r and name.lower() in r.stdout.lower())


def proc_ws_bytes(name):
    r = run(["powershell", "-NoProfile", "-Command",
             f"(Get-Process '{name}' -ErrorAction "
             "SilentlyContinue | Measure-Object WorkingSet64 "
             "-Sum).Sum"])
    try:
        return float(r.stdout.strip() or 0)
    except Exception:
        return 0.0


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
        avail = int(m.ullAvailPhys // 2**20)
        commit = (int(round(100 * (1 - m.ullAvailPageFile / m.ullTotalPageFile)))
                  if m.ullTotalPageFile else 0)
        return avail, commit
    except Exception:
        return -1, -1


def vram():
    r = run(["nvidia-smi",
             "--query-gpu=memory.used,memory.total",
             "--format=csv,noheader,nounits"])
    m = re.search(r"(\d+)\s*,\s*(\d+)", r.stdout if r else "")
    return (int(m[1]), int(m[2])) if m else (0, 0)


def load_state():
    try:
        return json.loads(STATE_FILE.read_text(
            encoding="utf-8-sig"))
    except Exception:
        return {}


def save_state(state):
    try:
        STATE_FILE.parent.mkdir(exist_ok=True)
        STATE_FILE.write_text(json.dumps(state),
                              encoding="utf-8")
    except OSError:
        pass


def last_action(state, key):
    v = state.get(key)
    if not v:
        return datetime.min
    try:
        return datetime.fromisoformat(
            str(v).replace("Z", "+00:00")).replace(tzinfo=None)
    except Exception:
        return datetime.min


def cull_llamas():
    r = run(["powershell", "-NoProfile", "-Command",
             "$l=Get-Process com.docker.llama-server "
             "-ErrorAction SilentlyContinue; if ($l) { "
             "$mb=[int](($l | Measure-Object WorkingSet64 -Sum)"
             ".Sum/1MB); $l | Stop-Process -Force; "
             "Write-Output \"$($l.Count) llamas ~$mb MB\" "
             "} else { Write-Output '0 llamas' }"])
    out = (r.stdout or "").strip() if r else "0 llamas"
    time.sleep(3)
    return out if out else "0 llamas"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-SoftThresholdMB", type=int, default=2500)
    ap.add_argument("-CriticalThresholdMB", type=int,
                    default=1200)
    ap.add_argument("-VramPercentThreshold", type=int,
                    default=85)
    ap.add_argument("-RateLimitMinutes", type=int, default=30)
    ap.add_argument("-BounceRateLimitMinutes", type=int,
                    default=60)
    ap.add_argument("-OnceVerbose", action="store_true")
    a = ap.parse_args()

    avail, commit_pct = avail_mb()
    vram_used, vram_total = vram()
    vram_pct = int(100 * vram_used / vram_total) \
        if vram_total else 0
    vmmem_gb = proc_ws_bytes("vmmemWSL") / 2**30
    log(f"metrics: avail={avail}MB vram={vram_used}/"
        f"{vram_total}MB ({vram_pct}%) "
        f"vmmemWSL={vmmem_gb:.1f}GB commit={commit_pct}%")

    state = load_state()
    now = datetime.now()
    devin_open = proc_running("Devin.exe")
    wsl_up = proc_running("vmmemWSL")
    engine = run(["docker", "info"])
    engine_up = bool(engine and engine.returncode == 0)

    state["metrics"] = {"availMB": avail, "vramPct": vram_pct,
                        "commitPct": commit_pct}
    save_state(state)

    # T2: soft pressure -> guest drop_caches
    if (wsl_up and 0 <= avail < a.SoftThresholdMB
            and last_action(state, "lastDropCaches")
            < now - timedelta(minutes=a.RateLimitMinutes)):
        run(["wsl.exe", "-d", "Ubuntu-24.04", "-u", "root",
             "--", "sh", "-c",
             "sync; echo 3 > /proc/sys/vm/drop_caches"])
        alert(1006,
              f"Available {avail} MB < {a.SoftThresholdMB} - "
              "guest drop_caches applied", "Warning")
        state["lastDropCaches"] = now.isoformat()
        save_state(state)
        time.sleep(10)
        avail, _ = avail_mb()
        log(f"post-dropcache available: {avail} MB")

    # T3: VRAM squeeze + host pressure -> restart model runner
    # GOTCHA: never `docker model *` (re-attempts broken
    # standalone-runner install, exits 127) - restart the
    # integrated docker-model-runner container to evict.
    if (engine_up and vram_pct > a.VramPercentThreshold
            and 0 <= avail < a.SoftThresholdMB
            and last_action(state, "lastUnload")
            < now - timedelta(minutes=a.RateLimitMinutes)):
        r = run(["docker", "restart", "docker-model-runner"])
        if r and r.returncode == 0:
            alert(1006,
                  f"VRAM {vram_pct}% + Available {avail} MB - "
                  "docker-model-runner restarted (evicted)",
                  "Warning")
            state["lastUnload"] = datetime.now().isoformat()
            save_state(state)
            time.sleep(10)
            used, _ = vram()
            log(f"VRAM after runner restart: {used} MiB")
        else:
            log("T3 skipped: docker-model-runner restart "
                "failed")

    # T4: critical -> cull, then auto-bounce when Devin closed
    if 0 <= avail < a.CriticalThresholdMB:
        if devin_open:
            cull = cull_llamas()
            after, _ = avail_mb()
            sev = "Critical" if after < a.CriticalThresholdMB \
                else "Warning"
            alert(1007,
                  f"CRITICAL Available {avail} MB with Devin "
                  f"OPEN - {cull}; available now {after} MB. "
                  "No bounce while Devin open.", sev)
            return 0
        if last_action(state, "lastBounce") \
                >= now - timedelta(
                    minutes=a.BounceRateLimitMinutes):
            cull = cull_llamas()
            log(f"T4: bounce rate-limited; {cull}")
            return 0
        state["lastBounce"] = now.isoformat()
        save_state(state)
        log("T4: critical memory with Devin closed - "
            "AUTO-BOUNCE starting")
        cli = r"C:\Program Files\Docker\Docker\DockerCli.exe"
        if os.path.exists(cli):
            run([cli, "-Shutdown"])
        for p in ("Docker Desktop.exe",
                  "com.docker.backend.exe"):
            run(["taskkill", "/F", "/IM", p])
        time.sleep(3)
        run(["wsl.exe", "--shutdown"])
        deadline = time.time() + 60
        while time.time() < deadline:
            if not proc_running("vmmemWSL"):
                break
            time.sleep(2)
        dd = r"C:\Program Files\Docker\Docker" \
            r"\Docker Desktop.exe"
        if os.path.exists(dd):
            subprocess.Popen([dd])
        deadline = time.time() + 180
        while time.time() < deadline:
            r = run(["docker", "info"])
            if r and r.returncode == 0:
                break
            time.sleep(5)
        log("engine restarted - bridge grace 120s")
        time.sleep(120)
        names = run(["docker", "ps", "-a", "--filter",
                     "status=exited", "--format", "{{.Names}}"])
        for c in ((names.stdout if names else "") or "").splitlines():
            c = c.strip()
            if not c:
                continue
            pol = run(["docker", "inspect", c, "--format",
                       "{{.HostConfig.RestartPolicy.Name}}"])
            p = (pol.stdout or "").strip() if pol else ""
            if re.search(r"always|unless-stopped", p):
                run(["docker", "start", c])
                log(f"  recovered: {c}")
        time.sleep(15)
        probe = run(["curl.exe", "-s", "-o", "NUL", "-w",
                     "%{http_code}", "-m", "10",
                     "http://localhost:9390/metrics"])
        code = (probe.stdout or "").strip() if probe else ""
        after, _ = avail_mb()
        sev = "Critical" if after < a.CriticalThresholdMB \
            else "Warning"
        alert(1007,
              f"CRITICAL {avail} MB -> auto-bounce done. "
              f"Available now {after} MB, 9390={code}", sev)
        return 0

    if a.OnceVerbose:
        print(f"metrics: avail={avail}MB vram={vram_pct}% "
              f"commit={commit_pct}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
