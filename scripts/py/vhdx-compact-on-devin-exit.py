"""Port of scripts/vhdx-compact-on-devin-exit.ps1 — fire
\\DevOptimizer\\Nightly-Vhdx-Compact once per day when Devin.exe AND
devin-server are both gone. Also owns the vsock-wedge heal, the
heal-resistant Net-Soft-Reset escalation, and the idle fsbridge
recycle (all gated on Devin presence, idle >= 30min, no devin-server).
"""
# REQUIRES: admin
import ctypes
import datetime
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path


def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required",
              file=sys.stderr)
        sys.exit(1)


LOGS = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs")
LOG = LOGS / "vhdx-compact-on-exit.log"
STAMP = LOGS / ".vhdx-compact-fired"
WEDGE = LOGS / ".vsock-wedge-healed"
NOTIFIED = LOGS / ".vsock-heal-notified"
IDLE = LOGS / ".idle-recycle-fired"
REPAIR_LOG = LOGS / "wsl-repair.log"
WEDGE_PAT = (r"unreachable|WSAETIMEDOUT|Wsl/Service|BROKEN"
             r"|DISTRO PROXY DEAD")


def log(msg):
    line = time.strftime("%Y-%m-%dT%H:%M:%S") + " " + msg
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def heal_notice(msg):
    subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         ". 'D:\\DevOptimizer\\scripts\\lib\\Notify.ps1'\n"
         "Send-DevOptAlert -Severity Warning -Title 'WSL vsock heal'"
         " -Message '" + msg.replace("'", "''")
         + "' -Tags 'wsl','vsock' -ErrorAction SilentlyContinue"],
        capture_output=True)


def minutes_idle():
    class LASTINPUTINFO(ctypes.Structure):
        _fields_ = [("cbSize", ctypes.c_uint),
                    ("dwTime", ctypes.c_uint)]
    lii = LASTINPUTINFO()
    lii.cbSize = ctypes.sizeof(LASTINPUTINFO)
    if not ctypes.windll.user32.GetLastInputInfo(
            ctypes.byref(lii)):
        return -1
    return int(((ctypes.windll.kernel32.GetTickCount() & 0xFFFFFFFF)
                - lii.dwTime) // 60000)


def devin_server_alive():
    for _ in range(3):
        r = subprocess.run(
            ["wsl.exe", "-d", "Ubuntu-24.04", "-e", "bash", "-lc",
             "pgrep -f 'devin acp|server-mai[n]' | head -3"],
            capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            return True
        time.sleep(5)
    return False


def devin_running():
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "[bool](Get-Process -Name 'Devin'"
                        " -ErrorAction SilentlyContinue)"],
                       capture_output=True, text=True)
    return r.stdout.strip().lower() == "true"


def wsl_recycle():
    subprocess.run(["wsl.exe", "--shutdown"], capture_output=True)
    subprocess.run(["wsl.exe", "-d", "Ubuntu-24.04", "-e", "true"],
                   capture_output=True)
    dd = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" \
        / "DockerDesktop" / "Docker Desktop.exe"
    if dd.exists():
        subprocess.Popen([str(dd)])


def wedge_heal(why):
    log("vsock wedge evidence in wsl-repair.log - recycling WSL to"
        f" heal it ({why})")
    wsl_recycle()
    WEDGE.write_text(today())
    heal_notice(f"vsock wedge healed via wsl --shutdown ({why})."
                " Docker Desktop relaunched.")
    log("wsl recycled + Docker Desktop relaunched")


