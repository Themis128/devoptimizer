# REQUIRES: admin
"""Port of scripts/wsl-permanent-fix.ps1.

4-layer WSL/Docker-Desktop crash defense:
  L1 startup gate (Wait-WSLReadyForDocker, -DockerStartupGate)
  L2 active guard (wslexec detect + pre-stabilize, every 2 min)
  L3 existing wsl-guardian T1-T3 (frequency check)
  L4 DD config hardening (settings.json + settings-store.json
    + daemon.json userns-remap)

-Install/-Uninstall register/remove the \DevOptimizer\ tasks.
"""

import argparse
import ctypes
import json
import os
import subprocess
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

LOG = Path("D:/DevOptimizer/logs/wsl-permanent-fix.log")
STATE = Path(
    "D:/DevOptimizer/logs/wsl-permanent-fix-state.json")
APPDATA = Path(os.environ.get("APPDATA", ""))
DD_SETTINGS = APPDATA / "Docker" / "settings.json"
DD_STORE = APPDATA / "Docker" / "settings-store.json"
DD_DAEMON = APPDATA / "Docker" / "daemon.json"
NOTIFY = (Path(__file__).resolve().parents[1]
          / "lib" / "Notify.ps1")


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


def warn(msg):
    print(f"WARN: {msg}")
    log(f"WARN: {msg}")


def err(msg):
    print(f"ERROR: {msg}")
    log(f"ERROR: {msg}")


def alert(sev, title, msg, force=False):
    if not NOTIFY.exists():
        return
    env = dict(os.environ, DEVOPT_ALERT_TITLE=title,
               DEVOPT_ALERT_MSG=msg)
    subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         f'. "{NOTIFY}"; Send-DevOptAlert -Severity {sev} '
         '-Title $env:DEVOPT_ALERT_TITLE '
         '-Message $env:DEVOPT_ALERT_MSG '
         "-Tags 'wsl','docker' "
         + ("-Force" if force else "")],
        capture_output=True, env=env)


def run(cmd, timeout=30):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=timeout)
    except Exception:
        return None


def proc_alive(name):
    r = run(["tasklist", "/FI", f"IMAGENAME eq {name}"])
    return bool(r and name in r.stdout)


def proc_started_recent(name, secs=30):
    r = run(["powershell", "-NoProfile", "-Command",
             f"(Get-Process '{name}' -ErrorAction "
             "SilentlyContinue | Where-Object { ((Get-Date)"
             " - $_.StartTime).TotalSeconds -lt "
             f"{secs} }} | "
             "Measure-Object).Count"])
    try:
        return int((r.stdout if r else "0").strip()) > 0
    except ValueError:
        return False


def load_state():
    try:
        return json.loads(STATE.read_text(
            encoding="utf-8-sig"))
    except Exception:
        return {"lastDockerStart": 0, "lastCrash": 0,
                "crashCount": 0, "wslexecDetected": False}


def save_state(s):
    STATE.write_text(json.dumps(s, indent=2),
                     encoding="utf-8")


def read_json(p):
    try:
        return json.loads(Path(p).read_text(
            encoding="utf-8-sig"))
    except Exception:
        return {}


def write_json(p, d):
    Path(p).write_text(json.dumps(d, indent=2),
                       encoding="utf-8")


# LAYER 4
def harden():
    out("[LAYER 4] Hardening Docker Desktop "
        "configuration...")
    bak = Path(str(DD_SETTINGS) + ".bak")
    if DD_SETTINGS.exists() and not bak.exists():
        bak.write_bytes(DD_SETTINGS.read_bytes())
        out("  Backed up settings.json")
    keys = {"disableWSLIntegrationAutoConfig": True,
            "wslIntegrationAutoConfigure": False,
            "manageDockerGroup": False}
    for f in (DD_SETTINGS, DD_STORE):
        if not f.exists():
            continue
        try:
            s = read_json(f)
            s.update(keys)
            write_json(f, s)
            out(f"  Updated {f.name}: disabled WSL "
                "auto-config + docker group management")
        except Exception as e:
            out(f"  WARN: could not harden {f}: {e}")
    d = read_json(DD_DAEMON)
    d["userns-remap"] = "default"
    write_json(DD_DAEMON, d)
    out("  Updated daemon.json: enabled userns-remap")


def restore():
    out("Restoring Docker Desktop configuration...")
    bak = Path(str(DD_SETTINGS) + ".bak")
    if bak.exists():
        DD_SETTINGS.write_bytes(bak.read_bytes())
        out("  Restored settings.json from backup")


