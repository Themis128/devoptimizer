"""Port of scripts/devin/Check-DevinHealth.ps1.

Devin Desktop WSL-remote health check: distro reachable,
boot-age race advisory, devin-server process + commit,
bundle integrity (corrupt node_modules), host free memory.
-Repair kills devin-server and deletes the corrupt commit
dir so Reload Window re-downloads the bundle.
Exit: 0 healthy, 1 problems, 2 repaired.
"""

import argparse
import re
import subprocess
import sys

DISTRO = "Ubuntu-24.04"


def wsl(cmd):
    r = subprocess.run(["wsl.exe", "-d", DISTRO, "--",
                        "bash", "-c", cmd],
                       capture_output=True, text=True)
    if r.returncode != 0:
        r = subprocess.run(["wsl.exe", "-d", DISTRO,
                            "--exec", cmd],
                           capture_output=True, text=True)
    out = ((r.stdout or "") + (r.stderr or ""))
    out = out.replace("\x00", "")
    return [x for x in re.split(r"\r?\n", out) if x]


def ps(cmd):
    r = subprocess.run(["powershell", "-NoProfile",
                        "-Command", cmd],
                       capture_output=True, text=True)
    return (r.stdout or "").strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Repair", action="store_true")
    a = ap.parse_args()
    fail, warn = [], []

    print(f"=== Devin WSL-Remote Health ({DISTRO}) ===")

    ping = wsl("echo ok")
    if not any("ok" in x for x in ping):
        print(f"[FAIL] WSL distro '{DISTRO}' unreachable - "
              f"start WSL first: wsl -d {DISTRO} --exec true")
        return 1
    print("[ OK ] WSL distro reachable")

    up = wsl("cat /proc/uptime")
    try:
        secs = float(up[0].split()[0])
        if secs < 180:
            warn.append(
                f"WSL booted {int(secs)}s ago - Devin may "
                "race the boot; if a popup appeared, "
                "Reload Window once WSL is up")
        h, rem = divmod(int(secs), 3600)
        m, s = divmod(rem, 60)
        print(f"[ OK ] WSL uptime: {h}h {m}m {s}s")
    except (IndexError, ValueError):
        warn.append("could not read WSL uptime")

    procs = wsl("pgrep -af 'devin acp' || true")
    commit = None
    for line in procs:
        m = re.search(
            r"\.devin-server/bin/([a-f0-9]{40})/", line)
        if m:
            commit = m.group(1)
            break
    if commit:
        print(f"[ OK ] devin-server running "
              f"(commit {commit})")
    else:
        warn.append("devin-server not running - if Devin "
                    "shows 'Cannot reconnect', click "
                    "Reload Window")
        print("[WARN] devin-server not running in WSL")

    if commit:
        base = f"$HOME/.devin-server/bin/{commit}/node_modules"
        chk = wsl(f"test -d {base}/minimist -a -d "
                  f"{base}/@vscode && echo intact || "
                  "echo broken")
        if any("intact" in x for x in chk):
            print("[ OK ] server bundle intact (minimist "
                  "+ @vscode present)")
        else:
            print("[FAIL] server bundle CORRUPT - "
                  "node_modules truncated (classic "
                  "ERR_MODULE_NOT_FOUND crash loop)")
            fail.append(f"bundle corrupt: {commit}")
            if a.Repair:
                print("[FIX ] killing server and deleting "
                      "corrupt commit dir...")
                wsl("pkill -f 'devin acp'; rm -rf "
                    f"$HOME/.devin-server/bin/{commit}; "
                    "echo repaired")
                print("[FIX ] done. In Devin: click "
                      "'Reload Window' (or reopen) - a "
                      "fresh bundle will download "
                      "(~700 MB).")
                return 2
            else:
                print("       run again with -Repair to "
                      "fix (then Reload Window in Devin)")

    free = ps("(Get-CimInstance Win32_OperatingSystem)."
              "FreePhysicalMemory / 1MB")
    try:
        free_gb = round(float(free), 1)
        if free_gb < 2:
            warn.append(
                f"host memory low: {free_gb} GB free - "
                "memory starvation can kill devin-server")
        print(f"[ OK ] host free memory: {free_gb} GB")
    except ValueError:
        warn.append("could not read host memory")

    for w in warn:
        print(f"[WARN] {w}")
    if not fail:
        print("=== HEALTHY ===")
        return 0
    print(f"=== PROBLEMS: {'; '.join(fail)} ===")
    return 1


if __name__ == "__main__":
    sys.exit(main())
