"""Devin cleanup pre-hook (port of scripts/devin/hook-cleanup-pre.ps1).

Validates WSL distro reachability before devin-doctor operations;
exits 1 on failure. --operation NAME; --json.
"""

import argparse
import json
import subprocess
import sys

# CATEGORY: utilities
# TAGS: devin, hook, wsl, cleanup

DISTRO = "Ubuntu-24.04"
NEEDS_APP_CLOSED = {"repair-bundle", "cleanup-sessions",
                    "daily-maintenance"}


def wsl(cmd: str) -> str:
    r = subprocess.run(
        ["wsl.exe", "-d", DISTRO, "--", "bash", "-c", cmd],
        capture_output=True, text=True, timeout=60)
    return (r.stdout or "").replace("\x00", "").strip()


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--operation", default="")
    p.add_argument("--distro", default=DISTRO)
    p.add_argument("--json", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    ok = True
    if args.dry_run:
        print(f"[dry-run] wsl -d {args.distro} -- echo ok")
    elif wsl("echo ok") != "ok":
        print(f"[devin-cleanup:pre] FAIL: WSL distro '{args.distro}' "
              "unreachable", file=sys.stderr)
        ok = False
    if ok and args.json:
        print(json.dumps({"ok": True, "operation": args.operation}))
    elif ok:
        print("[devin-cleanup:pre] environment valid for: "
              f"{args.operation or '(none)'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
