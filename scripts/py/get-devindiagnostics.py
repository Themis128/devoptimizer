"""Port of scripts/devin/Get-DevinDiagnostics.ps1 — read-only deep
diagnostics for Devin Desktop's WSL remote. Optional --out-file JSON.
Exit 1 when the distro is unreachable.
"""
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

DISTRO = "Ubuntu-24.04"
report = {"generated": datetime.datetime.now().isoformat(),
          "distro": DISTRO, "app": {}, "wsl": {}, "server": {},
          "logs": {}, "memory": {}, "findings": []}


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


def finding(level, msg):
    report["findings"].append({"level": level, "message": msg})


def main():
    out_file = None
    for i, a in enumerate(sys.argv):
        if a == "--out-file" and i + 1 < len(sys.argv):
            out_file = sys.argv[i + 1]

    print(f"=== Devin Diagnostics ({DISTRO}, read-only) ===")
    app_exe = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" \
        / "Devin" / "Devin.exe"
    if app_exe.exists():
        r = subprocess.run(["powershell", "-NoProfile", "-Command",
                            "(Get-Item '" + str(app_exe)
                            + "').VersionInfo.ProductVersion"],
                           capture_output=True, text=True)
        ver = r.stdout.strip() or None
        report["app"]["exePath"] = str(app_exe)
        report["app"]["version"] = ver
        print(f"[ OK ] Devin Desktop app version: {ver}")
    else:
        report["app"]["version"] = None
        finding("warn", f"Devin.exe not found at {app_exe} - app"
                " may not be installed")
        print(f"[WARN] Devin.exe not found at {app_exe}")

    if "ok" not in " ".join(wsl("echo ok")):
        print(f"[FAIL] WSL distro '{DISTRO}' unreachable - the"
              " disease is usually the WSL VM, not Devin.")
        print(f"       Check WSL FIRST (wsl -d {DISTRO} --exec true,"
              " Docker VM state, vmmemWSL memory) before touching"
              " Devin.")
        report["wsl"]["reachable"] = False
        if out_file:
            Path(out_file).write_text(json.dumps(report, indent=2),
                                      encoding="utf-8")
            print(f"[ OK ] JSON report written to {out_file}")
        return 1
    report["wsl"]["reachable"] = True
    print("[ OK ] WSL distro reachable")

    up_lines = wsl("cat /proc/uptime")
    try:
        up = float(up_lines[0].split()[0]) if up_lines else None
    except (IndexError, ValueError):
        up = None
    report["wsl"]["uptimeSeconds"] = up
    if up is not None:
        ts = str(datetime.timedelta(seconds=int(up)))
        print(f"[ OK ] WSL uptime: {ts}")
        if up < 180:
            finding("warn", f"WSL booted {int(up)}s ago - Devin may"
                    " race the boot; Reload Window once WSL is up")
    else:
        finding("warn", "could not read WSL uptime")

    freeh = wsl("free -h | sed -n 2p")
    report["memory"]["guest"] = re.sub(r"\s+", " ", freeh[0]).strip() \
        if freeh else None
    print(f"[ OK ] guest memory: {report['memory']['guest']}")

    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "Get-CimInstance Win32_OperatingSystem |"
                        " Select-Object -Expand FreePhysicalMemory"],
                       capture_output=True, text=True)
    try:
        free_gb = round(int(r.stdout.strip()) / 1048576, 1)
    except ValueError:
        free_gb = None
    report["memory"]["hostFreeGB"] = free_gb
    print(f"[ OK ] host free memory: {free_gb} GB")
    if free_gb is not None and free_gb < 2:
        finding("warn", f"host memory low: {free_gb} GB free -"
                " starvation can kill devin-server")

    procs = wsl("pgrep -af 'devin acp' || true")
    commit = None
    m = re.search(r"\.devin-server/bin/([a-f0-9]{40})/",
                  "\n".join(procs))
    if m:
        commit = m.group(1)
        report["server"]["running"] = True
        report["server"]["commit"] = commit
        print(f"[ OK ] devin-server running (commit {commit})")
    else:
        report["server"]["running"] = False
        finding("warn", "devin-server not running - if Devin shows"
                " 'Cannot reconnect', click Reload Window")
        print("[WARN] devin-server not running in WSL")

    if commit:
        base = f"$HOME/.devin-server/bin/{commit}/node_modules"
        check = wsl(f"test -d {base}/minimist -a -d {base}/@vscode"
                    " && echo intact || echo broken")
        intact = "intact" in check
        report["server"]["bundleIntact"] = intact
        if intact:
            print("[ OK ] server bundle intact (minimist + @vscode"
                  " present)")
        else:
            finding("fail", f"server bundle CORRUPT for commit"
                    f" {commit} - run repair-devin --fix-bundle"
                    " (or check-devinhealth --repair), then Reload"
                    " Window")
            print("[FAIL] server bundle CORRUPT - classic"
                  " ERR_MODULE_NOT_FOUND crash loop incoming")

    bin_dirs = [d for d in wsl(
        "ls -1 $HOME/.devin-server/bin/ 2>/dev/null || true")
        if re.match(r"^[a-f0-9]{40}$", d)]
    report["server"]["commitDirs"] = bin_dirs
    print(f"[ OK ] commit dirs in bin/: {len(bin_dirs)}")
    superseded = [d for d in bin_dirs if d != commit]
    if superseded:
        report["server"]["supersededDirs"] = superseded
        finding("warn", "superseded commit dirs present (safe to"
                " clean with repair-devin --clean-leftovers):"
                f" {', '.join(superseded)}")
        print(f"[WARN] superseded commit dirs:"
              f" {', '.join(superseded)}")

    ext = wsl("ls -1 ~/.devin-server/extensions 2>/dev/null | wc -l")
    try:
        ext_count = int(ext[0])
    except (IndexError, ValueError):
        ext_count = 0
    report["server"]["extensionEntries"] = ext_count
    print(f"[ OK ] extensions dir entries: {ext_count}")

    ls = wsl("du -sh ~/.devin-server/data/logs 2>/dev/null | cut -f1")
    log_size = ls[0].strip() if ls else None
    report["server"]["dataLogsSize"] = log_size
    print(f"[ OK ] ~/.devin-server/data/logs size: {log_size}")

    logs_root = Path(os.environ.get("APPDATA", "")) / "Devin" / "logs"
    patterns = ["ERR_MODULE_NOT_FOUND", "terminated unexpectedly"]
    renderer = {"file": None, "session": None, "counts": {}}
    strays = 0
    newest = None
    session_dirs = sorted(
        [d for d in logs_root.glob("*") if d.is_dir()
         and re.match(r"^\d{8}T\d{6}$", d.name)],
        key=lambda d: d.name, reverse=True) if logs_root.exists() \
        else []
    for d in session_dirs:
        if list(d.rglob("*.log")):
            newest = d
            break
        strays += 1
    if newest:
        if strays:
            print(f"[ OK ] skipped {strays} empty stray session"
                  " dir(s) (window-relaunch artifacts)")
        renderer["session"] = newest.name
        rlog = newest / "window1" / "renderer.log"
        if rlog.exists():
            renderer["file"] = str(rlog)
            text = rlog.read_text(encoding="utf-8", errors="replace")
            for p in patterns:
                hits = [l for l in text.splitlines() if p in l]
                renderer["counts"][p] = len(hits)
                if hits:
                    print(f"[WARN] renderer.log: {p} x{len(hits)};"
                          f" last: {hits[-1].strip()}")
            if not any(renderer["counts"].values()):
                print("[ OK ] renderer.log clean (no known error"
                      " signatures)")
        else:
            print(f"[WARN] renderer.log not found in newest session"
                  f" {newest.name}")
    elif session_dirs:
        print(f"[WARN] all {len(session_dirs)} Devin session dir(s)"
              f" under {logs_root} are empty (strays)")
    else:
        print(f"[WARN] no Devin session log dirs under {logs_root}")
    report["logs"]["renderer"] = renderer

    server_log = {"file": None, "counts": {}}
    if commit:
        slog = wsl(f"ls ~/.devin-server/.{commit}.log 2>/dev/null"
                   " || true")
        if any(".log" in l for l in slog):
            server_log["file"] = f"~/.devin-server/.{commit}.log"
            for p in ("ERR_MODULE_NOT_FOUND", "exited with code"):
                raw = wsl(f"grep -c '{p}' ~/.devin-server/.{commit}.log"
                          " 2>/dev/null || true")
                nums = [l for l in raw if re.match(r"^\d+$", l)]
                cnt = int(nums[-1]) if nums else 0
                server_log["counts"][p] = cnt
                if cnt:
                    print(f"[WARN] server log: {p} x{cnt}")
            if not any(server_log["counts"].values()):
                print("[ OK ] server log clean (no known error"
                      " signatures)")
    report["logs"]["server"] = server_log

    if not report["findings"]:
        print("=== DIAGNOSTICS COMPLETE - NO FINDINGS ===")
    else:
        print(f"=== DIAGNOSTICS COMPLETE -"
              f" {len(report['findings'])} finding(s) ===")
        for f in report["findings"]:
            print(f"[{f['level'].upper()}] {f['message']}")
    if out_file:
        Path(out_file).write_text(json.dumps(report, indent=2),
                                  encoding="utf-8")
        print(f"[ OK ] JSON report written to {out_file}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
