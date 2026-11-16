"""WSL swap-pressure watchdog + elevated piggyback lanes (port of
scripts/check-wsl-memory-pressure.ps1). Runs every 30 min via
\\DevOptimizer\\WSL-Memory-Watchdog (elevated, headless).

Elevated-lane bootstraps (each guarded by task/rule existence):
sshd-repair -RegisterTask, Windows-Patch-Check-Elevated re-register
(conhost-headless action), Net-Soft-Reset, Popup-Flash-Watch,
Phone-Tailnet-Watch (10 min), DeepClean-Elevated (monthly 1st 04:00
-SkipVhdx), CDP-Relay-9229 firewall rule.

Core: skip when vmmemWSL absent (never wake the VM); `wsl free -m`
Swap line - warn event 1003 >=80%, drop_caches >=90%, docker-desktop
restart >=95% (2h cooldown stamp); swap-orphan reaper piggyback; C:
free guard (event 1004 <15GB warn/<5GB error); rewrap-headless-all 6h
throttle; elevated-once\\*.ps1 lane. --dry-run skips mutations.
"""

import argparse
import ctypes
import datetime
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

# CATEGORY: maintenance
# TAGS: wsl, watchdog, memory, swap, piggyback
# REQUIRES: admin

ROOT = Path(r"D:\DevOptimizer")
LOG = ROOT / "logs" / "wsl-memory-pressure.log"
COOLDOWN_STAMP = ROOT / "logs" / "dd-restart.cooldown"
REWRAP_MARKER = ROOT / "scripts" / "_rewrap-last-run.stamp"
ONCE_DIR = ROOT / "elevated-once"


def log(msg):
    line = f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {msg}"
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG, "a") as fh:
            fh.write(line + "\n")
    except OSError:
        pass
    print(line)


def ps(script, timeout=300):
    return subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-Command", script], capture_output=True, text=True,
        errors="replace", timeout=timeout)


def task_exists(path_name):
    name = path_name.rsplit("\\", 1)[-1]
    r = ps(f"Get-ScheduledTask -TaskName '{name}' "
           "-ErrorAction SilentlyContinue")
    return bool(r.stdout.strip())


