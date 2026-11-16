"""Port of scripts/health-dashboard.ps1.

Generates logs/health-dashboard.html (self-contained) and
logs/health-dashboard.json summarizing subsystem health:
WSL Permanent Fix, WSL Guardian, Host Guard, Docker-WSL Sync,
DD Settings Watchdog, Admin Cleanup.
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

HOME = Path(os.environ.get("DEVOPT_HOME", "D:\\DevOptimizer"))
LOGS = HOME / "logs"
HTML_OUT = LOGS / "health-dashboard.html"
JSON_OUT = LOGS / "health-dashboard.json"


def read_json(path):
    try:
        return json.loads(Path(path).read_text(
            encoding="utf-8-sig"))
    except Exception:
        return {}


def tail(path, n):
    try:
        return Path(path).read_text(
            encoding="utf-8-sig",
            errors="replace").splitlines()[-n:]
    except Exception:
        return []


def wsl_fix():
    s = read_json(LOGS / "wsl-permanent-fix-state.json")
    if not s:
        return {"status": "Unknown", "lastGate": "none",
                "wslexecDetected": False,
                "lastDockerStart": "never"}
    gate = s.get("lastGate", "unknown")
    wslx = s.get("wslexecDetected", False)
    return {"lastGate": gate, "wslexecDetected": wslx,
            "lastDockerStart": s.get("lastDockerStart",
                                     "never"),
            "status": ("Warning" if wslx else
                       "Healthy"
                       if gate == "Layer4-ConfigHardened"
                       else "Unknown")}


def guardian():
    s = read_json(r"C:\ProgramData\wsl-guardian\state.json")
    if not s:
        return {"status": "Unknown", "deepFails": 0,
                "postT2Fails": 0, "lastT1": "never",
                "lastT2": "never", "lastT3": "never",
                "t2Pending": False}
    df = s.get("deepFails", 0)
    return {"deepFails": df,
            "postT2Fails": s.get("postT2Fails", 0),
            "lastT1": s.get("lastT1", "never"),
            "lastT2": s.get("lastT2", "never"),
            "lastT3": s.get("lastT3", "never"),
            "t2Pending": s.get("t2Pending", False),
            "status": ("Critical" if df >= 4 else
                       "Warning" if df >= 2 else "Healthy")}


def host_guard():
    s = read_json(LOGS / "host-guard-state.json")
    if not s:
        return {"status": "Unknown", "availMB": 0,
                "vramPct": 0, "commitPct": 0,
                "lastDropCaches": "never",
                "lastUnload": "never", "lastBounce": "never"}
    m = s.get("metrics") or {}
    avail = m.get("availMB", 0)
    vram = m.get("vramPct", 0)
    return {"availMB": avail, "vramPct": vram,
            "commitPct": m.get("commitPct", 0),
            "lastDropCaches": s.get("lastDropCaches", "never"),
            "lastUnload": s.get("lastUnload", "never"),
            "lastBounce": s.get("lastBounce", "never"),
            "status": ("Critical" if avail < 1200 else
                       "Warning" if avail < 2500 or vram > 85
                       else "Healthy")}


def docker_sync():
    last_run, actions, up = "never", 0, 0
    for line in tail(LOGS / "docker-wsl-sync.log", 20):
        if "sync run started" in line:
            p = line.split(" ")
            last_run = p[0] + " " + p[1]
        m = re.search(
            r"sync complete: (\d+) container.*?(\d+) repair",
            line)
        if m:
            up, actions = int(m[1]), int(m[2])
    return {"lastRun": last_run, "actions": actions,
            "containersUp": up,
            "status": "Warning" if actions > 0 else "Healthy"}


def dd_watchdog():
    s = read_json(LOGS / "dd-settings-watchdog-state.json")
    if not s:
        return {"status": "Unknown", "lastCheck": "never",
                "lastDrift": "never", "lastRestore": "never",
                "driftCount": 0, "restoreCount": 0}
    dc = s.get("driftCount", 0)
    warn = dc > 0 and str(s.get("lastDrift", "")) \
        > str(s.get("lastRestore", ""))
    return {"lastCheck": s.get("lastCheck", "never"),
            "lastDrift": s.get("lastDrift", "never"),
            "lastRestore": s.get("lastRestore", "never"),
            "driftCount": dc,
            "restoreCount": s.get("restoreCount", 0),
            "status": "Warning" if warn else "Healthy"}


def admin_cleanup():
    last_run, freed = "never", 0
    for line in tail(LOGS / "admin-cleanup-elevated.log", 10):
        m = re.search(r"Freed on C:.*: ([\d.]+) GB", line)
        if m:
            freed = float(m[1])
        if "=== Summary ===" in line:
            last_run = f"{datetime.now():%Y-%m-%d %H:%M}"
    return {"lastRun": last_run, "freedGB": freed,
            "status": "Healthy"}


def color(status):
    return {"Healthy": "#22c55e", "Warning": "#f59e0b",
            "Critical": "#ef4444"}.get(status, "#6b7280")


CSS_CLASS = {"Healthy": "healthy", "Warning": "warning",
             "Critical": "critical"}


def card(title, status, metrics):
    rows = "".join(
        f'<div class="metric"><span class="metric-label">'
        f'{k}</span><span class="metric-value '
        f'{CSS_CLASS.get(sc, "")}">{v}</span></div>'
        for k, v, sc in metrics)
    c = color(status)
    return (f'<div class="card"><div class="card-header">'
            f'<span class="card-title">{title}</span>'
            f'<span class="status-badge" style="background: '
            f'{c}20; color: {c};">{status}</span></div>'
            f'{rows}</div>')


def main():
    subs = {
        "wslPermanentFix": wsl_fix(),
        "wslGuardian": guardian(),
        "hostGuard": host_guard(),
        "dockerWslSync": docker_sync(),
        "ddSettingsWatchdog": dd_watchdog(),
        "adminCleanup": admin_cleanup(),
    }
    sts = [s["status"] for s in subs.values()]
    overall = ("Critical" if "Critical" in sts else
               "Warning" if "Warning" in sts else "Healthy")
    data = {"timestamp": datetime.now().isoformat(),
            "overall": overall, "subsystems": subs}
    LOGS.mkdir(exist_ok=True)
    JSON_OUT.write_text(json.dumps(data, indent=2),
                        encoding="utf-8")

    w, g, h, ds, dd, ac = subs.values()
    cards = "".join([
        card("WSL Permanent Fix (4 Layers)", w["status"], [
            ("Last Gate", w["lastGate"], ""),
            ("WSLEXEC Detected",
             "Yes" if w["wslexecDetected"] else "No",
             "Warning" if w["wslexecDetected"] else "Healthy"),
            ("Last Docker Start", w["lastDockerStart"], "")]),
        card("WSL Guardian (T1-T3)", g["status"], [
            ("Deep Fails", g["deepFails"],
             "Critical" if g["deepFails"] >= 4 else
             "Warning" if g["deepFails"] >= 2 else "Healthy"),
            ("Post-T2 Fails", g["postT2Fails"],
             "Warning" if g["postT2Fails"] > 0 else "Healthy"),
            ("T2 Pending",
             "Yes" if g["t2Pending"] else "No",
             "Warning" if g["t2Pending"] else "Healthy"),
            ("Last T1", g["lastT1"], ""),
            ("Last T2", g["lastT2"], ""),
            ("Last T3", g["lastT3"], "")]),
        card("Host Guard (T2-T4)", h["status"], [
            ("Available RAM", f"{h['availMB']} MB",
             "Critical" if h["availMB"] < 1200 else
             "Warning" if h["availMB"] < 2500 else "Healthy"),
            ("VRAM Usage", f"{h['vramPct']}%",
             "Warning" if h["vramPct"] > 85 else "Healthy"),
            ("Commit %", f"{h['commitPct']}%",
             "Warning" if h["commitPct"] > 90 else "Healthy"),
            ("Last Drop Caches", h["lastDropCaches"], ""),
            ("Last Model Unload", h["lastUnload"], ""),
            ("Last Auto-Bounce", h["lastBounce"], "")]),
        card("Docker-WSL Sync", ds["status"], [
            ("Containers Up", ds["containersUp"], ""),
            ("Repair Actions", ds["actions"],
             "Warning" if ds["actions"] > 0 else "Healthy"),
            ("Last Run", ds["lastRun"], "")]),
        card("DD Settings Watchdog", dd["status"], [
            ("Drift Count", dd["driftCount"],
             "Warning" if dd["driftCount"] > 0 else "Healthy"),
            ("Restore Count", dd["restoreCount"], ""),
            ("Last Check", dd["lastCheck"], ""),
            ("Last Drift", dd["lastDrift"],
             "Warning" if str(dd["lastDrift"])
             > str(dd["lastRestore"]) else "Healthy"),
            ("Last Restore", dd["lastRestore"], "")]),
        card("Admin Cleanup", ac["status"], [
            ("Last Run", ac["lastRun"], ""),
            ("Freed Space", f"{ac['freedGB']} GB", "Healthy")]),
    ])
    oc = color(overall)
    html = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="60">
<title>DevOptimizer Health Dashboard</title>
<style>
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; padding: 20px; line-height: 1.5; }}
.container {{ max-width: 1200px; margin: 0 auto; }}
header {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid #1e293b; }}
h1 {{ font-size: 1.5rem; font-weight: 600; }}
.overall {{ display: flex; align-items: center; gap: 12px; padding: 12px 20px; border-radius: 8px; font-weight: 600; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 16px; }}
.card {{ background: #1e293b; border-radius: 8px; padding: 20px; border: 1px solid #334155; }}
.card-header {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }}
.card-title {{ font-weight: 600; font-size: 1rem; }}
.status-badge {{ padding: 4px 12px; border-radius: 9999px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; }}
.metric {{ display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #334155; }}
.metric:last-child {{ border-bottom: none; }}
.metric-label {{ color: #94a3b8; }}
.metric-value {{ font-weight: 500; font-family: monospace; }}
.metric-value.warning {{ color: #f59e0b; }}
.metric-value.critical {{ color: #ef4444; }}
.metric-value.healthy {{ color: #22c55e; }}
.timestamp {{ color: #64748b; font-size: 0.8rem; text-align: right; margin-top: 20px; }}
.refresh-info {{ color: #64748b; font-size: 0.75rem; }}
</style></head><body><div class="container">
<header><h1>DevOptimizer Health Dashboard</h1>
<div class="overall" style="background: {oc}20; color: {oc};">
<span style="width: 10px; height: 10px; border-radius: 50%; background: {oc};"></span>
<span>Overall: {overall}</span></div></header>
<div class="grid">{cards}</div>
<div class="timestamp">Last updated: {datetime.now():%Y-%m-%d %H:%M:%S}<br>
<span class="refresh-info">Auto-refresh: 60s (page) / 30s (data)</span></div>
</div></body></html>"""
    HTML_OUT.write_text(html, encoding="utf-8")
    print(f"Health dashboard generated: {HTML_OUT} and "
          f"{JSON_OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
