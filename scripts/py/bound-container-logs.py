"""Port of scripts/bound-container-logs.ps1.

Binds json-file logs on existing containers by force-recreating
their compose projects. Report-only unless -Apply. Defers while
Devin.exe or devin-server is alive (recreate bounces the stack).
Exit 2 deferred / 0 ok / 1 failures.
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

LOG = Path("D:/DevOptimizer/logs/bound-container-logs.log")


def log(msg):
    LOG.parent.mkdir(exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}\n")


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=600)
    except Exception:
        return None


def docker(*args):
    r = run(["docker"] + list(args))
    return (r.stdout if r else "") or ""


def wsl(distro, sh):
    r = run(["wsl.exe", "-d", distro, "-e", "sh", "-lc", sh])
    return (r.stdout if r else "") or "", (r.returncode if r
                                           else 1)


def all_names():
    return [n.strip() for n in
            docker("ps", "-a", "--format", "{{.Names}}")
            .splitlines() if n.strip()]


def inspect(c, fmt):
    return docker("inspect", c, "--format", fmt).strip()


def unbounded(c):
    return "max-size" not in inspect(
        c, "{{.HostConfig.LogConfig.Config}}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Apply", action="store_true")
    ap.add_argument("-Force", action="store_true")
    ap.add_argument("-Distro", default="Ubuntu-24.04")
    a = ap.parse_args()

    log(f"--- bound-container-logs run started "
        f"(Apply={a.Apply}) ---")

    # [1] gates
    if "Devin" in subprocess.run(
            ["tasklist"], capture_output=True,
            text=True).stdout:
        log("Devin.exe running - DEFERRED (exit 2)")
        return 2
    out, _ = wsl(a.Distro,
                 'pgrep -fc "out/server-main.js" 2>/dev/null')
    if out.strip() and out.strip() != "0":
        if a.Force:
            log("devin-server alive but -Force given and "
                "Devin.exe closed - proceeding")
        else:
            log("devin-server alive in distro - DEFERRED "
                "(exit 2; use -Force only when Devin.exe is "
                "closed)")
            return 2
    r = run(["docker", "info"])
    if not r or r.returncode != 0:
        log("docker engine not reachable (skipped)")
        return 0

    # [2] snapshot restart=no trims
    restart_no = [c for c in all_names()
                  if inspect(c, "{{.HostConfig.RestartPolicy"
                                 ".Name}}") == "no"]
    log(f"restart=no snapshot ({len(restart_no)}): "
        f"{', '.join(restart_no)}")

    # [3] unbounded containers + compose projects
    names = all_names()
    unb = [c for c in names if unbounded(c)]
    log(f"unbounded containers: {len(unb)} of {len(names)}")
    projects = {}
    for c in unb:
        try:
            labels = json.loads(inspect(
                c, "{{json .Config.Labels}}") or "{}")
        except Exception:
            labels = {}
        proj = labels.get("com.docker.compose.project")
        wdir = labels.get(
            "com.docker.compose.project.working_dir")
        if proj and wdir:
            projects[proj] = wdir
        else:
            log(f"non-compose container (manual-only): {c}")
    for k, v in projects.items():
        log(f"project {k} -> {v}")
    if not a.Apply:
        log("report-only (no -Apply). Review the plan above, "
            "then re-run with -Apply.")
        return 0

    # [4] recreate per project (inside the distro)
    failed = 0
    for k, wdir in projects.items():
        log(f"recreating project {k}...")
        out, rc = wsl(a.Distro,
                      f"cd '{wdir}' && docker compose up -d "
                      f"--force-recreate 2>&1 | tail -3")
        for line in out.splitlines():
            log(f"  {line}")
        if rc != 0:
            failed += 1
            log(f"project {k} recreate FAILED (exit {rc})")

    # [5] re-apply restart=no trims
    for c in restart_no:
        if inspect(c, "{{.HostConfig.RestartPolicy.Name}}") \
                != "no":
            run(["docker", "update", "--restart=no", c])
            run(["docker", "stop", c])
            log(f"re-applied restart=no + stopped: {c}")

    # [6] verify
    still = sum(1 for c in all_names() if unbounded(c))
    unhealthy = len([l for l in docker(
        "ps", "--filter", "health=unhealthy", "--format",
        "{{.Names}}").splitlines() if l.strip()])
    probe = run(["curl.exe", "-s", "-o", "NUL", "-w",
                 "%{http_code}", "-m", "8",
                 "http://localhost:9390/metrics"])
    log(f"verify: still-unbounded={still} "
        f"unhealthy={unhealthy} "
        f"9390/metrics={probe.stdout if probe else '?'} "
        f"failed-projects={failed}")
    log("--- run complete ---")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