def elevated_lanes(dry):
    """Idempotent registrations this elevated pass owns."""
    if dry:
        print("[dry-run] elevated piggyback lanes")
        return
    try:
        repair = ROOT / "scripts" / "sshd-repair.ps1"
        if repair.is_file():
            if task_exists("Sshd-Watch"):
                ps(f"& '{repair}'")
            else:
                ps(f"& '{repair}' -RegisterTask")
                if task_exists("Sshd-Watch"):
                    (ROOT / "logs" / ".sshd-watch-registered").touch()
    except Exception:
        pass
    try:
        xml = Path(r"C:\Users\tbaltzakis\devin-scripts"
                   r"\win-patch-task-elevated.xml")
        if xml.is_file():
            headless = ps(
                "$t = Get-ScheduledTask -TaskName "
                "'Windows-Patch-Check-Elevated' -ErrorAction "
                "SilentlyContinue; "
                "if ($t -and $t.Actions[0].Execute -match 'conhost') "
                "{'ok'}").stdout.strip()
            if not headless:
                ps("Register-ScheduledTask -TaskName "
                   f"'Windows-Patch-Check-Elevated' -Xml "
                   f"(Get-Content '{xml}' -Raw) -Force | Out-Null; "
                   "Unregister-ScheduledTask -TaskName "
                   "'Windows-Patch-Check' -Confirm:$false "
                   "-ErrorAction SilentlyContinue")
                log("  (re)registered Windows-Patch-Check-Elevated "
                    "via elevated piggyback")
    except Exception:
        pass
    try:
        if not task_exists("Net-Soft-Reset"):
            ps(f"& '{ROOT}\\scripts\\network-soft-reset.ps1' "
               "-RegisterTask")
            log("  registered Net-Soft-Reset via elevated piggyback")
    except Exception:
        pass
    for name, arg_line, principal in (
            ("Popup-Flash-Watch",
             '--headless powershell.exe -NoProfile -ExecutionPolicy '
             'Bypass -File "D:\\DevOptimizer\\scripts'
             '\\popup-flash-watch.ps1"', "Highest"),
            ("Phone-Tailnet-Watch",
             '--headless powershell.exe -NoProfile -ExecutionPolicy '
             'Bypass -File "D:\\DevOptimizer\\scripts'
             '\\phone-tailnet-watch.ps1"', "Limited")):
        try:
            if not task_exists(name):
                interval = "10" if name == "Phone-Tailnet-Watch" \
                    else None
                trig = ("-Once -At (Get-Date) -RepetitionInterval "
                        f"(New-TimeSpan -Minutes {interval})"
                        if interval else
                        "-Once -At (Get-Date '2030-01-01')")
                ps(
                    "$a = New-ScheduledTaskAction -Execute "
                    "'C:\\Windows\\System32\\conhost.exe' -Argument "
                    f"'{arg_line}'; "
                    f"$t = New-ScheduledTaskTrigger {trig}; "
                    f"$p = New-ScheduledTaskPrincipal -UserId "
                    f"$env:USERNAME -LogonType Interactive "
                    f"-RunLevel {principal}; "
                    "Register-ScheduledTask -TaskPath '\\DevOptimizer\\'"
                    f" -TaskName '{name}' -Action $a -Trigger $t "
                    "-Principal $p -Force | Out-Null")
                log(f"  registered {name} via elevated piggyback")
        except Exception:
            pass
    try:
        r = ps("$t = Get-ScheduledTask -TaskPath '\\DevOptimizer\\' "
               "-TaskName 'DeepClean-Elevated' -ErrorAction "
               "SilentlyContinue; if ($t -and $t.Actions.Arguments "
               "-match 'SkipVhdx' -and $t.Actions.Execute -match "
               "'conhost') {'ok'}")
        if not r.stdout.strip():
            subprocess.run(
                ["schtasks.exe", "/create", "/tn",
                 "\\DevOptimizer\\DeepClean-Elevated", "/sc", "monthly",
                 "/d", "1", "/st", "04:00", "/rl", "HIGHEST", "/ru",
                 os.environ.get("USERNAME", ""), "/tr",
                 "C:\\Windows\\System32\\conhost.exe --headless "
                 "powershell.exe -NoProfile -ExecutionPolicy Bypass "
                 "-File \"D:\\DevOptimizer\\scripts"
                 "\\admin-cleanup-elevated.ps1\" -SkipVhdx", "/f"],
                capture_output=True)
            log("  registered DeepClean-Elevated via elevated "
                "piggyback")
    except Exception:
        pass
    try:
        ps("if (-not (Get-NetFirewallRule -DisplayName "
           "'CDP-Relay-9229' -ErrorAction SilentlyContinue)) "
           "{ New-NetFirewallRule -DisplayName 'CDP-Relay-9229' "
           "-Direction Inbound -Protocol TCP -LocalPort 9229 "
           "-Action Allow | Out-Null }")
    except Exception:
        pass


