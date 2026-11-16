"""Port of scripts/repair-wsl-docker-integration.ps1 — WSL2/Docker
Desktop integration watchdog: distro reachable, ~/ ownership +
~/.docker/run creatable (chown -R repair), IntegratedWslDistros
re-enable, docker.sock/engine probe with transient confirm, DD
restart, scripted #13426 integration reset (once/day), fsbridge
distro-proxy + stack-watchers cli-tools mount checks, weekly
wsl --update. --dry-run reports only.
"""
import datetime
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

DISTRO = "Ubuntu-24.04"
ROOT = Path("D:" + chr(92) + "DevOptimizer")
LOG = ROOT / "logs" / "wsl-repair.log"


def log(msg):
    line = time.strftime("%Y-%m-%d %H:%M:%S") + " " + msg
    try:
        if LOG.exists() and LOG.stat().st_size > 1048576:
            tail = LOG.read_text(errors="replace").splitlines()[-2000:]
            LOG.write_text("\n".join(tail) + "\n", encoding="utf-8")
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass
    print(line)


def wsl(argv, root=False):
    args = ["wsl.exe", "-d", DISTRO]
    if root:
        args += ["-u", "root"]
    args += ["--"] + list(argv)
    try:
        r = subprocess.run(args, capture_output=True, text=True)
        return r.returncode, (r.stdout + r.stderr).strip()
    except FileNotFoundError:
        return -1, ""


def dd_running():
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "[bool](Get-Process -Name 'Docker Desktop'"
                        " -ErrorAction SilentlyContinue)"],
                       capture_output=True, text=True)
    return r.stdout.strip().lower() == "true"


def dd_stop():
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    "Get-Process -Name 'Docker Desktop'"
                    " -ErrorAction SilentlyContinue |"
                    " Stop-Process -Force"], capture_output=True)


def dd_start():
    exe = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" \
        / "DockerDesktop" / "Docker Desktop.exe"
    subprocess.Popen([str(exe)])


def engine_probe(timeout_s=8):
    code, out = wsl(["timeout", str(timeout_s), "docker", "info",
                     "--format", "{{.ServerVersion}}"])
    return code == 0 and re.match(r"^\d+\.\d+", out), out


def load_settings(path):
    try:
        return json.loads(Path(path).read_text(
            encoding="utf-8-sig"))
    except (OSError, ValueError):
        return None


def save_settings(path, st):
    Path(path).write_text(json.dumps(st, indent=2), encoding="utf-8")


