"""WSL vsock watchdog (port of scripts/wsl-vsock-watchdog.ps1).

Probes the distro exec channel; after 5 consecutive failures and a
25-min cooldown, bounces the distro (wsl --shutdown + re-probe).
State in state/wsl-vsock-watchdog.state; log wsl-vsock-watchdog.log.
--once default; --threshold/--cooldown/--interval for the loop.
"""

import argparse
import datetime
import json
import os
import subprocess
import sys
import time
from pathlib import Path

# CATEGORY: maintenance
# TAGS: wsl, watchdog, vsock, watchdog-state

STATE = Path(r"D:\DevOptimizer\state\wsl-vsock-watchdog.state")
LOG = Path(r"D:\DevOptimizer\logs\wsl-vsock-watchdog.log")
DISTRO = "Ubuntu-24.04"
THRESHOLD = 5
COOLDOWN_MIN = 25
PROBE_TIMEOUT = 45


def log(msg: str):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a") as fh:
        fh.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {msg}\n")


def get_state():
    try:
        return json.loads(STATE.read_text())
    except Exception:
        return {"fails": 0, "lastBounce": None}


def save_state(st):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(st))


def distro_running(distro: str) -> bool:
    # wsl -l -v is a service-level query - it answers even when the VM
    # is wedged. A probe would boot a deliberately stopped distro, so
    # this must be checked first (never boot a VM somebody turned off).
    env = dict(os.environ, WSL_UTF8="1")
    try:
        r = subprocess.run(["wsl.exe", "-l", "-v"],
                           capture_output=True, text=True, timeout=30,
                           env=env)
        out = r.stdout or ""
    except Exception:
        return False
    return "Running" in out and distro in out


def probe(distro: str) -> bool:
    env = dict(os.environ, WSL_UTF8="1")
    try:
        r = subprocess.run(
            ["wsl.exe", "-d", distro, "-e", "bash", "-c",
             "echo ok"], capture_output=True, text=True,
            timeout=PROBE_TIMEOUT, env=env)
        return r.returncode == 0 and "ok" in (r.stdout or "")
    except Exception:
        return False


def bounce(distro: str):
    env = dict(os.environ, WSL_UTF8="1")
    subprocess.run(["wsl.exe", "--shutdown"], timeout=120, env=env)
    time.sleep(5)
    return probe(distro)


def pass_once(args) -> int:
    st = get_state()
    if not distro_running(args.distro):
        if st["fails"]:
            log("distro stopped - reset fails")
            save_state({"fails": 0, "lastBounce": st["lastBounce"]})
        return 0
    if probe(args.distro):
        if st["fails"]:
            log(f"recovered after {st['fails']} fails")
            save_state({"fails": 0, "lastBounce": st["lastBounce"]})
        return 0
    fails = st["fails"] + 1
    last = st["lastBounce"]
    cooled = (last is None or
              (datetime.datetime.now() -
               datetime.datetime.fromisoformat(last)).total_seconds()
              >= args.cooldown * 60)
    log(f"probe fail #{fails}")
    if fails >= args.threshold and cooled:
        log("threshold reached — bouncing distro")
        try:
            ok = bounce(args.distro)
        except Exception as e:
            ok = False
            log(f"bounce raised: {e}")
        if ok:
            last = datetime.datetime.now().isoformat()
            fails = 0
        log("bounce ok" if ok else "bounce FAILED")
        save_state({"fails": fails, "lastBounce": last})
    else:
        save_state({"fails": fails, "lastBounce": last})
    return 1


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--distro", default=DISTRO)
    p.add_argument("--threshold", type=int, default=THRESHOLD)
    p.add_argument("--cooldown", type=int, default=COOLDOWN_MIN)
    p.add_argument("--interval", type=int, default=60)
    p.add_argument("--loop", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    if args.loop:
        while True:
            pass_once(args)
            time.sleep(args.interval)
    rc = pass_once(args)
    if args.json:
        print(json.dumps({"ok": rc == 0, "state": get_state()}))
    sys.exit(rc)


if __name__ == "__main__":
    main()