def vmmem_gb():
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "(Get-Process vmmemWSL -ErrorAction "
                        "SilentlyContinue).WS"],
                       capture_output=True, text=True,
                       errors="replace")
    try:
        return int(r.stdout.strip()) / 2**30
    except ValueError:
        return None


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run

    elevated_lanes(dry)

    vm = vmmem_gb()
    if vm is None:
        log("WSL not running (skipped)")
        sys.exit(0)

    r = subprocess.run(["wsl", "-e", "bash", "-c", "free -m"],
                       capture_output=True, text=True,
                       errors="replace")
    for line in r.stdout.replace("\r", "").splitlines():
        if line.startswith("Swap:"):
            parts = line.split()
            total, used = int(parts[1]), int(parts[2])
            if total > 0:
                pct = round(100 * used / total)
                log(f"swap {used}/{total} MB ({pct}%), "
                    f"vmmemWSL {vm:.1f} GB")
                if pct >= 80:
                    ps("Write-EventLog -LogName 'DevOptimizer' "
                       "-Source 'DevOptimizer' -EventId 1003 "
                       "-EntryType Warning -Message "
                       f"'WSL swap pressure {pct}% ({used}/{total} MB)"
                       " - wedge risk.'")
                    log(f"WARNING: swap pressure {pct}% - event "
                        "1003 written")
                if pct >= 90:
                    if not dry:
                        subprocess.run(
                            ["wsl", "-d", "Ubuntu-24.04", "-u", "root",
                             "--", "sh", "-c",
                             "sync; echo 1 > /proc/sys/vm/drop_caches"],
                            capture_output=True)
                    log(f"ACTION: swap {pct}% - dropped guest page "
                        "cache")
                if pct >= 95:
                    cooled = (COOLDOWN_STAMP.is_file() and
                              (time.time() -
                               COOLDOWN_STAMP.stat().st_mtime) < 7200)
                    if cooled:
                        log(f"CRITICAL: swap {pct}% persists; "
                            "docker-desktop restart in 2h cooldown")
                    else:
                        docker_exe = (r"C:\Program Files\Docker\Docker"
                                      r"\resources\bin\docker.exe")
                        if Path(docker_exe).is_file():
                            if not dry:
                                subprocess.run(
                                    [docker_exe, "desktop", "restart"],
                                    capture_output=True)
                            log(f"ACTION: swap {pct}% - docker "
                                "desktop restart issued")
                        else:
                            if not dry:
                                subprocess.run(
                                    ["wsl", "--terminate",
                                     "docker-desktop"],
                                    capture_output=True)
                            log(f"ACTION: swap {pct}% - wsl "
                                "--terminate docker-desktop")
                        if not dry:
                            COOLDOWN_STAMP.touch()
                            ps("Write-EventLog -LogName 'DevOptimizer'"
                               " -Source 'DevOptimizer' -EventId 1003"
                               " -EntryType Warning -Message "
                               f"'WSL swap {pct}% exhausted - "
                               "docker-desktop distro restarted.'")
            break

    # swap-orphan reaper piggyback
    reaper = ROOT / "scripts" / "cleanup-wsl-swap-orphans.ps1"
    if reaper.is_file() and not dry:
        try:
            ps(f"& '{reaper}' | Out-Null", timeout=600)
        except Exception as e:
            log(f"swap-orphan reaper failed: {e}")

    # C: free-space guard (swap.vhdx + docker_data.vhdx live on C:)
    try:
        c_free = round(shutil.disk_usage("C:\\").free / 2**30, 1)
        log(f"C: free {c_free} GB")
        if c_free < 5:
            ps("Write-EventLog -LogName 'DevOptimizer' -Source "
               "'DevOptimizer' -EventId 1004 -EntryType Error "
               f"-Message 'C: drive critically low: {c_free} GB free "
               "- expect WSL stalls and Docker Desktop crashes.'")
            log(f"CRITICAL: C: free {c_free} GB - event 1004")
        elif c_free < 15:
            ps("Write-EventLog -LogName 'DevOptimizer' -Source "
               "'DevOptimizer' -EventId 1004 -EntryType Warning "
               f"-Message 'C: drive low: {c_free} GB free.'")
            log(f"WARNING: C: free {c_free} GB - event 1004")
    except Exception:
        pass

    # rewrap-headless-all (6h throttle)
    try:
        stale = (not REWRAP_MARKER.is_file() or
                 (time.time() -
                  REWRAP_MARKER.stat().st_mtime) >= 6 * 3600)
        if stale:
            if not dry:
                ps(f"& '{ROOT}\\scripts\\_rewrap-headless-all.ps1'",
                   timeout=600)
                REWRAP_MARKER.touch()
            log("rewrap-headless-all piggybacked (6h throttle)")
    except Exception as e:
        log(f"rewrap piggyback failed: {e}")

    # elevated-once lane
    if ONCE_DIR.is_dir() and not dry:
        for f in ONCE_DIR.glob("*.ps1"):
            try:
                ps(f"& '{f}'", timeout=600)
                log(f"elevated-once ran {f.name}")
            except Exception as e:
                log(f"elevated-once FAILED {f.name}: {e}")
            try:
                f.unlink()
            except OSError:
                pass


if __name__ == "__main__":
    main()
