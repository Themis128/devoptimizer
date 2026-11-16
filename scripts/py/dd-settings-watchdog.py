"""Port of scripts/dd-settings-watchdog.ps1.

Docker Desktop settings persistence watchdog. Detects drift in
settings-store.json (DD >= 4.35; settings.json legacy fallback),
auto-restores IntegratedWslDistros += Ubuntu-24.04 and
EnableIntegrationWithDefaultWslDistro=true, then restarts DD at
most once per 6h. DD >= 4.98 'store-v2' minimal schema has no
integration keys - drift-free by design.
"""

import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

APPDATA = os.environ.get("APPDATA", "")
LOCALAPPDATA = os.environ.get("LOCALAPPDATA", "")
STORE = Path(APPDATA) / "Docker" / "settings-store.json"
LEGACY = Path(APPDATA) / "Docker" / "settings.json"
ACTIVE = STORE if STORE.exists() else LEGACY

HOME = Path(os.environ.get("DEVOPT_HOME", "D:\\DevOptimizer"))
STATE_FILE = HOME / "logs" / "dd-settings-watchdog-state.json"
LOG_FILE = HOME / "logs" / "dd-settings-watchdog.log"
REWRAP = HOME / "scripts" / "_rewrap-headless-all.ps1"
RESTART_COOLDOWN_HOURS = 6
DISTRO = "Ubuntu-24.04"


def log(msg, level="INFO"):
    try:
        LOG_FILE.parent.mkdir(exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} "
                    f"[{level}] {msg}\n")
    except OSError:
        pass


def alert(sev, title, msg, eid):
    notify = Path(__file__).resolve().parents[1] / "lib" \
        / "Notify.ps1"
    if notify.exists():
        subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             f'. "{notify}"; Send-DevOptAlert -Severity {sev} '
             f'-Title "{title}" -Message "{msg}" '
             f"-EventId {eid}"], capture_output=True)


def current_state():
    st = {"schema": "none", "distros": [], "defaultWsl": None,
          "defaultWslKey": False, "distrosKey": False}
    if not ACTIVE.exists():
        return st
    try:
        js = json.loads(ACTIVE.read_text(
            encoding="utf-8-sig"))
    except Exception as e:
        log(f"Failed to parse {ACTIVE}: {e}", "WARN")
        return st
    if ACTIVE == STORE:
        st["defaultWslKey"] = \
            "EnableIntegrationWithDefaultWslDistro" in js
        st["distrosKey"] = "IntegratedWslDistros" in js
        if not st["defaultWslKey"] and not st["distrosKey"]:
            # DD >= 4.98 minimal schema: defaults govern.
            st["schema"] = "store-v2"
        else:
            st["schema"] = "store"
            if st["defaultWslKey"]:
                st["defaultWsl"] = js.get(
                    "EnableIntegrationWithDefaultWslDistro")
            if st["distrosKey"]:
                st["distros"] = list(
                    js.get("IntegratedWslDistros") or [])
    else:
        st["schema"] = "legacy"
    return st


def drift(cur):
    d = []
    if cur["schema"] == "none":
        d.append(f"settings file missing: {ACTIVE}")
        return d
    if cur["schema"] == "store":
        if cur["defaultWslKey"] and cur["defaultWsl"] is not True:
            d.append("EnableIntegrationWithDefaultWslDistro: "
                     f"current={cur['defaultWsl']} desired=True")
        if cur["distrosKey"] and DISTRO not in cur["distros"]:
            d.append(f"IntegratedWslDistros missing {DISTRO}: "
                     f"current=[{','.join(cur['distros'])}]")
    return d


def restore():
    """Re-add Ubuntu-24.04 in settings-store.json. True only
    when the file was actually rewritten."""
    if ACTIVE != STORE:
        log("Cannot auto-restore: no settings-store.json "
            "(legacy schema)", "WARN")
        return False
    try:
        js = json.loads(STORE.read_text(encoding="utf-8-sig"))
        changed = False
        if ("EnableIntegrationWithDefaultWslDistro" in js
                and js["EnableIntegrationWithDefaultWslDistro"]
                is not True):
            js["EnableIntegrationWithDefaultWslDistro"] = True
            changed = True
        if "IntegratedWslDistros" in js:
            distros = list(js.get("IntegratedWslDistros") or [])
            if DISTRO not in distros:
                distros.append(DISTRO)
                js["IntegratedWslDistros"] = distros
                changed = True
        if not changed:
            return False
        STORE.write_text(json.dumps(js, indent=2),
                         encoding="utf-8")
        log("Restored settings-store.json to desired state",
            "WARN")
        return True
    except Exception as e:
        log(f"Restore-Settings failed: {e}", "WARN")
        return False


