"""Win11 safe cleanup (port of scripts/win11-safe-cleanup.ps1).

Non-admin-safe passes: user+Windows temp, package-manager caches
(npm/pip/pnpm/yarn + NuGet), INetCache/CrashDumps, recycle bin, docker
builder+dangling prune. Admin items reported only. --dry-run.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# CATEGORY: cleanup
# TAGS: windows11, safe, temp, caches, docker


def mb(b):
    return round(b / 2**20, 1)


def free_c():
    return shutil.disk_usage("C:\\").free


def dir_size(path):
    total = 0
    for f in Path(path).rglob("*"):
        try:
            if f.is_file():
                total += f.stat().st_size
        except OSError:
            pass
    return total


def clear(path, dry):
    p = Path(path)
    if dry:
        print(f"[dry-run] clear {p}")
        return 0
    if not p.exists():
        return -1
    size = dir_size(p)
    for f in p.iterdir():
        try:
            if f.is_dir():
                shutil.rmtree(f, ignore_errors=True)
            else:
                f.unlink()
        except OSError:
            pass
    return size


def run(cmd, dry):
    if dry:
        print(f"[dry-run] {' '.join(cmd)}")
        return ""
    r = subprocess.run(cmd, shell=True, capture_output=True,
                       text=True, errors="replace")
    return (r.stdout + r.stderr).strip()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run

    before = free_c()
    print("=== Windows 11 Safe Cleanup ===")
    print(f"C: free before: {before / 2**30:.2f} GB\n")

    tmp = os.environ.get("TEMP", tempfile.gettempdir())
    s = clear(tmp, dry)
    print(f"[1] User temp cleaned          : -{mb(max(s,0))} MB")
    s = clear(r"C:\Windows\Temp", dry)
    print(f"[2] Windows temp (best effort) : -{mb(max(s,0))} MB "
          "(locked/admin files skipped)")

    for name, cmd in (("npm cache", ["npm", "cache", "clean", "--force"]),
                      ("pip cache", ["pip", "cache", "purge"]),
                      ("pnpm store", ["pnpm", "store", "prune"]),
                      ("yarn cache", ["yarn", "cache", "clean"])):
        out = run(cmd, dry)
        print(f"[3] {name:<22} : cleaned" +
              ("" if not out else f" ({out.splitlines()[-1]})"))

    la = os.environ.get("LOCALAPPDATA", "")
    up = os.environ.get("USERPROFILE", "")
    for name, path in (
            ("NuGet v3-cache", rf"{la}\NuGet\v3-cache"),
            ("NuGet packages", rf"{up}\.nuget\packages"),
            ("pip cache dir", rf"{la}\pip\cache"),
            ("pip cache alt", rf"{up}\.cache\pip"),
            ("npm cache dir", rf"{la}\npm-cache")):
        s = clear(path, dry)
        print(f"[3b] {name:<22}: " +
              ("not found" if s == -1 else f"-{mb(s)} MB"))

    for d in (rf"{la}\Microsoft\Windows\INetCache\IE",
              rf"{la}\CrashDumps"):
        s = clear(d, dry)
        if s and s > 0:
            print(f"[4] {Path(d).name:<30}: -{mb(s)} MB")

    if dry:
        print("[dry-run] Clear-RecycleBin -Force")
    else:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "try { Clear-RecycleBin -Force -ErrorAction Stop; "
             "'[5] Recycle bin emptied' } catch { "
             "'[5] Recycle bin: skipped' }"],
            capture_output=True, text=True, errors="replace")
        print(r.stdout.strip() or "[5] Recycle bin: skipped")

    print("\n--- Docker (safe subset) ---")
    print("Before: " + (run(["docker", "system", "df", "--format",
                             "{{.Type}} {{.Size}}"], dry)
                        or "(n/a)"))
    for tag, cmd in (("Build cache", ["docker", "builder", "prune", "-f"]),
                     ("Dangling img", ["docker", "image", "prune", "-f"])):
        out = run(cmd, dry)
        line = out.splitlines()[-1] if out else ""
        print(f"[6] {tag} : {line}")
    print("Containers/volumes/named images: untouched")

    after = free_c()
    print("\n=== Summary ===")
    print(f"C: free after : {after / 2**30:.2f} GB")
    print(f"Freed on C:   : {mb(after - before)} MB")
    print("\nRequires Administrator (elevated cleanup covers):")
    print("  - DISM component store cleanup")
    print("  - Windows Update download cache")
    print("  - Delivery Optimization cache")
    print("  - shadow copies: vssadmin delete shadows /for=c: /oldest")


if __name__ == "__main__":
    main()
