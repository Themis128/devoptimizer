"""Port of scripts/devin/Invoke-DevinDailyMaintenance.ps1 —
unattended daily Devin Desktop maintenance: cache sweep, host/server
log retention, bundle-orphan removal (corrupt/superseded commit dirs,
live-guarded), sessions.db VACUUM when Devin closed and freelist
>=256MiB, health verdict, latest.json report. Exit 0/1/2.
"""
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

DISTRO = "Ubuntu-24.04"
REPORT_DIR = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs"
                  + chr(92) + "devin-maintenance")
CLI = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Devin" \
    / "bin" / "devin-desktop.cmd"
CACHE = Path(os.environ.get("APPDATA", "")) / "Devin" / "Cache"
HOST_LOGS = Path(os.environ.get("APPDATA", "")) / "Devin" / "logs"
SESSIONS_DB = Path(os.environ.get("APPDATA", "")) / "devin" / "cli" \
    / "sessions.db"
steps = []


def wsl(cmd):
    try:
        r = subprocess.run(["wsl.exe", "-d", DISTRO, "--", "bash",
                            "-c", cmd], capture_output=True,
                           text=True)
        return [l for l in re.split(r"\r?\n",
                                    r.stdout.replace("\x00", ""))
                if l]
    except FileNotFoundError:
        return []


def step(name, status, detail):
    print(f"[{status:<5}] {name}: {detail}")
    steps.append({"name": name, "status": status,
                  "detail": detail})


def event(id_, etype, msg):
    subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Write-EventLog -LogName Application -Source 'DevOptimizer'"
         f" -EventId {id_} -EntryType {etype} -Message \"{msg}\""
         " -ErrorAction SilentlyContinue"],
        capture_output=True)


