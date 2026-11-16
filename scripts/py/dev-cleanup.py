"""Interactive dev environment cleanup (port of
scripts/dev-cleanup.ps1).

Sections: process cleanup (kills dev processes owned by the user),
temp/cache folders, disk-space recovery (recycle bin, event logs,
CLI cache clears, docker container logs), common dev-port cleanup,
WSL Ubuntu cleanup (apt/tmp/journald/docker prune + dev caches; more
with --aggressive), Cline extension caches, summary. Each section asks
for confirmation unless --yes is passed; --dry-run prints only.
"""

import argparse
import ctypes
import datetime
import glob
import os
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: dev, interactive, processes, cache, wsl, ports

LA = os.environ.get("LOCALAPPDATA", "")
AD = os.environ.get("APPDATA", "")
UP = os.environ.get("USERPROFILE", "")
TMP = os.environ.get("TEMP", "")
MB = 2**20

DEV_PROCESSES = [
    ("node", "Node.js processes"), ("npm", "npm processes"),
    ("yarn", "Yarn processes"), ("pnpm", "pnpm processes"),
    ("playwright", "Playwright processes"),
    ("chrome", "Chrome/Chromium (headless)"),
    ("msedge", "Edge (headless)"), ("webkit", "WebKit processes"),
    ("Code", "VS Code"), ("Code - Insiders", "VS Code Insiders"),
    ("electron", "Electron apps"), ("dotnet", ".NET processes"),
    ("java", "Java processes"), ("python", "Python processes"),
    ("docker", "Docker processes"),
]

CACHE_TARGETS = [
    (rf"{TMP}\*", "User TEMP folder", False),
    (rf"{LA}\Temp\*", "LocalAppData Temp", False),
    (r"C:\Windows\Temp\*", "System Temp (needs Admin)", True),
    (rf"{LA}\npm-cache\*", "npm cache", False),
    (rf"{LA}\Yarn\Cache\*", "Yarn cache", False),
    (rf"{LA}\pnpm\store\*", "pnpm store", False),
    (rf"{UP}\.nuget\packages\*", "NuGet packages cache", False),
    (rf"{UP}\.gradle\caches\*", "Gradle cache", False),
    (rf"{UP}\.cargo\registry\cache\*", "Cargo registry cache", False),
    (rf"{LA}\Google\Chrome\User Data\Default\Cache\*",
     "Chrome cache", False),
    (rf"{LA}\Google\Chrome\User Data\Default\Code Cache\*",
     "Chrome code cache", False),
    (rf"{LA}\Microsoft\Edge\User Data\Default\Cache\*",
     "Edge cache", False),
    (rf"{AD}\Mozilla\Firefox\Profiles\*\cache2\*",
     "Firefox cache", False),
    (rf"{LA}\Microsoft\VSCode\*\Cache\*", "VS Code cache", False),
    (rf"{LA}\Microsoft\VSCode\*\CachedData\*",
     "VS Code cached data", False),
    (rf"{LA}\Microsoft\VSCode Insiders\*\Cache\*",
     "VS Code Insiders cache", False),
    (rf"{LA}\Microsoft\VSCode Insiders\*\CachedData\*",
     "VS Code Insiders cached data", False),
    (rf"{AD}\Code\CachedData\*", "VS Code user cache", False),
    (rf"{AD}\Code - Insiders\CachedData\*",
     "VS Code Insiders user cache", False),
    (rf"{LA}\Microsoft\Windows\INetCache\*", "Windows INetCache",
     False),
]

COMMON_PORTS = [3000, 3001, 4200, 5000, 5173, 8000, 8080, 8081,
                8888, 9000, 9229, 9230]

