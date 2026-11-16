"""Port of tools/Variants/CURSOR-AI-GIT-CACHE-CLEAR-__VAR__.bat —
8-step git cache clear (gc --prune=now, reset --hard, stash clear,
reflog expire, remote prune, lfs prune, worktree prune, config
unsets) plus admin-level cache clears (Cursor/Code caches, npm/yarn, TEMP, Chrome).
"""
# REQUIRES: admin
import ctypes
import os

def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required", file=sys.stderr)
        sys.exit(1)

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


def step(n, label, cmd):
    print(f"[{n}] {label}")
    try:
        rc = subprocess.run(cmd).returncode
        print("[SUCCESS]" if rc == 0 else f"[WARNING] rc={rc}")
    except FileNotFoundError:
        print(f"[WARNING] not found: {cmd[0]}")


GIT_STEPS = [
    ("Git garbage collection",
     ["git", "gc", "--prune=now"]),
    ("Clearing Git index", ["git", "reset", "--hard", "HEAD"]),
    ("Clearing Git stash", ["git", "stash", "clear"]),
    ("Clearing Git reflog",
     ["git", "reflog", "expire", "--expire=now", "--all"]),
    ("Clearing Git remote cache",
     ["git", "remote", "prune", "origin"]),
    ("Clearing Git LFS cache", ["git", "lfs", "prune"]),
    ("Clearing Git worktree cache", ["git", "worktree", "prune"]),
    ("Clearing Git config cache",
     ["git", "config", "--global", "--unset-all",
      "core.preloadindex"]),
]


def rmdirs(paths):
    for p in paths:
        p = Path(p)
        if p.exists():
            shutil.rmtree(p, ignore_errors=True)
            print(f"[INFO] cleared {p}")


def main():
    _ensure_admin()
    ap = argparse.ArgumentParser(
        description="Cursor AI git cache clear")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.dry_run:
        print("[dry-run] 8 git steps + cache clears")
        return 0
    for i, (label, cmd) in enumerate(GIT_STEPS, 1):
        step(f"{i}/8", label, cmd)
    for key in ("core.fscache", "core.untrackedCache"):
        subprocess.run(["git", "config", "--global",
                        "--unset-all", key])

    # Admin-only: editor caches, package-manager caches, TEMP,
    # browser cache
    appdata = os.environ.get("APPDATA", "")
    local = os.environ.get("LOCALAPPDATA", "")
    for app in ("Cursor", "Code"):
        for d in ("CachedData", "logs", "CachedExtensions"):
            rmdirs([Path(appdata) / app / d])
    rmdirs([Path(appdata) / "npm-cache"])
    step("-", "yarn cache clean", ["yarn", "cache", "clean"])
    tmp = Path(os.environ.get("TEMP", ""))
    if tmp.is_dir():
        for child in tmp.iterdir():
            try:
                if child.is_dir():
                    shutil.rmtree(child, ignore_errors=True)
                else:
                    child.unlink(missing_ok=True)
            except OSError:
                pass
    rmdirs([Path(local) / "Google" / "Chrome" / "User Data"
            / "Default" / "Cache"])

    return 0


if __name__ == "__main__":
    sys.exit(main())
