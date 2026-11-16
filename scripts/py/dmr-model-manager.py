"""Port of scripts/dmr-model-manager.ps1.

DMR (docker-model-runner) model management: list, evict, ttl,
watchdog, status, check-once. Reads nvidia-smi VRAM, DMR
/v1/models via docker exec, and log-parsed last-access.
"""

import argparse
import json
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

LOG = Path("D:/DevOptimizer/logs/dmr-model-manager.log")
STATE = Path("D:/DevOptimizer/logs/dmr-model-state.json")


def log(msg):
    try:
        LOG.parent.mkdir(exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} "
                    f"{msg}\n")
    except OSError:
        pass


def out(msg):
    print(msg)
    log(msg)


def run(cmd, timeout=30):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=timeout)
    except Exception:
        return None


def get_container():
    for extra in (["ps"], ["ps", "-a"]):
        r = run(["docker", *extra, "--filter",
                 "name=docker-model-runner",
                 "--format", "{{.Names}}"])
        c = (r.stdout if r else "").strip()
        if c:
            return c
    for name in ("docker-model-runner", "dmr",
                 "model-runner"):
        for extra in (["ps"], ["ps", "-a"]):
            r = run(["docker", *extra, "--filter",
                     f"name={name}", "--format",
                     "{{.Names}}"])
            c = (r.stdout if r else "").strip()
            if c:
                return c
    return None


def get_vram():
    r = run(["nvidia-smi",
             "--query-gpu=memory.used,memory.total",
             "--format=csv,noheader,nounits"])
    s = (r.stdout if r else "").strip()
    m = re.search(r"(\d+)\s*,\s*(\d+)", s)
    if not m:
        m = re.search(r"(\d+)\s+(\d+)", s)
    if not m:
        return {"Used": 0, "Total": 0, "Pct": 0}
    used, total = int(m[1]), int(m[2])
    return {"Used": used, "Total": total,
            "Pct": int(100 * used / total) if total else 0}


def get_models(container):
    models = []
    r = run(["docker", "exec", container, "curl", "-s",
             "http://localhost:12434/v1/models"], 30)
    if r and r.stdout and '"data"' in r.stdout:
        try:
            data = json.loads(r.stdout)["data"]
            for m in data:
                created = None
                if m.get("created"):
                    created = datetime.fromtimestamp(
                        m["created"])
                models.append(
                    {"Id": m.get("id", ""),
                     "OwnedBy": m.get("owned_by", ""),
                     "Created": created,
                     "SizeBytes":
                     int(m.get("size") or 0)})
        except Exception:
            pass
    return models


def get_last_access(container):
    access = {}
    r = run(["docker", "logs", "--tail", "500",
             container], 30)
    for line in ((r.stdout if r else "").splitlines()):
        if re.search(
                r"(GET|POST)\s+/v1/(chat/completions|"
                r"embeddings|models/[\w-]+)", line):
            m = re.search(r'model["\s:=]+([\w\-\.\/]+)',
                          line)
            if m:
                access[m[1]] = datetime.now()
    return access


