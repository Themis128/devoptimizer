"""WSL2 Ubuntu self-healing ladder (port of scripts/wsl-guardian.ps1
v2.1). Runs every 5 min via conhost --headless scheduled task.

Recovery ladder (each tier guarded by .deploy.lock + cooldowns):
  T1 container - distro alive but stack dead: docker restart the
                 unhealthy container(s) inside the distro.
  T2 distro    - T2After sustained deep fails: `wsl --terminate
                 <distro>` + prewarm (docker-desktop stays).
  T3 vm        - post-terminate still dead: `wsl --shutdown` +
                 prewarm + verify.
State/log under %ProgramData%\\wsl-guardian\\; optional ntfy alerts
(--ntfy-topic). --dry-run.
"""

import argparse
import datetime
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

# CATEGORY: maintenance
# TAGS: wsl2, self-healing, watchdog, docker, ntfy

STATE_DIR = Path(os.environ.get("ProgramData", r"C:\ProgramData")) \
    / "wsl-guardian"
LOG_FILE = STATE_DIR / "guardian.log"
STATE_FILE = STATE_DIR / "state.json"


def log(msg, level="INFO"):
    line = (f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} "
            f"[{level}] {msg}")
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        if LOG_FILE.exists() and LOG_FILE.stat().st_size > 1 << 20:
            tail = LOG_FILE.read_text(errors="replace").splitlines()
            LOG_FILE.write_text("\n".join(tail[-1000:]) + "\n")
        with open(LOG_FILE, "a") as fh:
            fh.write(line + "\n")
    except OSError:
        pass
    if level != "INFO":
        print(line)


def notify(topic, title, body):
    log(f"ALERT: {title} -- {body}", "WARN")
    if not topic:
        return
    headers = {"Title": title, "Priority": "high"}
    tf = Path(os.environ.get("APPDATA", "")) / "devin" / "secrets" \
        / "ntfy-devoptimizer-token"
    try:
        if tf.is_file():
            headers["Authorization"] = \
                "Bearer " + tf.read_text().strip()
        req = urllib.request.Request(
            f"https://ntfy.cloudless.gr/{topic}", data=body.encode(),
            headers=headers, method="POST")
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        log(f"ntfy fail: {e}", "WARN")


DEFAULT_STATE = {"deepFails": 0, "postT2Fails": 0, "lastT1": "",
                 "lastT2": "", "lastT3": "", "t2Pending": False,
                 "tick": 0}


