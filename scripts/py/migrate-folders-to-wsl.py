"""Migrate DevOptimizer folder to WSL (port of
scripts/migrate-folders-to-wsl.ps1).

rsync -av from /mnt/d/DevOptimizer (or --source) to
/home/tbaltzakis/DevOptimizer inside Ubuntu-24.04. Mutating;
--dry-run.
"""

import argparse
import os
import subprocess
import sys

# CATEGORY: utilities
# TAGS: wsl, migration, rsync


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--source", default="D:\\DevOptimizer")
    p.add_argument("--dest", default="/home/tbaltzakis/DevOptimizer")
    p.add_argument("--distro", default="Ubuntu-24.04")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    # D:\X -> /mnt/d/X
    mnt = "/mnt/" + args.source.replace(":\\", "/").replace(
        ":", "").rstrip("/").lower().lstrip("/")
    cmd = ["rsync", "-av", "--progress", f"{mnt}/", args.dest + "/"]
    if args.dry_run:
        print(f"[dry-run] wsl -d {args.distro} -- " + " ".join(cmd))
        return
    env = dict(os.environ, WSL_UTF8="1")
    subprocess.run(["wsl.exe", "-d", args.distro, "--", "bash", "-c",
                    "mkdir -p '" + args.dest + "'"], env=env)
    r = subprocess.run(["wsl.exe", "-d", args.distro, "--",
                        *cmd], env=env)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