WSL_COMMANDS = [
    ("apt-get clean -y 2>/dev/null", "apt clean"),
    ("apt-get autoclean -y 2>/dev/null", "apt autoclean"),
    ("apt-get autoremove -y 2>/dev/null", "apt autoremove"),
    ("rm -rf /tmp/* /var/tmp/* 2>/dev/null", "temp folders"),
    ("journalctl --vacuum-time=7d 2>/dev/null", "journald (7 days)"),
    ("docker system prune -f --volumes "
     "--filter 'label!=com.docker.desktop.service=model-runner' "
     "--filter 'label!=com.docker.model-runner.role=model-storage' "
     "2>/dev/null", "docker system prune"),
    ("npm cache clean --force 2>/dev/null", "npm cache"),
    ("pip cache purge 2>/dev/null", "pip cache"),
    ("yarn cache clean 2>/dev/null", "yarn cache"),
    ("pnpm store prune 2>/dev/null", "pnpm store"),
    ("cargo clean 2>/dev/null", "cargo cache"),
    ("go clean -cache 2>/dev/null", "go cache"),
    ("flatpak uninstall --unused -y 2>/dev/null", "flatpak unused"),
    ("snap list --all 2>/dev/null | "
     "awk '/disabled/{print $1}' | "
     "xargs -r snap remove 2>/dev/null",
     "snap disabled revisions"),
    ("rm -rf /home/*/.cache/pip /home/*/.cache/pipx 2>/dev/null",
     "pip user cache"),
    ("rm -rf /home/*/.cache/yarn /home/*/.cache/pnpm 2>/dev/null",
     "yarn/pnpm user cache"),
    ("rm -rf /home/*/.cache/pre-commit 2>/dev/null",
     "pre-commit cache"),
    ("rm -rf /home/*/.ccache 2>/dev/null", "ccache"),
    ("rm -rf /var/lib/apt/lists/* 2>/dev/null; "
     "apt-get update 2>/dev/null", "apt lists refresh"),
    ("rm -rf /home/*/.vscode-server/data/CachedData 2>/dev/null",
     "VS Code CachedData"),
    ("rm -rf /home/*/.vscode-server/data/User/workspaceStorage "
     "2>/dev/null", "VS Code workspaceStorage"),
    ("rm -rf /home/*/.vscode-server/data/logs 2>/dev/null",
     "VS Code logs"),
    ("rm -rf /home/*/.vscode-server/extensionsCache 2>/dev/null",
     "VS Code extensions cache"),
    ("rm -rf /home/*/.vscode-server/bin/*/node_modules 2>/dev/null",
     "VS Code server node_modules"),
    ("rm -rf /home/*/.cache/typescript 2>/dev/null",
     "TypeScript language server cache"),
    ("rm -rf /home/*/.cache/pylint 2>/dev/null", "pylint cache"),
    ("rm -rf /home/*/.cache/mypy 2>/dev/null", "mypy cache"),
    ("rm -rf /home/*/.cache/ruff 2>/dev/null", "ruff cache"),
    ("rm -rf /home/*/.cache/jedi 2>/dev/null", "jedi cache"),
    ("rm -rf /home/*/.cache/gopls 2>/dev/null", "gopls cache"),
    ("rm -rf /home/*/.cache/rust-analyzer 2>/dev/null",
     "rust-analyzer cache"),
    ("rm -rf /home/*/.cache/clangd 2>/dev/null", "clangd cache"),
    ("find /home -name '.git' -type d -execdir git -C {} gc "
     "--aggressive --prune=now \\; 2>/dev/null",
     "Git GC (aggressive)"),
]

WSL_AGGRESSIVE = [
    ("find /home -name 'node_modules' -type d -prune -exec rm -rf "
     "{} + 2>/dev/null",
     "node_modules (removes all, requires npm install)"),
    ("find /home -name 'dist' -o -name 'build' -o -name '.next' -o "
     "-name '.nuxt' -o -name 'target' -o -name '__pycache__' -o "
     "-name '*.pyc' -o -name '.pytest_cache' -o -name '.coverage' "
     "-o -name '.tox' -o -name '.mypy_cache' -o -name '.ruff_cache' "
     "| xargs -r rm -rf 2>/dev/null",
     "Build/test artifacts (dist, build, target, __pycache__, etc.)"),
    ("find /home -name '*~' -o -name '*.swp' -o -name '*.swo' -o "
     "-name '.#*' | xargs -r rm -f 2>/dev/null",
     "Editor temp files (~/.swp, *~)"),
]

CLINE_PATHS = [
    (rf"{AD}\Code\User\globalStorage\saoudrizwan.claude-dev\cache",
     "Cline cache"),
    (rf"{AD}\Code\User\globalStorage\saoudrizwan.claude-dev\state",
     "Cline state"),
    (rf"{AD}\Code\User\globalStorage\saoudrizwan.claude-dev\tasks",
     "Cline tasks"),
    (rf"{AD}\Code - Insiders\User\globalStorage\saoudrizwan."
     r"claude-dev\cache", "Cline cache (Insiders)"),
    (rf"{AD}\Code - Insiders\User\globalStorage\saoudrizwan."
     r"claude-dev\state", "Cline state (Insiders)"),
    (rf"{AD}\Code - Insiders\User\globalStorage\saoudrizwan."
     r"claude-dev\tasks", "Cline tasks (Insiders)"),
]