def main():
    dry = "--dry-run" in sys.argv
    log(f"=== WSL repair check (dryRun={dry}) ===")

    code, out = wsl(["echo", "__WSL_OK__"])
    if "__WSL_OK__" not in out:
        log(f"[{DISTRO}] not installed/unreachable - skipping")
        return 0

    _, user = wsl(["whoami"])
    user = user.strip()
    hd = f"/home/{user}"
    code_mk, out_mk = wsl(["mkdir", "-p", f"{hd}/.docker/run"])
    _, foreign = wsl(["find", hd, "-maxdepth", "1", "!", "-user",
                      user])
    foreign_n = len([l for l in foreign.splitlines() if l.strip()])
    if code_mk != 0 and out_mk == "":
        _, out2 = wsl(["echo", "__WSL_OK__"])
        if "__WSL_OK__" not in out2:
            log("[home] SKIP: wsl call failed"
                f" (mkdirExit={code_mk}) and distro unreachable -"
                " transient, not an ownership fault")
            foreign_n = 0
        else:
            code_mk, out_mk = wsl(["mkdir", "-p",
                                   f"{hd}/.docker/run"])

    settings_path = str(Path(os.environ.get("APPDATA", ""))
                        / "Docker" / "settings-store.json")
    if code_mk != 0 or foreign_n > 0:
        log(f"[home] BROKEN user={user} mkdirExit={code_mk}"
            f" foreignTopLevel={foreign_n}")
        if not dry:
            log(f"[home] repairing: chown -R {user}:{user} {hd}")
            c1, _ = wsl(["chown", "-R", f"{user}:{user}", hd],
                        root=True)
            c2, _ = wsl(["mkdir", "-p", f"{hd}/.docker/run"])
            c3, _ = wsl(["chown", f"{user}:{user}", f"{hd}/.docker",
                         f"{hd}/.docker/run"], root=True)
            log(f"[home] repair chownExit={c1} mkdirExit={c2}"
                f" chownDockerExit={c3}")
    else:
        log(f"[home] OK ({user})")
        st = load_settings(settings_path)
        if st is None:
            log("[integration] settings check failed:")
        elif "IntegratedWslDistros" not in st:
            log("[integration] no IntegratedWslDistros key (DD 4.98+"
                " schema) - default-distro integration governs,"
                " skipping")
        elif DISTRO not in (st.get("IntegratedWslDistros") or []):
            if not dry:
                st["IntegratedWslDistros"] = \
                    (st.get("IntegratedWslDistros") or []) + [DISTRO]
                save_settings(settings_path, st)
                log(f"[integration] re-enabled {DISTRO} in"
                    " settings-store.json (distro reachable; DD"
                    " will re-push the proxy)")
            else:
                log(f"[integration] would re-enable {DISTRO}"
                    " (dry-run)")

    sock_code, _ = wsl(["test", "-S", "/var/run/docker.sock"])
    engine_ok, eng_ver = (False, "")
    if sock_code == 0:
        engine_ok, eng_ver = engine_probe(8)
    if sock_code != 0 or not engine_ok:
        if sock_code == 0:
            time.sleep(15)
            ok2, v2 = engine_probe(15)
            if ok2:
                engine_ok, eng_ver = True, v2
                log(f"[docker] first probe failed, second probe OK"
                    f" (ver={v2}) - transient, no restart")
    if sock_code != 0 or not engine_ok:
        log(f"[docker] BROKEN sock={sock_code == 0}"
            f" engine={engine_ok}({eng_ver})"
            f" dockerDesktopRunning={dd_running()}")
        if not dry:
            if dd_running():
                log("[docker] restarting Docker Desktop")
                dd_stop()
                time.sleep(5)
                dd_start()
                deadline = time.time() + 180
                while True:
                    time.sleep(10)
                    ok, ver = engine_probe(8)
                    if ok or time.time() > deadline:
                        break
                log(f"[docker] post-restart engineOk={ok} ver={ver}")
                if not ok:
                    _, chan = wsl(["echo", "__WSL_OK__"])
                    stamp = ROOT / "logs" / ".dd-integration-reset"
                    today = datetime.date.today().isoformat()
                    rst_today = stamp.exists() and \
                        stamp.read_text().strip() == today
                    if not rst_today:
                        if "__WSL_OK__" in chan:
                            log("[docker] engine dead after DD"
                                " restart - running scripted #13426"
                                " integration reset")
                            dd_stop()
                            time.sleep(5)
                            st = load_settings(settings_path)
                            if st is not None:
                                if "IntegratedWslDistros" in st:
                                    st["IntegratedWslDistros"] = []
                                    if "EnableIntegrationWithDefaultWslDistro" in st:
                                        st["EnableIntegrationWithDefaultWslDistro"] = False
                                    save_settings(settings_path, st)
                            else:
                                log("[integration] settings reset"
                                    " failed")
                            dd_start()
                            deadline = time.time() + 240
                            while True:
                                time.sleep(10)
                                ok, ver = engine_probe(8)
                                if ok or time.time() > deadline:
                                    break
                            log(f"[docker] post-reset engineOk={ok}"
                                f" ver={ver}")
                            if ok:
                                st = load_settings(settings_path)
                                if st is not None and \
                                        "IntegratedWslDistros" in st \
                                        and DISTRO not in \
                                        (st.get(
                                            "IntegratedWslDistros")
                                         or []):
                                    st["IntegratedWslDistros"] = \
                                        st["IntegratedWslDistros"] \
                                        + [DISTRO]
                                    save_settings(settings_path, st)
                                    log(f"[integration] re-added"
                                        f" {DISTRO} post-reset (DD"
                                        " re-pushes proxy)")
                            stamp.write_text(today)
                        else:
                            log("[docker] integration reset skipped"
                                " - wsl exec channel dead (vsock"
                                " wedge class; exit-gate heal owns"
                                " it)")
            else:
                log("[docker] Docker Desktop not running - leaving"
                    " stopped (socket absence is expected)")
    else:
        log(f"[docker] OK (engine {eng_ver} reachable)")
        pcode, _ = wsl(["pgrep", "-f", "user-distro-proxy"])
        if pcode == 0:
            log("[fsbridge] distro proxy alive")
        else:
            _, dm = wsl(["bash", "-lc",
                         "find /mnt/wsl/docker-desktop-bind-mounts"
                         " -maxdepth 3 -type d -empty 2>/dev/null"
                         " | wc -l"])
            log(f"[fsbridge] DISTRO PROXY DEAD - UNC-sourced"
                " bind-mounts will be empty dirs (empty mount"
                f" dirs: {dm.strip()}). Heals on wsl --shutdown +"
                " DD restart; affected containers need"
                " force-recreate after.")
        sw = "stack-watchers"
        _, swr = wsl(["docker", "inspect", "-f",
                      "{{.State.Running}}", sw])
        if swr.strip() == "true":
            mcode, _ = wsl(["docker", "exec", sw, "test", "-f",
                            "/usr/bin/docker"])
            if mcode != 0:
                icode, _ = wsl(["grep", "-qs", "cli-tools.*iso9660",
                                "/proc/mounts"])
                if icode == 0:
                    log(f"[{sw}] docker-cli mount is an empty dir -"
                        " recreating (iso remounted)")
                    if not dry:
                        proj = f"/home/{user}/cu130-slim"
                        wsl(["bash", "-lc",
                             f'echo "$(date -u +%FT%TZ)'
                             f" devoptimizer-wsl-repair refix {sw}"
                             f' mount" > {proj}/.deploy.lock'])
                        rcode, rout = wsl(
                            ["bash", "-lc",
                             f"cd {proj} && docker compose up -d"
                             f" --force-recreate {sw} 2>&1"
                             f" | tail -3; rm -f"
                             f" {proj}/.deploy.lock"])
                        m2, _ = wsl(["docker", "exec", sw, "test",
                                     "-f", "/usr/bin/docker"])
                        tail = " | ".join(
                            rout.splitlines()[-3:])
                        log(f"[{sw}] recreate exit={rcode}"
                            f" mountOk={m2 == 0} out={tail}")
                else:
                    log(f"[{sw}] docker-cli mount broken but"
                        " cli-tools iso not remounted yet - will"
                        " retry next pass")

    upd_stamp = ROOT / "logs" / ".wsl-update-stamp"
    due = (not upd_stamp.exists()
           or upd_stamp.stat().st_mtime
           < time.time() - 7 * 86400)
    if due:
        if not dry:
            log("[wsl] weekly update check: wsl --update"
                " --web-download")
            r = subprocess.run(["wsl.exe", "--update",
                                "--web-download"],
                               capture_output=True, text=True)
            out = re.sub(r"\s+", " ",
                         (r.stdout + r.stderr).strip())[:200]
            log(f"[wsl] update exit={r.returncode} out={out}")
            upd_stamp.write_text(
                datetime.datetime.now().isoformat())
        else:
            log("[wsl] weekly update check due (dry-run, skipped)")
    log("=== WSL repair check done ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