def get_state():
    if STATE_FILE.is_file():
        try:
            st = json.loads(STATE_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            st = {}
        merged = dict(DEFAULT_STATE, **st)
        merged.pop("lastTerminate", None)
        return merged
    return dict(DEFAULT_STATE)


def set_state(st):
    STATE_FILE.write_text(json.dumps(st))


def cooled(iso, minutes):
    if not iso:
        return False
    try:
        d = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
        if d.tzinfo:
            d = d.replace(tzinfo=None)
        return (datetime.datetime.now() - d).total_seconds() \
            / 60 < minutes
    except (ValueError, TypeError):
        return False


def wsl_run(args, distro, timeout, outfile=None):
    cmd = ["wsl.exe", "-d", distro, "-e"] + args
    try:
        if outfile:
            with open(outfile, "w") as out, \
                    open(outfile + ".err", "w") as err:
                r = subprocess.run(cmd, timeout=timeout, stdout=out,
                                   stderr=err)
            return Path(outfile).read_text(
                errors="replace").strip()
        r = subprocess.run(cmd, timeout=timeout,
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
        return r.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return None


def wsl_admin(args, timeout):
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        with open(STATE_DIR / "admin.txt", "w") as out, \
                open(STATE_DIR / "admin.err", "w") as err:
            r = subprocess.run(["wsl.exe"] + args, timeout=timeout,
                               stdout=out, stderr=err)
        return r.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False


def test_deploy_lock(args):
    out = wsl_run(
        ["bash", "-c",
         f"if [ -f {args.deploy_lock} ]; then "
         f"a=$(( $(date +%s) - $(stat -c %Y {args.deploy_lock}) )); "
         f"[ $a -lt {args.deploy_lock_max_age_sec} ] && "
         "echo FRESH || echo stale; else echo none; fi"],
        args.distro, 15, str(STATE_DIR / "lock.txt"))
    return out == "FRESH"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--distro", default="Ubuntu-24.04")
    ap.add_argument("--probe-timeout-sec", type=int, default=20)
    ap.add_argument("--deep-check-every", type=int, default=3)
    ap.add_argument("--t1-after", type=int, default=2)
    ap.add_argument("--t2-after", type=int, default=4)
    ap.add_argument("--t3-after", type=int, default=6)
    ap.add_argument("--t1-cooldown-min", type=int, default=15)
    ap.add_argument("--t2-cooldown-min", type=int, default=60)
    ap.add_argument("--t3-cooldown-min", type=int, default=240)
    ap.add_argument("--deep-health-cmd",
                    default='curl -sf -m30 -o /dev/null -w '
                            '"%{http_code}" '
                            'http://localhost:8083/health')
    ap.add_argument("--deep-check-timeout-sec", type=int, default=45)
    ap.add_argument("--t1-repair-cmd",
                    default="docker restart social-api")
    ap.add_argument("--verify-cmd",
                    default='curl -sf -m30 -o /dev/null -w '
                            '"%{http_code}" '
                            'http://localhost:8083/health')
    ap.add_argument("--deploy-lock",
                    default="/home/tbaltzakis/cu130-slim/"
                            ".deploy.lock")
    ap.add_argument("--deploy-lock-max-age-sec", type=int,
                    default=3600)
    ap.add_argument("--ntfy-topic", default="devoptimizer-alerts")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    st = get_state()
    st["tick"] = int(st["tick"]) + 1

    probe = wsl_run(["true"], args.distro, args.probe_timeout_sec)
    deep_fail = False
    if probe is not True:
        st["deepFails"] = int(st["deepFails"]) + 1
        if st["t2Pending"]:
            st["postT2Fails"] = int(st["postT2Fails"]) + 1
        log("probe FAIL "
            f"consecutive={st['deepFails']} "
            f"postT2={st['postT2Fails']}", "WARN")
        deep_fail = True
    elif st["tick"] % args.deep_check_every == 0:
        code = wsl_run(["bash", "-c", args.deep_health_cmd],
                       args.distro, args.deep_check_timeout_sec,
                       str(STATE_DIR / "deep.txt"))
        try:
            code = int(str(code).strip())
        except ValueError:
            code = 0
        if not (200 <= code < 400):
            st["deepFails"] = int(st["deepFails"]) + 1
            if st["t2Pending"]:
                st["postT2Fails"] = int(st["postT2Fails"]) + 1
            deep_fail = True
            log(f"deep FAIL http={code} "
                f"consecutive={st['deepFails']} "
                f"postT2={st['postT2Fails']}", "WARN")
        else:
            st["deepFails"] = 0
            st["postT2Fails"] = 0
            st["t2Pending"] = False
            log(f"deep OK http={code} - recovery counters reset")
    else:
        log(f"probe OK tick={st['tick']} "
            f"deepFails={st['deepFails']} "
            f"postT2={st['postT2Fails']}")

    df = int(st["deepFails"])
    if deep_fail and df >= args.t1_after:
        locked = test_deploy_lock(args)
        if (df >= args.t1_after and df < args.t2_after
                and probe is True and not locked
                and not cooled(st["lastT1"], args.t1_cooldown_min)):
            log(f"T1 ACTION: in-distro repair {args.t1_repair_cmd} "
                f"(fail #{df})", "WARN")
            if not args.dry_run:
                wsl_run(["bash", "-c", args.t1_repair_cmd],
                        args.distro, 90)
                st["lastT1"] = datetime.datetime.now().isoformat()
        elif df < args.t2_after and probe is not True:
            log(f"distro unreachable at fail #{df} - T1 skipped "
                f"(needs reachable distro); T2 arms at fail "
                f"#{args.t2_after}", "WARN")
        elif (df >= args.t2_after and not st["t2Pending"]
              and not locked
              and not cooled(st["lastT2"], args.t2_cooldown_min)):
            log(f"T2 ACTION: wsl --terminate {args.distro} "
                f"(fail #{df})", "WARN")
            if not args.dry_run:
                notify(args.ntfy_topic,
                       "wsl-guardian T2: terminating distro",
                       f"{args.distro} terminated after {df} "
                       "sustained failures. Containers recover via "
                       "restart policies.")
                wsl_admin(["--terminate", args.distro], 60)
                import time
                time.sleep(15)
                wsl_run(["true"], args.distro, 30)
                st["lastT2"] = datetime.datetime.now().isoformat()
                st["deepFails"], st["postT2Fails"] = 0, 0
                st["t2Pending"] = True
        elif (st["t2Pending"]
              and int(st["postT2Fails"]) >= args.t3_after
              and not locked
              and not cooled(st["lastT3"], args.t3_cooldown_min)):
            log(f"T3 ACTION: wsl --shutdown (postT2 "
                f"#{st['postT2Fails']}, post-T2 unrecovered)", "WARN")
            if not args.dry_run:
                notify(args.ntfy_topic, "wsl-guardian T3: VM bounce",
                       f"wsl --shutdown after {st['postT2Fails']} "
                       "post-terminate failures (T2 did not recover). "
                       "Applies pending .wslconfig changes; containers "
                       "recover via policies.")
                wsl_admin(["--shutdown"], 120)
                import time
                time.sleep(15)
                wsl_run(["true"], args.distro, 30)
                time.sleep(30)
                v = wsl_run(["bash", "-c", args.verify_cmd],
                            args.distro, 60,
                            str(STATE_DIR / "verify.txt"))
                log(f"T3 verify: http={v}")
                st["lastT3"] = datetime.datetime.now().isoformat()
                st["deepFails"], st["postT2Fails"] = 0, 0
                st["t2Pending"] = False
        elif locked:
            log(f"action suppressed: FRESH .deploy.lock "
                f"(fail #{df})", "WARN")
        else:
            log(f"action suppressed by cooldown (fail #{df})")

    set_state(st)


if __name__ == "__main__":
    main()