actions = []
mem_freed = 0.0
disk_freed = 0.0


def header(msg):
    print(f"\n=== {msg} ===")


def confirm(msg, args, default_yes=True):
    if args.yes:
        return True
    suffix = "[Y/n]" if default_yes else "[y/N]"
    r = input(f"\n{msg} {suffix} ").strip()
    return default_yes if not r else r.lower().startswith("y")


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def dir_size_mb(path):
    return sum(f.stat().st_size for f in Path(path).rglob("*")
               if f.is_file()) / MB if Path(path).is_dir() else 0


def clear_children(path, dry):
    p = Path(path)
    if not p.is_dir():
        return
    for c in p.iterdir():
        if dry:
            continue
        try:
            if c.is_dir():
                shutil.rmtree(c, ignore_errors=True)
            else:
                c.unlink()
        except OSError:
            pass


def run(cmd, dry):
    if dry:
        print(f"[dry-run] {' '.join(str(c) for c in cmd)}")
        return 0
    return subprocess.run([str(c) for c in cmd], capture_output=True,
                          text=True, errors="replace").returncode


def main() -> None:
    global mem_freed, disk_freed
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--yes", action="store_true",
                    help="answer yes to all confirmations")
    ap.add_argument("--aggressive", action="store_true",
                    help="also run aggressive WSL cleanup "
                    "(node_modules, build artifacts)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run
    start = datetime.datetime.now()

    # ─── Process cleanup ───
    header("Process Cleanup")
    user = os.environ.get("USERNAME", "").lower()
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "Get-Process | Select-Object Id,ProcessName,"
                        "WorkingSet64 | ConvertTo-Csv -NoType"],
                       capture_output=True, text=True,
                       errors="replace")
    found = {}
    for line in r.stdout.splitlines()[1:]:
        p = line.split(",")
        if len(p) < 3:
            continue
        name = p[1].strip('"')
        for proc_name, desc in DEV_PROCESSES:
            if name.lower() == proc_name.lower():
                try:
                    ws = int(p[2].strip('"').strip() or 0)
                except ValueError:
                    ws = 0
                pid_s = p[0].strip('"')
                if pid_s != str(os.getpid()):
                    found.setdefault((proc_name, desc),
                                     []).append((pid_s, ws))
    for (proc_name, desc), procs in found.items():
        total_mb = sum(ws for _, ws in procs) / MB
        print(f"  {desc:<35} count={len(procs)} "
              f"mem={total_mb:.1f} MB")
    if found and confirm("Kill these processes?", args):
        for (proc_name, desc), procs in found.items():
            for pid, ws in procs:
                run(["taskkill", "/PID", pid, "/F"], dry)
            mem_freed += sum(ws for _, ws in procs) / MB
            actions.append(f"Killed {len(procs)} {desc}")
            print(f"  [OK] Killed {len(procs)} {desc}")
    elif not found:
        print("  [OK] No orphaned development processes found")

    # ─── Temp/Cache cleanup ───
    header("Temp & Cache Cleanup")
    if confirm("Clear temp and cache folders?", args):
        for pattern, desc, needs_admin in CACHE_TARGETS:
            if needs_admin and not is_admin():
                print(f"  [WARN] Skipping {desc} (requires Admin)")
                continue
            matches = [m for m in glob.glob(pattern)
                       if Path(m).exists()]
            if not matches:
                continue
            size = sum(dir_size_mb(m) for m in matches)
            if size > 0:
                for match in matches:
                    clear_children(match, dry)
                    if Path(match).is_file() and not dry:
                        try:
                            Path(match).unlink()
                        except OSError:
                            pass
                disk_freed += size
                actions.append(f"Cleared {desc} ({size:.2f} MB)")
                print(f"  [OK] Cleared {desc} ({size:.2f} MB)")
            else:
                print(f"  [INFO] {desc} already empty")

    # ─── Disk space recovery ───
    header("Disk Space Recovery")
    if confirm("Run disk space recovery operations?", args):
        rb = dir_size_mb(r"C:\$Recycle.Bin")
        run(["powershell", "-NoProfile", "-Command",
             "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"],
            dry)
        disk_freed += rb
        actions.append(f"Emptied Recycle Bin ({rb:.2f} MB)")
        run(["powershell", "-NoProfile", "-Command",
             "wevtutil el | % { wevtutil cl $_ 2>$null }"], dry)
        actions.append("Cleared Windows Event Logs")
        for tool, cargs, desc in (
                ("npm", ["cache", "clean", "--force"], "npm cache"),
                ("dotnet", ["nuget", "locals", "all", "--clear"],
                 "NuGet cache"),
                ("cargo", ["clean"], "Cargo cache")):
            if shutil.which(tool):
                run([tool, *cargs], dry)
                actions.append(f"Cleared {desc} (via CLI)")
        dc = Path(rf"{UP}\AppData\Local\Docker\containers")
        if dc.is_dir():
            s = dir_size_mb(dc)
            clear_children(dc, dry)
            disk_freed += s
            actions.append(f"Docker container logs ({s:.2f} MB)")

    # ─── Port cleanup ───
    header("Port Cleanup (Common Dev Ports)")
    listeners = []
    if not dry:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "Get-NetTCPConnection -State Listen -ErrorAction "
             "SilentlyContinue | Select-Object LocalPort,OwningProcess"
             " | ConvertTo-Csv -NoType"], capture_output=True,
            text=True, errors="replace")
        by_port = {}
        for line in r.stdout.splitlines()[1:]:
            p = line.split(",")
            if len(p) >= 2:
                try:
                    port = int(p[0].strip('"'))
                    pid = int(p[1].strip('"'))
                except ValueError:
                    continue
                if port in COMMON_PORTS:
                    by_port.setdefault(port, pid)
        for port, pid in sorted(by_port.items()):
            listeners.append((port, pid))
            print(f"  port {port}: PID {pid}")
    if listeners and confirm(
            "Kill processes on these ports?", args):
        for port, pid in listeners:
            run(["taskkill", "/PID", str(pid), "/F"], dry)
            actions.append(f"Freed port {port} (PID {pid})")
            print(f"  [OK] Freed port {port}")
    elif not listeners:
        print("  [OK] No processes on common dev ports")

    # ─── WSL cleanup ───
    header("WSL (Ubuntu) Cleanup")
    try:
        r = subprocess.run(["wsl", "-l", "-q"],
                           capture_output=True, text=True,
                           errors="replace")
    except OSError:
        r = None
    distros = [] if r is None else [
        d.replace("\0", "").strip()
        for d in r.stdout.splitlines()]
    distros = [d for d in distros if d and d != "docker-desktop"
               and "data" not in d]
    if distros:
        cmds = WSL_COMMANDS + (WSL_AGGRESSIVE if args.aggressive
                               else [])
        if confirm(f"Run WSL cleanup on {distros}?", args):
            for distro in distros:
                print(f"  -- {distro} --")
                for cmd, desc in cmds:
                    if dry:
                        print(f"  [dry-run] wsl -d {distro} "
                              f"bash -c {cmd}")
                    else:
                        subprocess.run(
                            ["wsl", "-d", distro, "-e", "bash", "-c",
                             cmd], capture_output=True)
                        print(f"  [OK] {desc}")
            actions.append(f"WSL cleanup on {len(distros)} distro(s)")
    else:
        print("  [INFO] No WSL distros found")

    # ─── Cline extension cleanup ───
    header("Cline Extension Cleanup")
    for path, desc in CLINE_PATHS:
        if not Path(path).is_dir():
            continue
        s = dir_size_mb(path)
        if s > 0:
            clear_children(path, dry)
            disk_freed += s
            actions.append(f"Cleared {desc} ({s:.2f} MB)")
            print(f"  [OK] Cleared {desc} ({s:.2f} MB)")
        else:
            print(f"  [INFO] {desc} already empty")

    # ─── Summary ───
    header("Summary")
    elapsed = (datetime.datetime.now() - start).total_seconds()
    print(f"  Memory freed      : {mem_freed:.1f} MB")
    print(f"  Disk space freed  : {disk_freed:.1f} MB")
    print(f"  Duration          : {elapsed:.0f} seconds")
    if actions:
        print("\nActions performed:")
        for a in actions:
            print(f"  * {a}")
    else:
        print("  [INFO] No cleanup actions performed")
    for letter in ("C:\\", "D:\\", "E:\\"):
        try:
            u = shutil.disk_usage(letter)
            print(f"  {letter[0]}: free {u.free / 2**30:.2f} GB "
                  f"({u.used / (u.used + u.free) * 100:.1f}% used)")
        except OSError:
            pass
    print("\n[OK] Dev cleanup complete!")


if __name__ == "__main__":
    main()