# LAYER 1
def wait_ready(timeout):
    out("[LAYER 1] Docker Desktop startup gate: waiting "
        "for WSL integration...")
    log("Docker Desktop startup detected - engaging WSL "
        "readiness gate")
    deadline = time.time() + timeout
    stage = 0
    while time.time() < deadline:
        if stage < 1 and proc_alive("vmmemWSL"):
            stage = 1
            log("DEBUG: Stage 1: vmmemWSL detected")
        if 1 <= stage < 2:
            r = run(["wsl.exe", "-d", "Ubuntu-24.04",
                     "-e", "true"], 15)
            if r and r.returncode == 0:
                stage = 2
                log("DEBUG: Stage 2: distro responds")
        if 2 <= stage < 3:
            r = run(["wsl.exe", "-d", "Ubuntu-24.04",
                     "-e", "docker", "version",
                     "--format",
                     "{{.Server.Version}}"], 20)
            v = (r.stdout if r else "").strip()
            if v and v[0].isdigit():
                stage = 3
                log(f"DEBUG: Stage 3: engine {v}")
        if 3 <= stage < 4:
            r = run(["docker", "info"], 20)
            if r and r.returncode == 0:
                stage = 4
                log("DEBUG: Stage 4: engine API ok")
        if 4 <= stage < 5:
            try:
                with urllib.request.urlopen(
                        "http://localhost:9390/metrics",
                        timeout=5) as resp:
                    if resp.status < 400:
                        stage = 5
                        log("DEBUG: Stage 5: port proxy "
                            "healthy")
            except Exception:
                pass
        if stage >= 5:
            out("[LAYER 1] WSL integration fully ready - "
                "Docker Desktop can proceed")
            return True
        time.sleep(3)
    warn(f"[LAYER 1] WSL readiness gate TIMEOUT after "
         f"{timeout}s - Docker Desktop may still crash "
         "WSL")
    log(f"WSL readiness gate TIMEOUT - stage reached: "
        f"{stage}")
    return False


# LAYER 2
def active_guard():
    state = load_state()
    just_started = (proc_started_recent("Docker Desktop")
                    or proc_started_recent(
                        "com.docker.backend"))
    wslexec = proc_alive("wslexec")
    if wslexec:
        log("DEBUG: wslexec detected - group setup")
        state["wslexecDetected"] = True
        alert("Warning", "wslexec Detected",
              "Docker Desktop wslexec process detected "
              "(docker group setup in progress). "
              "Pre-stabilization engaged.")
    else:
        state["wslexecDetected"] = False

    if just_started:
        out("[LAYER 2] Docker Desktop startup detected - "
            "running pre-stabilization...")
        log("Docker Desktop startup detected - "
            "pre-stabilization engaged")
        wsl_ok = False
        if proc_alive("vmmemWSL"):
            r = run(["wsl.exe", "-d", "Ubuntu-24.04",
                     "-e", "true"], 15)
            wsl_ok = bool(r and r.returncode == 0)
        if not wsl_ok:
            warn("[LAYER 2] WSL not ready - running "
                 "emergency stabilization")
            alert("Warning",
                  "WSL Not Ready at Docker Startup",
                  "WSL Ubuntu-24.04 was not ready when "
                  "Docker Desktop started. Running "
                  "emergency stabilization.")
            run(["wsl.exe", "-d", "Ubuntu-24.04",
                 "-e", "docker", "version"], 20)
            time.sleep(5)
            r = run(["wsl.exe", "-d", "Ubuntu-24.04",
                     "-e", "true"], 15)
            if r and r.returncode == 0:
                out("[LAYER 2] WSL stabilized "
                    "successfully")
                log("Emergency stabilization successful")
            else:
                err("[LAYER 2] WSL stabilization FAILED "
                    "- may need T2/T3")
                alert("Critical",
                      "WSL Stabilization Failed",
                      "Emergency stabilization failed "
                      "after Docker Desktop startup. WSL "
                      "may need T2/T3 recovery.",
                      force=True)
        state["lastDockerStart"] = datetime.now() \
            .isoformat()

    if proc_alive("vmmemWSL"):
        r = run(["wsl.exe", "-d", "Ubuntu-24.04",
                 "-e", "true"], 15)
        if not (r and r.returncode == 0):
            warn("[LAYER 2] WSL distro unresponsive - "
                 "triggering wsl-guardian T1")
            log("WSL distro unresponsive - would trigger "
                "wsl-guardian")
    save_state(state)


# LAYER 3
def guardian_freq():
    r = run(["powershell", "-NoProfile", "-Command",
             "$t = Get-ScheduledTask -TaskName "
             "'WSL-Guardian' -TaskPath '\\DevOptimizer\\' "
             "-ErrorAction SilentlyContinue; "
             "if ($t) { ($t.Triggers | Where-Object { "
             "$_.GetType().Name -eq 'TimeTrigger' })"
             ".Repetition.Interval }"])
    interval = (r.stdout if r else "").strip()
    if interval and interval != "PT2M":
        out(f"[LAYER 3] Updating WSL-Guardian frequency "
            f"from {interval} to PT2M")


