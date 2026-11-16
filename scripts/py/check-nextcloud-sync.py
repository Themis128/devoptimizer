"""NextCloud sync health check (Python port of check-nextcloud-sync.ps1).

Read-only: client version/running state, server URL + sync root + VFS mode,
journal size, newest client logs (gz-aware) error/warning counts, bounded
conflict audit, Defender exclusion + cldflt driver, latest release via
GitHub API. --backup-config copies %APPDATA%\\NextCloud (minus rotating
logs) to backups\\nextcloud-config\\<ts> keeping newest 5.
"""

import argparse
import gzip
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

# CATEGORY: utilities
# TAGS: nextcloud, sync, health, monitoring

ROOT = Path(r"D:\DevOptimizer")


def cfg_value(cfg: list[str], key: str) -> str | None:
    for line in cfg:
        m = re.match(rf"^.*?0\\{key}=", line) or re.match(rf"^{key}=", line)
        if m:
            return line[m.end():].strip()
    for line in cfg:
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip()
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--backup-config", action="store_true")
    parser.add_argument("--keep-backups", type=int, default=5)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    out: dict = {}
    appdata = Path(os.environ.get("APPDATA", ""))

    # 1. client
    exe = Path(os.environ.get("PROGRAMFILES", r"C:\Program Files")) / \
        r"Nextcloud\nextcloud.exe"
    ver = exe.exists() and "found" or "NOT FOUND"
    proc = subprocess.run(["tasklist", "/FI", "IMAGENAME eq nextcloud.exe",
                           "/FO", "CSV", "/NH"],
                          capture_output=True, text=True, timeout=30)
    running = "nextcloud" in proc.stdout.lower()
    out["client"] = {"exe": str(exe), "installed": exe.exists(),
                     "running": running}
    print(f"[1] Client: {'found' if exe.exists() else 'NOT FOUND'} "
          f"({'running' if running else 'not running'})")

    # 2. cfg
    cfg_path = appdata / r"Nextcloud\nextcloud.cfg"
    server = sync_root = vfs = None
    if cfg_path.exists():
        lines = cfg_path.read_text(errors="replace").splitlines()
        server = cfg_value(lines, "url")
        sync_root = cfg_value(lines, "localPath")
        vfs = cfg_value(lines, "virtualFilesMode")
    sync_root = (sync_root or str(Path(os.environ.get("USERPROFILE", "")) / "Nextcloud")).rstrip("/")
    out["config"] = {"server": server, "syncRoot": sync_root, "vfs": vfs}
    print(f"    Server: {server}  Folder: {sync_root} (vfs: {vfs})")

    # 3. journal
    j = next((p for p in Path(sync_root).glob(".sync_*.db") if p.is_file()), None)
    if j:
        wal = j.with_name(j.name + "-wal")
        out["journalMB"] = {"db": round(j.stat().st_size / 1_048_576, 2),
                            "wal": round(wal.stat().st_size / 1_048_576, 2)
                            if wal.exists() else 0}
        print(f"[2] Journal: {out['journalMB']['db']} MB db + "
              f"{out['journalMB']['wal']} MB wal")
    else:
        print("[2] Journal: not found")

    # 4. recent logs
    log_dir = appdata / r"Nextcloud\logs"
    errs = warns = scanned = 0
    if log_dir.exists():
        logs = sorted(log_dir.glob("*"), key=lambda p: p.stat().st_mtime,
                      reverse=True)[:3]
        for l in logs:
            try:
                if l.suffix == ".gz":
                    text = gzip.open(l, "rt", errors="replace").read(2_000_000)
                else:
                    text = l.read_text(errors="replace")[:2_000_000]
                scanned += 1
                errs += len(re.findall(r"\bERROR\b", text))
                warns += len(re.findall(r"\bWARNING\b", text))
            except OSError:
                continue
    out["logs"] = {"scanned": scanned, "errors": errs, "warnings": warns}
    print(f"[3] Logs: {scanned} newest, {errs} errors, {errs and '' or ''}{warns} warnings")

    # 5. bounded conflict audit (time-capped 15s)
    conflicts = []
    deadline = time.time() + 15
    for dirpath, _dirs, files in os.walk(sync_root):
        if time.time() > deadline:
            break
        for f in files:
            if "(conflicted copy" in f:
                conflicts.append(str(Path(dirpath) / f))
    out["conflicts"] = conflicts
    print(f"[4] Conflicts: {len(conflicts)}")

    # 6. defender exclusion + cldflt + latest release
    defr = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "(Get-MpPreference).ExclusionPath -contains "
         f"'{sync_root}'"],
        capture_output=True, text=True, timeout=30)
    out["defenderExcluded"] = "True" in defr.stdout
    cld = subprocess.run(["sc", "query", "cldflt"], capture_output=True,
                         text=True, timeout=15)
    out["cldflt"] = "RUNNING" in cld.stdout
    try:
        rel = json.loads(urllib.request.urlopen(
            "https://api.github.com/repos/nextcloud/desktop/releases/latest",
            timeout=10).read())
        out["latestRelease"] = rel.get("tag_name")
    except Exception:
        out["latestRelease"] = None
    print(f"[5] Defender exclusion: {out['defenderExcluded']}  "
          f"cldflt running: {out['cldflt']}  latest: {out['latestRelease']}")

    # optional config backup
    if args.backup_config:
        src = appdata / "NextCloud"
        if src.exists():
            dst = ROOT / "backups" / f"nextcloud-config/{time.strftime('%Y%m%d-%H%M%S')}"
            dst.mkdir(parents=True, exist_ok=True)
            for item in src.iterdir():
                if item.name.startswith("logs"):
                    continue
                if item.is_dir():
                    shutil.copytree(item, dst / item.name, dirs_exist_ok=True)
                else:
                    shutil.copy2(item, dst / item.name)
            # prune to newest N
            backs = sorted((ROOT / "backups" / "nextcloud-config").iterdir())
            for old in backs[:-args.keep_backups]:
                shutil.rmtree(old, ignore_errors=True)
            out["backup"] = str(dst)
            print(f"[B] Config backed up to {dst} (kept newest {args.keep_backups})")

    if args.json:
        print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
