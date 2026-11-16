"""Port of scripts/sync-docker-wsl.ps1.

Docker-WSL integration watchdog: checks engine reachability
(3-strike DD restart), WSL integration probe, restarts exited
always/unless-stopped containers (skipping stack-ops-managed,
retrying bind-mount exit-127 through the bridge window), and
repairs dead published port proxies (restart -> in-distro
compose force-recreate). Event 1004 + alerts via Notify.ps1.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

LOG = Path("D:/DevOptimizer/logs/docker-wsl-sync.log")
STRIKES = Path("D:/DevOptimizer/logs/docker-down-strikes.txt")
NOTIFY = (Path(__file__).resolve().parents[1]
          / "lib" / "Notify.ps1")


def log(msg):
    try:
        LOG.parent.mkdir(exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}\n")
    except OSError:
        pass


def alert(sev, title, msg, eid=1004, force=False):
    if not NOTIFY.exists():
        return
    env = dict(os.environ, DEVOPT_ALERT_TITLE=title,
               DEVOPT_ALERT_MSG=msg)
    subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         f'. "{NOTIFY}"; Send-DevOptAlert -Severity {sev} '
         '-Title $env:DEVOPT_ALERT_TITLE '
         '-Message $env:DEVOPT_ALERT_MSG '
         "-Tags 'docker','wsl','sync' "
         f"-EventId {eid}" + (" -Force" if force else "")],
        capture_output=True, env=env)


def note(msg):
    log(f"EVENT: {msg}")
    alert("Warning", "Docker-WSL Sync Event", msg)


def run(cmd, timeout=60):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=timeout)
    except Exception:
        return None


def docker(*args):
    r = run(["docker"] + list(args))
    return (r.stdout if r else "").replace("\r", "")


def proc_alive(name):
    r = run(["tasklist", "/FI", f"IMAGENAME eq {name}"])
    return bool(r and name in r.stdout)


def probe(port, path, timeout, from_windows=True,
          distro="Ubuntu-24.04"):
    if from_windows:
        cmd = ["curl.exe", "-s", "-o", "NUL", "-w",
               "%{http_code}", "-m", str(timeout),
               f"http://localhost:{port}{path}"]
    else:
        cmd = ["wsl.exe", "-d", distro, "--", "curl", "-s",
               "-o", "/dev/null", "-w", "%{http_code}",
               "-m", str(timeout),
               f"http://127.0.0.1:{port}{path}"]
    r = run(cmd, timeout=timeout + 15)
    return (r.stdout if r else "").strip()


def ok(code):
    return code.startswith(("2", "3"))


def force_recreate(distro, proj, svc, wdir, port, path,
                   timeout, retries=2):
    for attempt in range(1, retries + 1):
        run(["wsl", "-d", "Ubuntu-24.04", "--", "docker",
             "compose", "--project-directory", wdir, "-p",
             proj, "up", "-d", "--no-deps",
             "--force-recreate", svc], timeout=300)
        time.sleep(45)
        if ok(probe(port, path, timeout * 2)):
            return True
        if attempt < retries:
            time.sleep(30)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-ProbePorts", default="9390|/metrics")
    ap.add_argument("-BridgeWaitSeconds", type=int,
                    default=150)
    ap.add_argument("-ProbeTimeoutSec", type=int, default=8)
    ap.add_argument("-Distro", default="Ubuntu-24.04")
    a = ap.parse_args()

    actions = 0

    # [1] gates
    if not proc_alive("vmmemWSL"):
        log("WSL VM not running (skipped - no wake)")
        return 0
    r = run(["docker", "info"])
    if not r or r.returncode != 0:
        if not proc_alive("com.docker.backend"):
            log("docker engine unreachable AND "
                "com.docker.backend absent - relaunching "
                "Docker Desktop")
            run(['powershell', '-Command',
                 'Start-Process "$env:ProgramFiles\\Docker'
                 '\\Docker\\Docker Desktop.exe"'])
            return 0
        strikes = 0
        try:
            strikes = int(STRIKES.read_text()
                          .splitlines()[0])
        except Exception:
            pass
        strikes += 1
        try:
            STRIKES.parent.mkdir(exist_ok=True)
            STRIKES.write_text(str(strikes))
        except OSError:
            pass
        if strikes >= 3:
            log(f"docker engine unreachable {strikes} runs "
                "in a row with backend alive - restarting "
                "Docker Desktop")
            run(["powershell", "-Command",
                 "Stop-Process -Name 'com.docker.backend',"
                 "'Docker Desktop' -Force -ErrorAction "
                 "SilentlyContinue"])
            run(['powershell', '-Command',
                 'Start-Process "$env:ProgramFiles\\Docker'
                 '\\Docker\\Docker Desktop.exe"'])
            try:
                STRIKES.unlink(missing_ok=True)
            except OSError:
                pass
            return 0
        log(f"docker engine not reachable (Docker Desktop "
            f"still starting - strike {strikes}/3, skipped)")
        return 0
    try:
        STRIKES.unlink(missing_ok=True)
    except OSError:
        pass

    # [2] WSL integration probe
    r = run(["wsl.exe", "-d", a.Distro, "-e", "docker",
             "version", "--format", "{{.Server.Version}}"])
    server_ver = (r.stdout if r else "").strip()
    if server_ver:
        log(f"integration OK: {a.Distro} docker CLI reaches "
            f"engine {server_ver}")
    else:
        log(f"WARN: docker CLI inside {a.Distro} cannot "
            "reach engine - WSL integration broken (remedy: "
            "restart Docker Desktop)")
        note(f"WSL integration broken for {a.Distro} "
             "(docker CLI cannot reach engine)")

    # [3] stack-ops managed set
    managed = set()
    try:
        with urllib.request.urlopen(
                "http://127.0.0.1:8787/status",
                timeout=5) as resp:
            data = json.loads(resp.read().decode())
        for k, v in data.items():
            managed.add(k)
            if isinstance(v, dict) and v.get("container"):
                managed.add(v["container"])
    except Exception:
        pass

    # [4] restart exited always/unless-stopped
    exited = [n for n in docker(
        "ps", "-a", "--filter", "status=exited",
        "--format", "{{.Names}}").splitlines() if n]
    cands = []
    for name in exited:
        if name in managed:
            continue
        pol = docker("inspect", "-f",
                     "{{.HostConfig.RestartPolicy.Name}}",
                     name).strip()
        if pol in ("always", "unless-stopped"):
            cands.append(name)
    if cands:
        note(f"starting exited containers: "
             f"{', '.join(cands)}")
        deadline = time.time() + a.BridgeWaitSeconds
        pending = cands
        while pending and time.time() < deadline:
            still = []
            for name in pending:
                r = run(["docker", "start", name])
                if r and r.returncode == 0:
                    actions += 1
                else:
                    err = docker("inspect", "-f",
                                 "{{.State.Error}}",
                                 name).strip()
                    if "bind-mounts" in err:
                        still.append(name)
                    else:
                        note(f"container {name} failed to "
                             f"start: {err}")
            if still:
                time.sleep(15)
            pending = still

    # [5] port-proxy probes
    for pair in a.ProbePorts.split(","):
        parts = pair.strip().split("|", 1)
        if len(parts) < 2:
            continue
        port, path = parts[0].strip(), parts[1].strip()
        if not path.startswith("/"):
            path = "/" + path
        t = a.ProbeTimeoutSec
        cw = probe(port, path, t)
        cx = probe(port, path, t, False, a.Distro)
        if ok(cw) and ok(cx):
            continue
        time.sleep(20)
        cw = probe(port, path, t)
        cx = probe(port, path, t, False, a.Distro)
        if ok(cw) and ok(cx):
            continue
        publisher = None
        for line in docker(
                "ps", "--format",
                "{{.Names}}|{{.Ports}}").splitlines():
            if f":{port}->" in line:
                publisher = line.split("|")[0]
                break
        if not publisher:
            log(f"port-proxy DEAD: {port}{path} -> "
                f"Windows:{cw} WSL:{cx}, no running "
                f"container publishes {port}")
            note(f"port {port} dead (Windows:{cw} WSL:{cx}) "
                 "and no running publisher found")
            alert("Critical",
                  "Docker Port Proxy Dead - No Publisher",
                  f"Port {port} proxy dead (Windows:{cw} "
                  f"WSL:{cx}) and no running container "
                  f"publishes {port}", force=True)
            continue
        log(f"port-proxy DEAD for {port} (Windows:{cw} "
            f"WSL:{cx}) - restarting publisher {publisher}")
        alert("Warning",
              "Docker Port Proxy Dead - Restarting "
              "Publisher",
              f"Port {port} proxy dead (Windows:{cw} "
              f"WSL:{cx}) - restarting publisher "
              f"{publisher}")
        run(["docker", "restart", publisher], timeout=120)
        actions += 1
        time.sleep(30)
        cw = probe(port, path, t)
        cx = probe(port, path, t, False, a.Distro)
        if ok(cw) and ok(cx):
            log(f"  recovered: {port}{path} -> "
                f"Windows:{cw} WSL:{cx} after restarting "
                f"{publisher}")
            continue
        try:
            labels = json.loads(
                docker("inspect", "--format",
                       "{{json .Config.Labels}}",
                       publisher) or "{}")
        except Exception:
            labels = {}
        proj = labels.get("com.docker.compose.project")
        svc = labels.get("com.docker.compose.service")
        wdir = labels.get(
            "com.docker.compose.project.working_dir")
        if proj and svc and wdir:
            log("  restart insufficient - force-recreating "
                f"compose service {proj}/{svc} "
                f"(workdir {wdir})")
            alert("Warning",
                  "Docker Port Proxy Force-Recreate",
                  f"Port {port} proxy dead - "
                  f"force-recreating compose service "
                  f"{proj}/{svc}")
            if force_recreate(a.Distro, proj, svc, wdir,
                              port, path, t):
                actions += 1
            else:
                log(f"  STILL BROKEN: {port}{path} -> "
                    f"Windows:{cw} WSL:{cx} after restart +"
                    " force-recreate of "
                    f"{publisher} - needs manual check")
                note(f"port {port} still broken after "
                     "restart and force-recreate of "
                     f"{publisher}")
                alert("Critical",
                      "Docker Port Proxy STILL BROKEN "
                      "After Force-Recreate",
                      f"Port {port} proxy still dead "
                      f"after restart + force-recreate of "
                      f"{publisher} ({proj}/{svc}). Manual "
                      "intervention required.",
                      force=True)
        else:
            log(f"  STILL BROKEN: {port}{path} -> "
                f"Windows:{cw} WSL:{cx} after restarting "
                f"{publisher} (no compose labels - cannot "
                "force-recreate) - needs manual check")
            note(f"port {port} still broken after "
                 f"restarting {publisher} (no compose "
                 "labels)")
            alert("Critical",
                  "Docker Port Proxy STILL BROKEN "
                  "(No Compose Labels)",
                  f"Port {port} proxy still dead after "
                  f"restarting {publisher}. Cannot "
                  "force-recreate (no compose labels). "
                  "Manual intervention required.",
                  force=True)

    up = len([l for l in docker("ps", "-q").splitlines()
              if l])
    df = docker("system", "df", "--format",
                "{{.Type}} {{.TotalCount}} {{.Size}} "
                "{{.Reclaimable}}")
    log(f"sync complete: {up} container(s) up, {actions} "
        "repair action(s) taken")
    log(f"docker system df: "
        f"{'; '.join(df.splitlines()) or 'unavailable'}")
    if managed:
        log(f"stack-ops excluded {len(managed)} managed "
            "container(s) from recovery")
    return 0


if __name__ == "__main__":
    sys.exit(main())