def check_health(ttl, thresh, min_vram):
    res = {"ActionTaken": False, "Message": "",
           "ExitCode": 0}
    container = get_container()
    if not container:
        res["Message"] = ("docker-model-runner "
                          "container not found")
        res["ExitCode"] = 1
        return res
    vram = get_vram()
    models = get_models(container)
    last = get_last_access(container)
    now = datetime.now()
    evicted = []
    for m in models:
        lt = last.get(m["Id"]) or m["Created"]
        if lt and (now - lt).total_seconds() / 60 > ttl:
            evicted.append(m["Id"])
    should_evict = (len(evicted) > 0
                    and vram["Used"] > min_vram)
    if should_evict or vram["Pct"] > thresh:
        r = run(["docker", "restart", container], 120)
        ok = bool(r and r.returncode == 0)
        if ok:
            res["ActionTaken"] = True
            if should_evict:
                res["Message"] = (
                    f"Evicted idle models: "
                    f"{', '.join(evicted)}; restarted "
                    "docker-model-runner (VRAM was "
                    f"{vram['Used']}MB > {min_vram}MB)")
            else:
                res["Message"] = (
                    f"VRAM at {vram['Pct']}% "
                    f"(>{thresh}%); restarted "
                    "docker-model-runner preemptively")
            time.sleep(10)
        else:
            res["Message"] = ("FAILED to restart "
                              "docker-model-runner")
            res["ExitCode"] = 1
    else:
        res["Message"] = (
            f"VRAM {vram['Pct']}% ({vram['Used']}MB), "
            f"{len(models)} model(s) loaded, "
            f"idle>{ttl}min: {len(evicted)}, "
            f"threshold: {min_vram}MB")
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Action", default="list",
                    choices=["list", "evict", "ttl",
                             "watchdog", "status",
                             "check-once"])
    ap.add_argument("-Model", default="")
    ap.add_argument("-TTLMinutes", type=int, default=15)
    ap.add_argument("-VramPressureThreshold", type=int,
                    default=90)
    ap.add_argument("-MinModelVramForEvictMB", type=int,
                    default=6000)
    ap.add_argument("-All", action="store_true")
    ap.add_argument("-Force", action="store_true")
    ap.add_argument("-IntervalSeconds", type=int,
                    default=60)
    a = ap.parse_args()

    if a.Action == "list":
        out("=== DMR Model Manager ===")
        v = get_vram()
        out(f"VRAM: {v['Used']} / {v['Total']} MB "
            f"({v['Pct']}%)")
        out("")
        c = get_container()
        if not c:
            out("ERROR: docker-model-runner container "
                "not found")
            return 1
        out(f"Container: {c}\n")
        models = get_models(c)
        last = get_last_access(c)
        now = datetime.now()
        if not models:
            out("No models currently loaded (or DMR API "
                "not responding)")
        else:
            out(f"{'MODEL ID':<40} {'SIZE (MB)':>12} "
                f"{'LAST ACCESS':>20} "
                f"{'IDLE (MIN)':>15}")
            out("-" * 90)
            for m in models:
                size = (round(m["SizeBytes"] / 2**20, 1)
                        if m["SizeBytes"] > 0
                        else "unknown")
                lt = last.get(m["Id"]) or m["Created"]
                idle = (round((now - lt)
                              .total_seconds() / 60, 1)
                        if lt else "unknown")
                lt_s = (lt.strftime("%Y-%m-%d %H:%M")
                        if lt else "never")
                out(f"{m['Id'][:40]:<40} {size:>12} "
                    f"{lt_s:>20} {idle:>15}")
        return 0

    if a.Action == "evict":
        c = get_container()
        if not c:
            out("ERROR: docker-model-runner container "
                "not found")
            return 1
        if not a.Model and not a.All:
            out("ERROR: Specify -Model <name> or -All")
            return 1
        if a.Model:
            out(f"Evicting model: {a.Model}")
            if not a.Force:
                if not sys.stdin.isatty():
                    out("Cancelled (non-interactive; "
                        "pass -Force)")
                    return 0
                if input("This will restart "
                         "docker-model-runner (evicts "
                         "ALL models). Continue? (y/N) "
                         ).strip() != "y":
                    out("Cancelled")
                    return 0
        else:
            out("Evicting ALL models (restarting "
                "docker-model-runner)...")
        r = run(["docker", "restart", c], 120)
        if not (r and r.returncode == 0):
            out("ERROR: restart failed")
            return 1
        out("SUCCESS: docker-model-runner restarted")
        time.sleep(10)
        v = get_vram()
        out(f"VRAM after: {v['Used']} / {v['Total']} MB "
            f"({v['Pct']}%)")
        return 0

    if a.Action == "ttl":
        out(f"Setting DMR model TTL to {a.TTLMinutes} "
            "minutes (idle eviction)")
        out(f"VRAM pressure threshold: "
            f"{a.VramPressureThreshold}%")
        out(f"Min model VRAM for eviction: "
            f"{a.MinModelVramForEvictMB} MB")
        st = {"TTLMinutes": a.TTLMinutes, "Enabled": True,
              "VramPressureThreshold":
              a.VramPressureThreshold,
              "MinModelVramForEvictMB":
              a.MinModelVramForEvictMB,
              "Updated": datetime.now().isoformat()}
        STATE.write_text(json.dumps(st, indent=2))
        out(f"TTL config saved to {STATE}")
        out("Run 'dmr-model-manager watchdog' to start "
            "background eviction monitor")
        return 0

    if a.Action == "watchdog":
        out(f"Starting DMR Model Watchdog (interval: "
            f"{a.IntervalSeconds}s, TTL: {a.TTLMinutes}"
            f"min, VRAM threshold: "
            f"{a.VramPressureThreshold}%, Min VRAM for "
            f"evict: {a.MinModelVramForEvictMB}MB)")
        out("Press Ctrl+C to stop")
        log(f"Watchdog started: interval="
            f"{a.IntervalSeconds}s ttl={a.TTLMinutes}min")
        STATE.write_text(json.dumps({
            "TTLMinutes": a.TTLMinutes, "Enabled": True,
            "VramPressureThreshold":
            a.VramPressureThreshold,
            "MinModelVramForEvictMB":
            a.MinModelVramForEvictMB}, indent=2))
        try:
            while True:
                r = check_health(
                    a.TTLMinutes,
                    a.VramPressureThreshold,
                    a.MinModelVramForEvictMB)
                out(f"Watchdog: {r['Message']}")
                time.sleep(a.IntervalSeconds)
        except KeyboardInterrupt:
            out("Watchdog stopped")
        return 0

    if a.Action == "check-once":
        out("=== DMR Health Check (single run) ===")
        r = check_health(a.TTLMinutes,
                         a.VramPressureThreshold,
                         a.MinModelVramForEvictMB)
        kind = "ACTION" if r["ActionTaken"] else "OK"
        out(f"{kind}: {r['Message']}")
        log(f"Check-once: {r['Message']}")
        return r["ExitCode"]

    if a.Action == "status":
        out("=== DMR Status ===")
        v = get_vram()
        out(f"VRAM: {v['Used']} / {v['Total']} MB "
            f"({v['Pct']}%)")
        c = get_container()
        if c:
            out(f"Container: {c} (RUNNING)")
            models = get_models(c)
            out(f"Models loaded: {len(models)}")
            if models:
                out("Model IDs: " + ", ".join(
                    m["Id"] for m in models))
        else:
            out("Container: NOT RUNNING")
        if STATE.exists():
            st = json.loads(STATE.read_text())
            out(f"TTL Config: {st.get('TTLMinutes')} min, "
                f"Enabled: {st.get('Enabled')}")
        else:
            out("TTL Config: not set")
    return 0


if __name__ == "__main__":
    sys.exit(main())