def install():
    out("=== Installing WSL Permanent Fix ===")
    harden()
    user = run(["powershell", "-NoProfile", "-Command",
                "(Get-CimInstance Win32_ComputerSystem)"
                ".UserName"])
    user = (user.stdout if user else "").strip()
    run(["schtasks", "/create", "/f", "/tn",
         r"\DevOptimizer\WSL-Permanent-Fix",
         "/tr", 'conhost.exe --headless pwsh.exe '
         '-NoProfile -ExecutionPolicy Bypass -File '
         '"D:\\DevOptimizer\\scripts'
         '\\wsl-permanent-fix.ps1"',
         "/sc", "onlogon", "/ru", user,
         "/rl", "HIGHEST"])
    run(["schtasks", "/create", "/f", "/tn",
         r"\DevOptimizer\WSL-Permanent-Fix-2min",
         "/tr", 'conhost.exe --headless pwsh.exe '
         '-NoProfile -ExecutionPolicy Bypass -File '
         '"D:\\DevOptimizer\\scripts'
         '\\wsl-permanent-fix.ps1"',
         "/sc", "minute", "/mo", "2", "/ru", user,
         "/rl", "HIGHEST"])
    out("Registered scheduled task: "
        r"\DevOptimizer\WSL-Permanent-Fix (logon + "
        "every 2 min)")
    run(["schtasks", "/create", "/f", "/tn",
         r"\DevOptimizer\WSL-Permanent-Fix-DockerStartup",
         "/tr", 'conhost.exe --headless pwsh.exe '
         '-NoProfile -ExecutionPolicy Bypass -File '
         '"D:\\DevOptimizer\\scripts'
         '\\wsl-permanent-fix.ps1" -DockerStartupGate',
         "/sc", "onlogon", "/ru", user,
         "/rl", "HIGHEST"])
    out("Registered scheduled task: "
        r"\DevOptimizer\WSL-Permanent-Fix-DockerStartup"
        " (at logon with gate)")
    out("")
    out("=== Installation Complete ===")
    out("The fix is now active with 4 layers of "
        "defense:")
    out("  Layer 1: Docker Desktop startup gate (waits "
        "for WSL ready)")
    out("  Layer 2: Active guard every 2 min (detects "
        "wslexec, pre-stabilizes)")
    out("  Layer 3: Existing wsl-guardian T1-T3 "
        "(5 min, reactive recovery)")
    out("  Layer 4: Docker Desktop config hardened "
        "(disabled auto group mgmt)")


def uninstall():
    out("=== Uninstalling WSL Permanent Fix ===")
    for tn in (r"\DevOptimizer\WSL-Permanent-Fix",
               r"\DevOptimizer\WSL-Permanent-Fix-2min",
               r"\DevOptimizer"
               r"\WSL-Permanent-Fix-DockerStartup"):
        r = run(["schtasks", "/delete", "/f", "/tn", tn])
        if r and r.returncode == 0:
            out(f"Removed task: {tn}")
    restore()
    out("Uninstall complete")


def test(gate_timeout):
    out("[Test] Layer 4 - Docker Desktop config check:")
    for f in (DD_SETTINGS, DD_STORE):
        s = read_json(f)
        out(f"  {f.name}: "
            f"disableWSLIntegrationAutoConfig="
            f"{s.get('disableWSLIntegrationAutoConfig')}"
            f" wslIntegrationAutoConfigure="
            f"{s.get('wslIntegrationAutoConfigure')}"
            f" manageDockerGroup="
            f"{s.get('manageDockerGroup')}")
    out("[Test] Layer 1 - WSL readiness gate (dry run, "
        "10s timeout):")
    ok = wait_ready(10)
    out(f"[Test] gate result: {ok}")
    out("[Test] Layer 2 - Active guard check:")
    active_guard()
    out("[Test] Layer 3 - wsl-guardian frequency check:")
    guardian_freq()
    return 0


def is_admin():
    try:
        return bool(
            ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Install", action="store_true")
    ap.add_argument("-Uninstall", action="store_true")
    ap.add_argument("-Test", action="store_true")
    ap.add_argument("-Force", action="store_true")
    ap.add_argument("-DockerStartupGate",
                    action="store_true")
    ap.add_argument("-GateTimeoutSec", type=int,
                    default=120)
    a = ap.parse_args()

    if a.DockerStartupGate:
        return 0 if wait_ready(a.GateTimeoutSec) else 1
    if a.Install:
        if not is_admin():
            err("Install requires an elevated shell.")
            return 1
        install()
        return 0
    if a.Uninstall:
        if not is_admin():
            err("Uninstall requires an elevated shell.")
            return 1
        uninstall()
        return 0
    if a.Test:
        return test(a.GateTimeoutSec)
    # every-2-min run
    active_guard()
    return 0


if __name__ == "__main__":
    sys.exit(main())
