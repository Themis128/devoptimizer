"""Extended user-level cleanup (port of scripts/extended-cleanup.ps1).

Sections: [1] NVIDIA/D3D shader caches, [2] HuggingFace blobs
(ollama report-only), [3] Chrome/Edge caches (skipped while browser
runs), [4] VS Code caches + stale workspaceStorage (skipped while
Code runs), [5] Discord/Slack/Spotify caches, [6] user WER archives,
[7] DevOptimizer log rotation (old -> archive, ancient deleted).
Per-file age pruning; --dry-run.
"""

import argparse
import datetime
import os
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: extended, cache, logs, electron, browser, vscode

LA = os.environ.get("LOCALAPPDATA", "")
AD = os.environ.get("APPDATA", "")
UP = os.environ.get("USERPROFILE", "")
MB = 2**20
GB = 2**30


def prune(path, days, dry):
    """Delete files under path older than days; return freed bytes."""
    p = Path(path)
    freed = 0
    if not p.is_dir():
        return 0
    cutoff = (datetime.datetime.now() -
              datetime.timedelta(days=days)).timestamp()
    for f in p.rglob("*"):
        try:
            if f.is_file() and f.stat().st_mtime < cutoff:
                freed += f.stat().st_size
                if not dry:
                    f.unlink(missing_ok=True)
        except OSError:
            pass
    return freed


def proc_running(names):
    r = subprocess.run(["tasklist"], capture_output=True, text=True,
                       errors="replace")
    out = r.stdout.lower()
    return any(n.lower() in out for n in names)


def chromium_dirs(root):
    rp = Path(root)
    profiles = ([rp / "Default"] +
                [d for d in rp.glob("Profile *") if d.is_dir()])
    for prof in profiles:
        for sub in ("Cache", "Code Cache", "GPUCache",
                    r"Service Worker\CacheStorage",
                    r"Service Worker\ScriptCache"):
            yield prof / sub


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--shader-days", type=int, default=30)
    ap.add_argument("--model-days", type=int, default=60)
    ap.add_argument("--browser-days", type=int, default=7)
    ap.add_argument("--code-days", type=int, default=30)
    ap.add_argument("--electron-days", type=int, default=14)
    ap.add_argument("--wer-days", type=int, default=30)
    ap.add_argument("--log-days", type=int, default=30)
    ap.add_argument("--archive-days", type=int, default=180)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run
    total = 0

    print("\n=== [1] GPU shader caches ===")
    for d in (rf"{LA}\NVIDIA\DXCache", rf"{LA}\NVIDIA\GLCache",
              rf"{LA}\NVIDIA Corporation\NV_Cache",
              rf"{LA}\D3DSCache"):
        s = prune(d, args.shader_days, dry)
        total += s
        print(f"  {Path(d).name:<40}: -{s / MB:.1f} MB")

    print("\n=== [2] AI model caches ===")
    s = prune(rf"{UP}\.cache\huggingface", args.model_days, dry)
    total += s
    print(f"  HuggingFace blobs >{args.model_days}d: -{s / MB:.1f} MB")
    oll = Path(rf"{UP}\.ollama\models")
    if oll.is_dir():
        sz = sum(f.stat().st_size for f in oll.rglob("*")
                 if f.is_file())
        print(f"  [INFO] Ollama models: {sz / GB:.2f} GB - NOT touched "
              "(delete manually via 'ollama rm')")

    print("\n=== [3] Browser caches ===")
    for name, root, proc in (
            ("Chrome", rf"{LA}\Google\Chrome\User Data", ["chrome"]),
            ("Edge", rf"{LA}\Microsoft\Edge\User Data", ["msedge"])):
        if not Path(root).is_dir():
            continue
        if proc_running(proc):
            print(f"  [WARN] {name}: running - skipped")
            continue
        bf = sum(prune(d, args.browser_days, dry)
                 for d in chromium_dirs(root))
        total += bf
        print(f"  {name:<40}: -{bf / MB:.1f} MB")

    print("\n=== [4] VS Code caches ===")
    code_root = Path(rf"{AD}\Code")
    if code_root.is_dir():
        if proc_running(["Code"]):
            print("  [WARN] VS Code running - skipped")
        else:
            cf = sum(prune(code_root / sub, args.code_days, dry)
                     for sub in ("Cache", "CachedData", "Code Cache",
                                 "GPUCache", "CachedExtensionVSIXs",
                                 "logs"))
            ws = code_root / "User" / "workspaceStorage"
            cutoff = (datetime.datetime.now() -
                      datetime.timedelta(
                          days=args.code_days)).timestamp()
            for d in ws.glob("*") if ws.is_dir() else []:
                try:
                    if d.is_dir() and d.stat().st_mtime < cutoff:
                        cf += sum(f.stat().st_size
                                  for f in d.rglob("*") if f.is_file())
                        if not dry:
                            shutil.rmtree(d, ignore_errors=True)
                except OSError:
                    pass
            total += cf
            print(f"  VS Code (>{args.code_days}d, incl. "
                  f"workspaceStorage): -{cf / MB:.1f} MB")
    else:
        print("  [INFO] VS Code not installed - skipped")

    print("\n=== [5] Electron app caches ===")
    for name, root, extra in (
            ("Discord", rf"{AD}\discord", ()),
            ("Slack", rf"{AD}\Slack", ()),
            ("Spotify", rf"{AD}\Spotify", ("Storage",))):
        rp = Path(root)
        if not rp.is_dir():
            continue
        af = sum(prune(rp / sub, args.electron_days, dry)
                 for sub in ("Cache", "Code Cache", "GPUCache") + extra)
        total += af
        print(f"  {name:<40}: -{af / MB:.1f} MB")

    print("\n=== [6] WER archives (user) ===")
    wf = sum(prune(d, args.wer_days, dry) for d in
             (rf"{LA}\Microsoft\Windows\WER\ReportArchive",
              rf"{LA}\Microsoft\Windows\WER\ReportQueue"))
    total += wf
    print(f"  WER reports >{args.wer_days}d: -{wf / MB:.1f} MB")

    print("\n=== [7] DevOptimizer log rotation ===")
    log_dir = Path(r"D:\DevOptimizer\logs")
    if log_dir.is_dir():
        archive = log_dir / "archive"
        cutoff = (datetime.datetime.now() -
                  datetime.timedelta(days=args.log_days)).timestamp()
        stale = [f for f in log_dir.rglob("*")
                 if f.is_file()
                 and not str(f).startswith(str(archive))
                 and f.stat().st_mtime < cutoff]
        lf = sum(f.stat().st_size for f in stale)
        if not dry:
            archive.mkdir(exist_ok=True)
            for f in stale:
                try:
                    shutil.move(str(f), str(archive / f.name))
                except OSError:
                    pass
        acut = (datetime.datetime.now() -
                datetime.timedelta(
                    days=args.archive_days)).timestamp()
        dead = [f for f in archive.glob("*")
                if f.is_file() and f.stat().st_mtime < acut]
        df = sum(f.stat().st_size for f in dead)
        if not dry:
            for f in dead:
                f.unlink(missing_ok=True)
        print(f"  logs archived: -{lf / MB:.1f} MB, "
              f"archive purged: -{df / MB:.1f} MB")
        total += lf + df
    else:
        print("  [INFO] no logs dir - skipped")

    print(f"\n=== Total freed: {total / MB:.1f} MB "
          f"({'dry-run' if dry else 'applied'}) ===")


if __name__ == "__main__":
    main()
