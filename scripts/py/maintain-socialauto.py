"""Port of scripts/socialauto/Maintain-SocialAuto.ps1 — zero-downtime
maintenance for the socialauto (cu130-slim) stack inside WSL
Ubuntu-24.04: safe prunes (exited containers minus protected
cu130-slim/model-runner labels, dangling images, build cache >7d),
unhealthy report/opt-in restart, DMR health, page-cache drop below
--min-host-free-gb. Exit 0 clean / 1 unreachable / 2 unhealthy remain.
"""
import json
import re
import subprocess
import sys
import time
from pathlib import Path

DISTRO = "Ubuntu-24.04"
LOG_DIR = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs")
_log_file = None


def wsl(cmd, as_root=False):
    args = ["wsl.exe", "-d", DISTRO]
    if as_root:
        args += ["-u", "root"]
    args += ["--", "bash", "-c", cmd]
    try:
        r = subprocess.run(args, capture_output=True, text=True)
    except FileNotFoundError:
        return []
    return [l for l in re.split(r"\r?\n",
                                r.stdout.replace("\x00", "")) if l]


def log(line):
    print(line)
    if _log_file:
        with open(_log_file, "a", encoding="utf-8") as fh:
            fh.write("[" + time.strftime("%H:%M:%S") + "] " + line
                     + "\n")


def stack_count(cmd):
    digits = [l for l in wsl(cmd) if re.match(r"^\s*\d+\s*$", l)]
    return int(digits[-1].strip()) if digits else -1