def restart_dd(state):
    last = state.get("lastRestart")
    last_dt = datetime.min
    if last:
        try:
            last_dt = datetime.fromisoformat(
                str(last).replace("Z", "+00:00")) \
                .replace(tzinfo=None)
        except Exception:
            pass
    if datetime.now() - last_dt < timedelta(
            hours=RESTART_COOLDOWN_HOURS):
        log(f"Restart suppressed - last restart {last} within "
            f"{RESTART_COOLDOWN_HOURS}h cooldown", "WARN")
        return False
    dd = next((p for p in (
        Path(LOCALAPPDATA) / "Programs/DockerDesktop"
        / "Docker Desktop.exe",
        Path(r"C:\Program Files\Docker\Docker"
             r"\Docker Desktop.exe")) if p.exists()), None)
    if not dd:
        log("Docker Desktop.exe not found - restart skipped",
            "WARN")
        return False
    cli = next((p for p in (
        Path(r"C:\Program Files\Docker\Docker\DockerCli.exe"),
        Path(LOCALAPPDATA) / "Programs/DockerDesktop"
        / "DockerCli.exe") if p.exists()), None)
    if cli:
        subprocess.run([str(cli), "-Shutdown"],
                       capture_output=True)
    for p in ("Docker Desktop.exe", "com.docker.backend.exe"):
        subprocess.run(["taskkill", "/F", "/IM", p],
                       capture_output=True)
    time.sleep(5)
    subprocess.Popen([str(dd)])
    return True


def load_state():
    try:
        return json.loads(STATE_FILE.read_text(
            encoding="utf-8-sig"))
    except Exception:
        return {}


def save_state(s):
    try:
        STATE_FILE.parent.mkdir(exist_ok=True)
        STATE_FILE.write_text(json.dumps(s), encoding="utf-8")
    except OSError:
        pass


def main():
    # One-shot elevated rewrap of console-popup tasks (marker
    # inside the script prevents repeats).
    if REWRAP.exists():
        try:
            pwsh = shutil.which("pwsh") or "powershell"
            subprocess.run(
                [pwsh, "-NoProfile", "-File", str(REWRAP)],
                capture_output=True)
        except Exception:
            pass

    cur = current_state()
    d = drift(cur)
    state = load_state()
    now = datetime.now()
    state["lastCheck"] = now.isoformat()

    if d:
        state["driftCount"] = state.get("driftCount", 0) + 1
        state["lastDrift"] = now.isoformat()
        log(f"DRIFT DETECTED ({cur['schema']}): "
            f"{'; '.join(d)}", "WARN")
        ep_key = f"last_Warning-DDSettingsDrift-{cur['schema']}"
        last_alert = state.get(ep_key)
        last_dt = datetime.min
        if last_alert:
            try:
                last_dt = datetime.fromisoformat(
                    str(last_alert)) .replace(tzinfo=None)
            except Exception:
                pass
        if (not state.get("driftEpisode")
                or now - last_dt > timedelta(hours=24)):
            alert("Warning",
                  "Docker Desktop Settings Drift Detected",
                  f"Drift ({cur['schema']}): {'; '.join(d)}",
                  1010)
            state[ep_key] = now.isoformat()
            state["driftEpisode"] = True
        if restore():
            state["restoreCount"] = \
                state.get("restoreCount", 0) + 1
            state["lastRestore"] = now.isoformat()
            if restart_dd(state):
                state["lastRestart"] = now.isoformat()
                log("Docker Desktop restarted to apply "
                    "restored settings", "WARN")
                alert("Info",
                      "Docker Desktop Settings Auto-Restored",
                      "Applied fixes and restarted Docker "
                      "Desktop (cooldown "
                      f"{RESTART_COOLDOWN_HOURS}h).", 1011)
            else:
                alert("Warning",
                      "Docker Desktop Settings Restored - "
                      "Restart Pending",
                      "settings-store.json rewritten; restart "
                      "deferred by cooldown.", 1012)
    else:
        log(f"Settings OK ({cur['schema']}) - no drift "
            "detected")
        if state.get("driftEpisode"):
            state["driftEpisode"] = False
            alert("Info",
                  "Docker Desktop Settings Drift Resolved",
                  "settings-store.json back to desired state.",
                  1013)
    save_state(state)
    return 0


if __name__ == "__main__":
    sys.exit(main())