def main():
    retention = report_retention = 14
    vacuum_mb = 256
    for i, a in enumerate(sys.argv):
        if a == "--log-retention-days" and i + 1 < len(sys.argv):
            retention = int(sys.argv[i + 1])
        if a == "--report-retention-days" and i + 1 < len(sys.argv):
            report_retention = int(sys.argv[i + 1])
        if a == "--vacuum-threshold-mb" and i + 1 < len(sys.argv):
            vacuum_mb = int(sys.argv[i + 1])
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    final_exit = health_exit = 0
    app_running = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "[bool](Get-Process -Name 'Devin' -ErrorAction"
         " SilentlyContinue)"], capture_output=True,
        text=True).stdout.strip().lower() == "true"
    print(f"=== Devin Daily Maintenance ({DISTRO}) ===")
    print(f"Devin.exe running: {app_running} -> bundle repairs"
          f" {'DEFERRED' if app_running else 'enabled'}")

    if "ok" not in " ".join(wsl("echo ok")):
        step("wsl-preflight", "FAIL",
             f"distro '{DISTRO}' unreachable - check WSL/Docker VM"
             " state (wsl --shutdown recovery) before anything else")
        event(1002, "Error",
              f"Devin daily maintenance FAILED: WSL distro"
              f" '{DISTRO}' unreachable. Check WSL/Docker VM state.")
        (REPORT_DIR / "latest.json").write_text(json.dumps(
            {"date": time.strftime("%Y-%m-%dT%H:%M:%S"),
             "appRunning": app_running, "steps": steps,
             "healthExitCode": None, "exitCode": 1}))
        return 1
    step("wsl-preflight", "OK", f"distro '{DISTRO}' reachable")

    freed, locked = 0, 0
    if CACHE.exists():
        for f in CACHE.rglob("*"):
            if not f.is_file():
                continue
            try:
                size = f.stat().st_size
                f.unlink()
                freed += size
            except OSError:
                locked += 1
        step("cache-sweep", "OK",
             f"freed {freed / 1048576:.1f} MB, {locked} locked"
             " file(s) skipped")
    else:
        step("cache-sweep", "SKIP", f"{CACHE} not present")

    removed = 0
    cutoff = time.time() - retention * 86400
    if HOST_LOGS.exists():
        for d in HOST_LOGS.iterdir():
            if d.is_dir() and d.stat().st_mtime < cutoff:
                try:
                    shutil.rmtree(d)
                    removed += 1
                except OSError:
                    pass
    step("host-log-retention", "OK",
         f"removed {removed} session dir(s) older than {retention}"
         " days from %APPDATA%\\Devin\\logs")

    def log_count():
        out = wsl("ls -1 ~/.devin-server/data/logs 2>/dev/null"
                  " | wc -l")
        nums = [l for l in out if re.search(r"\d", l)]
        return int(nums[-1]) if nums else 0

    before = log_count()
    wsl(f"find ~/.devin-server/data/logs -mindepth 1 -maxdepth 1"
        f" -mtime +{retention} -exec rm -rf {{}} + 2>/dev/null; true")
    after = log_count()
    step("server-log-retention", "OK",
         f"server log entries {before} -> {after} (> {retention}"
         " days removed)")

    live_commit = None
    if CLI.exists():
        ver = subprocess.run([str(CLI), "--version"],
                             capture_output=True, text=True).stdout
        vv = [l for l in ver.splitlines()
              if re.match(r"^[a-f0-9]{40}$", l.strip())]
        if vv:
            live_commit = vv[0].strip()
    server_commit = None
    procs = wsl("pgrep -af 'server-mai[n]' 2>/dev/null; true")
    m = re.search(r"\.devin-server/bin/([a-f0-9]{40})/",
                  "\n".join(procs))
    if m:
        server_commit = m.group(1)
    bin_dirs = [l.rstrip("/") for l in wsl(
        "ls -1d ~/.devin-server/bin/*/ 2>/dev/null")]
    deleted, deferred, corrupt_removed = [], [], False
    if not live_commit and bin_dirs:
        step("bundle-orphans", "SKIP",
             "could not parse live commit from devin-desktop.cmd"
             " --version; leaving "
             f"{len(bin_dirs)} commit dir(s) untouched")
    else:
        cutoff48 = time.time() - 48 * 3600
        for d in bin_dirs:
            commit = d.rsplit("/", 1)[-1]
            integ = wsl(f"test -d '{d}/node_modules/minimist' -a -d"
                        f" '{d}/node_modules/@vscode' && echo intact"
                        " || echo broken")
            corrupt = "broken" in integ
            st = wsl(f"stat -c %Y '{d}' 2>/dev/null")
            fresh = False
            try:
                fresh = float(st[0]) > cutoff48 if st else False
            except ValueError:
                pass
            is_live = (commit == live_commit
                       or commit == server_commit or fresh)
            if not corrupt and is_live:
                continue
            why = "CORRUPT bundle" if corrupt \
                else "superseded commit dir"
            if app_running:
                deferred.append(f"{commit} ({why})")
                continue
            wsl(f"rm -rf '{d}'; rm -f ~/.devin-server/bin/.{commit}"
                f".log ~/.devin-server/bin/.{commit}.pid"
                f" ~/.devin-server/bin/.{commit}.token")
            deleted.append(f"{commit} ({why})")
            if corrupt:
                corrupt_removed = True
        if deleted:
            step("bundle-orphans", "OK",
                 "removed: " + ", ".join(deleted)
                 + "; next app launch re-downloads the bundle")
            if corrupt_removed:
                final_exit = 2
                print("[FIX ] corrupt bundle removed - on next"
                      " Devin launch a fresh ~700 MB bundle"
                      " downloads automatically.")
        elif deferred:
            step("bundle-orphans", "DEFER",
                 "app is running; deferred: " + ", ".join(deferred))
        else:
            short = (live_commit or server_commit or "unknown")[:7]
            step("bundle-orphans", "OK",
                 f"all commit dirs intact and current"
                 f" (live: {short})")

    if not SESSIONS_DB.exists():
        step("sessions-db-vacuum", "SKIP",
             f"{SESSIONS_DB} unavailable - skipped")
    else:
        try:
            con = sqlite3.connect(
                f"file:{SESSIONS_DB}?mode=ro", uri=True)
            page = con.execute("PRAGMA page_size").fetchone()[0]
            count = con.execute("PRAGMA page_count").fetchone()[0]
            free = con.execute("PRAGMA freelist_count").fetchone()[0]
            con.close()
            total, freeb = page * count, page * free
            free_mb = int(freeb / 1048576)
            if app_running:
                step("sessions-db-vacuum", "DEFER",
                     f"app running; {total / 1048576} MiB db,"
                     f" {free_mb} MiB freelist reclaimable - VACUUM"
                     " deferred until Devin is closed")
            elif free_mb < vacuum_mb:
                step("sessions-db-vacuum", "SKIP",
                     f"{free_mb} MiB freelist < {vacuum_mb} MiB"
                     " threshold - not worth compacting")
            else:
                sz_before = SESSIONS_DB.stat().st_size
                con = sqlite3.connect(str(SESSIONS_DB))
                con.execute("VACUUM")
                con.close()
                sz_after = SESSIONS_DB.stat().st_size
                step("sessions-db-vacuum", "OK",
                     f"{sz_before} -> {sz_after} bytes"
                     f" ({(sz_before - sz_after) / 1048576:.0f} MiB"
                     " reclaimed)")
        except sqlite3.Error as e:
            step("sessions-db-vacuum", "WARN",
                 f"probe/vacuum failed: {e}")

    health_script = (Path(__file__).resolve().parents[1] / "devin"
                     / "Check-DevinHealth.ps1")
    if not health_script.exists():
        health_script = Path("D:" + chr(92) + "DevOptimizer" + chr(92)
                             + "scripts" + chr(92) + "devin" + chr(92)
                             + "Check-DevinHealth.ps1")
    r = subprocess.run(["powershell.exe", "-NoProfile",
                        "-ExecutionPolicy", "Bypass", "-File",
                        str(health_script)], capture_output=True,
                       text=True)
    health_exit = r.returncode
    if r.stdout:
        print(r.stdout.strip())

    summary = "; ".join(s["name"] + "=" + s["status"]
                        for s in steps)
    if final_exit == 0:
        event(1000, "Information",
              f"Devin daily maintenance OK (Devin running:"
              f" {app_running}). Steps: {summary}. Health exit:"
              f" {health_exit}.")
    elif final_exit == 2:
        event(1001, "Warning",
              "Devin daily maintenance PERFORMED A REPAIR - next"
              " Devin launch re-downloads the bundle (~700 MB)."
              f" Steps: {summary}.")
    else:
        event(1002, "Error",
              f"Devin daily maintenance exited with code"
              f" {final_exit}. Steps: {summary}.")
    cutoff_r = time.time() - report_retention * 86400
    for f in REPORT_DIR.iterdir():
        if f.is_file() and f.stat().st_mtime < cutoff_r:
            f.unlink(missing_ok=True)
    (REPORT_DIR / "latest.json").write_text(json.dumps(
        {"date": time.strftime("%Y-%m-%dT%H:%M:%S"),
         "appRunning": app_running, "steps": steps,
         "healthExitCode": health_exit, "exitCode": final_exit},
        indent=2), encoding="utf-8")
    return final_exit


if __name__ == "__main__":
    sys.exit(main())