def main():
    global _log_file
    remediate = "--remediate" in sys.argv
    report_only = "--report-only" in sys.argv
    min_free = 2
    log_dir = str(LOG_DIR)
    for i, a in enumerate(sys.argv):
        if a == "--min-host-free-gb" and i + 1 < len(sys.argv):
            min_free = int(sys.argv[i + 1])
        if a == "--log-dir" and i + 1 < len(sys.argv):
            log_dir = sys.argv[i + 1]
    if log_dir and log_dir != "none":
        d = Path(log_dir)
        d.mkdir(parents=True, exist_ok=True)
        _log_file = d / ("socialauto-maintenance-"
                         + time.strftime("%Y%m%d") + ".log")

    log("=== SocialAuto Maintenance - zero-downtime pass - "
        + time.strftime("%Y-%m-%d %H:%M:%S") + " ===")
    if report_only:
        log("[MODE] report-only: no prunes, no cache drop")

    if not any(l == "ok" for l in wsl("echo ok")):
        log(f"[FAIL] WSL distro '{DISTRO}' unreachable - maintenance"
            " aborted (platform itself is untouched).")
        return 1
    engine_ok, server_ver = False, ""
    for i in range(48):
        out = wsl("docker version --format {{.Server.Version}}"
                  " 2>/dev/null || echo DOWN")
        ver = [l for l in out if re.match(r"^\s*\d+(\.\d+){1,3}\s*$",
                                          l)]
        if ver:
            engine_ok, server_ver = True, ver[0].strip()
            break
        if i == 0:
            log("[WAIT] docker engine/CLI not answering yet -"
                " waiting up to 8 minutes ...")
        time.sleep(10)
    if not engine_ok:
        log("[FAIL] Docker engine/CLI not responsive inside WSL"
            " after 8 minutes - maintenance aborted.")
        return 1
    log(f"[ OK ] WSL + docker engine responsive (server"
        f" {server_ver})")

    before = {"running": stack_count("docker ps -q | wc -l"),
              "unhealthy": stack_count(
                  "docker ps --filter health=unhealthy -q | wc -l"),
              "exited": stack_count(
                  "docker ps -a --filter status=exited -q | wc -l")}
    if min(before.values()) < 0:
        log("[FAIL] could not read stack counts (docker CLI missing"
            " inside distro?) - aborting.")
        return 1
    log(f"[ OK ] stack before: {before['running']} running /"
        f" {before['unhealthy']} unhealthy /"
        f" {before['exited']} exited")

    if report_only:
        d = wsl("docker images -f dangling=true -q | wc -l")
        log(f"[ DRY ] would prune: {d[0].strip() if d else '?'} "
            "dangling image(s), exited containers, build cache"
            " older than 7 days")
    else:
        exited_ids = [l for l in wsl(
            "docker ps -a --filter status=exited -q")
            if re.match(r"^[0-9a-f]+$", l)]
        protected = set(
            wsl('docker ps -a --filter status=exited --filter'
                ' "label=com.docker.compose.project=cu130-slim" -q')
            + wsl('docker ps -a --filter status=exited --filter'
                  ' "label=com.docker.desktop.service=model-runner"'
                  " -q"))
        prunable = sum(1 for i in exited_ids if i not in protected)
        if prunable > 0:
            wsl('docker container prune -f --filter'
                ' "label!=com.docker.compose.project=cu130-slim"'
                ' --filter'
                ' "label!=com.docker.desktop.service=model-runner"')
            log(f"[ OK ] pruned exited containers: {prunable}"
                f" removed ({len(protected)} protected - stack-ops"
                " sleeping/compose + DMR runner)")
        else:
            log("[ OK ] no exited containers to prune")
        d = wsl("docker images -f dangling=true -q | wc -l")
        dangling = int(d[0].strip()) if d else 0
        if dangling > 0:
            wsl("docker image prune -f")
            d2 = wsl("docker images -f dangling=true -q | wc -l")
            after = int(d2[0].strip()) if d2 else 0
            log(f"[ OK ] pruned dangling images:"
                f" {dangling - after} removed")
        else:
            log("[ OK ] no dangling images")
        bc = [l for l in wsl(
            "docker builder prune -f --filter until=168h")
            if "reclaimed" in l]
        if bc:
            log(f"[ OK ] build cache pruned (kept last 7 days):"
                f" {bc[0].strip()}")
        else:
            log("[ OK ] build cache prune: nothing reclaimed")

    unhealthy = [l for l in wsl(
        "docker ps --filter health=unhealthy --format"
        " '{{.Names}}|{{.Status}}'")
        if re.match(r"^[A-Za-z0-9][A-Za-z0-9_.\-]+\|", l)]
    if unhealthy:
        for u in unhealthy:
            name = u.split("|")[0]
            if remediate and not report_only:
                log(f"[FIX ] unhealthy: {name} - restarting (it is"
                    " already failing) ...")
                wsl(f"docker restart {name}")
                time.sleep(5)
                st = wsl(f"docker inspect {name} --format"
                         " '{{.State.Health.Status}}' 2>/dev/null"
                         " || echo restarted")
                log(f"[FIX ] {name} now:"
                    f" {st[0].strip() if st else 'restarted'}")
            else:
                log(f"[WARN] unhealthy container: {u} - rerun with"
                    " --remediate to restart it")
    else:
        log("[ OK ] no unhealthy containers")

    dmr = wsl("curl -s -m 5 -o /dev/null -w '%{http_code}'"
              " http://localhost:12435/engines/v1/models"
              " 2>/dev/null || echo 000")
    code = dmr[0].strip() if dmr else "000"
    if code == "200":
        loaded = wsl("curl -s -m 5 http://localhost:12435/api/ps"
                     " 2>/dev/null")
        try:
            n = len(json.loads(loaded[0]).get("models", [])) \
                if loaded else "?"
        except (ValueError, IndexError):
            n = "?"
        log(f"[ OK ] DMR API healthy; loaded model entries: {n}")
    else:
        log(f"[WARN] DMR API not reachable (HTTP {code}) -"
            " dmr-watchdog owns recovery; check docker logs"
            " dmr-watchdog")
    wd = wsl("docker ps --filter name=dmr-watchdog --format"
             " '{{.Status}}'")
    log(f"[ OK ] dmr-watchdog: {wd[0].strip() if wd else '?'}")

    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "(Get-CimInstance Win32_OperatingSystem)"
                        ".FreePhysicalMemory"],
                       capture_output=True, text=True)
    try:
        free_gb = round(int(r.stdout.strip()) / 1048576, 1)
    except ValueError:
        free_gb = 0
    log(f"[ OK ] host free memory: {free_gb} GB")
    if free_gb < min_free:
        if report_only:
            log(f"[ DRY ] would drop WSL page caches (host below"
                f" {min_free} GB)")
        else:
            wsl("sync; echo 3 > /proc/sys/vm/drop_caches",
                as_root=True)
            time.sleep(3)
            r2 = subprocess.run(
                ["powershell", "-NoProfile", "-Command",
                 "(Get-CimInstance Win32_OperatingSystem)"
                 ".FreePhysicalMemory"],
                capture_output=True, text=True)
            try:
                free2 = round(int(r2.stdout.strip()) / 1048576, 1)
            except ValueError:
                free2 = free_gb
            log(f"[ OK ] dropped WSL page caches: host free"
                f" {free_gb} -> {free2} GB")
    else:
        log("[ OK ] host memory above threshold - no cache drop"
            " needed")

    df = [l for l in wsl("df -h /") if l.startswith("/dev")]
    fields = re.sub(r"\s+", " ", df[0]).strip().split() \
        if df else []
    if len(fields) >= 5:
        log(f"[ OK ] WSL root disk: {fields[2]} used /"
            f" {fields[1]} ({fields[4]})")
    else:
        log("[WARN] could not read WSL disk usage")
    for l in wsl('docker system df --format "{{.Type}}: {{.Size}}'
                 ' (reclaimable {{.Reclaimable}})"'):
        if l:
            log(f"[ OK ] docker {l.strip()}")
    log("[NOTE] all containers use unbounded json-file logs; bound"
        " them with per-service")
    log("       logging: options (max-size/max-file) at the next"
        " planned recreate - downtime-bearing, so manual.")

    after = {"running": stack_count("docker ps -q | wc -l"),
             "unhealthy": stack_count(
                 "docker ps --filter health=unhealthy -q | wc -l"),
             "exited": stack_count(
                 "docker ps -a --filter status=exited -q | wc -l")}
    if min(after.values()) < 0:
        log("[FAIL] could not read post-pass stack counts -"
            " investigate (platform state unknown).")
        return 1
    log(f"[ OK ] stack after: {after['running']} running /"
        f" {after['unhealthy']} unhealthy /"
        f" {after['exited']} exited")
    if after["running"] < before["running"]:
        log(f"[FAIL] running count DROPPED ({before['running']} ->"
            f" {after['running']}) - investigate immediately!")
        return 2
    if after["unhealthy"] > 0:
        log("[WARN] MAINTENANCE DONE - unhealthy containers remain")
        return 2
    log(f"=== MAINTENANCE DONE - ZERO DOWNTIME"
        f" ({after['running']} running throughout) ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
