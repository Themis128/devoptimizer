"""Port of scripts/devin/Check-DevinHealth.ps1 — Devin Desktop WSL
health: distro reachability, uptime, devin-server bundle integrity,
host memory. --repair deletes a corrupt server bundle (exit 2).
"""
# REQUIRES: admin
import ctypes
import re
import subprocess
import sys


def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required",
              file=sys.stderr)
        sys.exit(1)


DISTRO = "Ubuntu-24.04"


def wsl(cmd):
    r = subprocess.run(["wsl.exe", "-d", DISTRO, "--", "bash", "-c",
                        cmd], capture_output=True, text=True)
    out = r.stdout
    if r.returncode != 0:
        r = subprocess.run(["wsl.exe", "-d", DISTRO, "--exec", cmd],
                           capture_output=True, text=True)
        out = r.stdout
    return [l for l in out.replace("\0", "").splitlines() if l]


def main():
    _ensure_admin()
    repair = "--repair" in sys.argv
    warn, fail = [], []
    print(f"=== Devin WSL-Remote Health ({DISTRO}) ===")
    ping = wsl("echo ok")
    if not any("ok" in l for l in ping):
        print(f"[FAIL] WSL distro '{DISTRO}' unreachable - start WSL"
              f" first: wsl -d {DISTRO} --exec true")
        return 1
    print("[ OK ] WSL distro reachable")
    try:
        up = float(wsl("cat /proc/uptime")[0].split()[0])
        if up < 180:
            warn.append(f"WSL booted {int(up)}s ago - Devin may race"
                        " the boot; if a popup appeared, Reload Window"
                        " once WSL is up")
        h, m = int(up) // 3600, (int(up) % 3600) // 60
        print(f"[ OK ] WSL uptime: {h}h {m}m {int(up) % 60}s")
    except (IndexError, ValueError):
        warn.append("could not read WSL uptime")
    procs = wsl("pgrep -af 'devin acp' || true")
    commit = None
    m = re.search(r"\.devin-server/bin/([a-f0-9]{40})/",
                  "\n".join(procs))
    if m:
        commit = m.group(1)
        print(f"[ OK ] devin-server running (commit {commit})")
    else:
        warn.append("devin-server not running - if Devin shows "
                    "'Cannot reconnect', click Reload Window")
        print("[WARN] devin-server not running in WSL")
    if commit:
        base = f"$HOME/.devin-server/bin/{commit}/node_modules"
        check = wsl(f"test -d {base}/minimist -a -d {base}/@vscode"
                    " && echo intact || echo broken")
        if any("intact" in l for l in check):
            print("[ OK ] server bundle intact (minimist + @vscode"
                  " present)")
        else:
            print("[FAIL] server bundle CORRUPT - node_modules"
                  " truncated (classic ERR_MODULE_NOT_FOUND crash"
                  " loop)")
            fail.append(f"bundle corrupt: {commit}")
            if repair:
                print("[FIX ] killing server and deleting corrupt"
                      " commit dir...")
                wsl(f"pkill -f 'devin acp'; rm -rf"
                    f" $HOME/.devin-server/bin/{commit}; echo repaired")
                print("[FIX ] done. In Devin: click 'Reload Window'"
                      " (or reopen) - a fresh bundle will download"
                      " (~700 MB).")
                return 2
            else:
                print("       run again with --repair to fix (then"
                      " Reload Window in Devin)")
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "[math]::Round((Get-CimInstance Win32_OperatingSystem)"
         ".FreePhysicalMemory / 1MB, 1)"],
        capture_output=True, text=True)
    try:
        free_gb = float(r.stdout.strip())
    except ValueError:
        free_gb = -1
    if 0 <= free_gb < 2:
        warn.append(f"host memory low: {free_gb} GB free - memory"
                    " starvation can kill devin-server")
    if free_gb >= 0:
        print(f"[ OK ] host free memory: {free_gb} GB")
    for w in warn:
        print(f"[WARN] {w}")
    if not fail:
        print("=== HEALTHY ===")
        return 0
    print("=== UNHEALTHY ===")
    return 1


if __name__ == "__main__":
    sys.exit(main())