def net_soft_reset(why):
    log(f"heal-resistant wedge ({why}) - firing elevated"
        " \\DevOptimizer\\Net-Soft-Reset")
    r = subprocess.run(["schtasks.exe", "/run", "/tn",
                        "\\DevOptimizer\\Net-Soft-Reset"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        log(f"net-soft-reset launch failed rc={r.returncode}")


def idle_recycle(why):
    log(f"idle recycle ({why}) - wsl --shutdown to heal"
        " fsbridge/poisoned mounts")
    wsl_recycle()
    IDLE.write_text(today())
    heal_notice(f"WSL recycled while idle ({why}) - heals poisoned"
                " bind mounts / fsbridge. Docker Desktop relaunched.")
    log("wsl recycled (idle) + Docker Desktop relaunched")


def today():
    return datetime.date.today().isoformat()


def flag_today(p):
    return p.exists() and p.read_text().strip() == today()


def fsbridge_bad():
    for _ in range(2):
        r = subprocess.run(
            ["wsl.exe", "-d", "Ubuntu-24.04", "-e", "python3",
             "/home/tbaltzakis/cu130-slim/.devin/skills/"
             "wsl-fsbridge-ops/scripts/fsbridge_doctor.py", "status"],
            capture_output=True, text=True)
        if r.stdout:
            return bool(re.search(
                r"casualties: [1-9]|[1-9][0-9]* EMPTY/unreadable",
                r.stdout))
        time.sleep(5)
    return False


def main():
    _ensure_admin()
    compacted_today = flag_today(STAMP)
    recent = []
    if REPAIR_LOG.exists():
        recent = REPAIR_LOG.read_text(
            encoding="utf-8", errors="replace").splitlines()[-80:]
    wedged = any(re.search(WEDGE_PAT, l) for l in recent)
    healed_today = flag_today(WEDGE)
    heal_pending = wedged and not healed_today
    idle_healed_today = flag_today(IDLE)
    fsbridge = False if wedged else fsbridge_bad()
    resistant = False
    if wedged and healed_today:
        last = next((l for l in reversed(recent)
                     if re.search(WEDGE_PAT, l)), None)
        if last:
            m = re.match(r"^(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})",
                         last)
            if m and WEDGE.stat().st_mtime < datetime.datetime \
                    .strptime(m.group(1).replace("T", " "),
                              "%Y-%m-%d %H:%M:%S").timestamp():
                resistant = True

    if devin_running():
        idle_recycle_due = fsbridge and not idle_healed_today
        if not (heal_pending or resistant or idle_recycle_due):
            return 0
        idle = minutes_idle()
        if 0 <= idle < 30:
            if not flag_today(NOTIFIED):
                NOTIFIED.write_text(today())
                what = ("vsock wedge detected"
                        if heal_pending or resistant
                        else "poisoned WSL bind mounts (fsbridge)"
                        " detected")
                heal_notice(f"{what}; heal queued - fires when you"
                            " step away >=30min or close Devin"
                            " (latest: nightly WSL bounce).")
                log(f"heal deferred - Devin open, user active"
                    f" (idle {idle}m); notice sent")
            return 0
        if devin_server_alive():
            log("heal deferred - devin-server still alive (active"
                " agent session)")
            return 0
        if heal_pending:
            wedge_heal("idle-escalation")
        elif resistant:
            net_soft_reset("idle-escalation")
        elif idle_recycle_due:
            idle_recycle("idle-escalation")
        return 0

    if devin_server_alive():
        return 0
    if compacted_today:
        if heal_pending:
            wedge_heal("devin-exit")
        elif resistant:
            net_soft_reset("devin-exit")
        elif fsbridge and not idle_healed_today:
            log("fsbridge still poisoned after today's recycle -"
                " manual investigation needed")
            heal_notice("fsbridge still poisoned after today's WSL"
                        " recycle - bind mounts may need manual"
                        " repair.")
            IDLE.write_text(today())
        return 0
    log("Devin closed - launching Nightly-Vhdx-Compact")
    r = subprocess.run(["schtasks.exe", "/run", "/tn",
                        "\\DevOptimizer\\Nightly-Vhdx-Compact"],
                       capture_output=True, text=True)
    for l in (r.stdout + r.stderr).splitlines():
        log("schtasks: " + l)
    if r.returncode == 0:
        STAMP.write_text(today())
        if wedged:
            WEDGE.write_text(today())
    else:
        log(f"schtasks failed rc={r.returncode} - will retry")
    return 0


if __name__ == "__main__":
    sys.exit(main())
