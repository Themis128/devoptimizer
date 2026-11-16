"""Check Devin processes in WSL (port of
scripts/check-devin-wsl-processes.ps1).

Runs `wsl -d Ubuntu-24.04 -- ps aux` filtered for devin. --json.
"""

import argparse
import json
import subprocess
import sys

# CATEGORY: utilities
# TAGS: wsl, devin, processes


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--json", action="store_true")
    p.add_argument("--distro", default="Ubuntu-24.04")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    cmd = ["wsl", "-d", args.distro, "--", "ps", "aux"]
    if args.dry_run:
        print("[dry-run] " + " ".join(cmd))
        return
    r = subprocess.run(cmd, capture_output=True, text=True)
    lines = [l for l in r.stdout.splitlines()
             if "devin" in l.lower() and "grep" not in l]
    if args.json:
        print(json.dumps({"processes": lines, "count": len(lines)}))
    else:
        for l in lines:
            print(l)
    sys.exit(r.returncode if r.returncode else 0)


if __name__ == "__main__":
    main()
