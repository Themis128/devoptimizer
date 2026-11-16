"""Organize DevOptimizer hub files (port of scripts/organize-files.bat).

Moves loose files in the hub root into Backups/, Documentation/, Logs/,
Scripts/, tools/Variants/ and tools/Old-Launchers/. Mutating; --dry-run.
"""

import argparse
import shutil
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: organize, files, housekeeping

HUB = Path(r"D:\DevOptimizer")
KEEP_LAUNCHERS = {"DEVOPTIMIZER-HUB.bat",
                  "DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat"}
# Root files the hub/app pipeline depends on — moving them breaks the
# registry build (Discover/Build) and command execution
# (Execute-Command.ps1 is loaded from the root by CommandRunnerService).
KEEP_ROOT = {"Execute-Command.ps1", "Discover-Scripts.ps1",
             "Build-Registry.ps1"} | KEEP_LAUNCHERS
SUBFOLDERS = ["Backups", "Documentation", "Logs", "Scripts", "Tools",
              "tools/Variants", "tools/Old-Launchers"]


def moves(hub: Path):
    for d in hub.glob("backup-*"):
        if d.is_dir():
            yield d, hub / "Backups"
    for pat, dst in [("*.md", "Documentation"), ("*.log", "Logs"),
                     ("*.ps1", "Scripts"), ("*-Admin.bat", "tools/Variants"),
                     ("*-NoAdmin.bat", "tools/Variants"),
                     ("-*.bat", "tools/Old-Launchers")]:
        for f in hub.glob(pat):
            if f.is_file() and f.name not in KEEP_ROOT:
                yield f, hub / dst
    for f in hub.glob("*LAUNCHER*.bat"):
        if f.is_file() and f.name not in KEEP_ROOT:
            yield f, hub / "tools/Old-Launchers"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--hub", default=str(HUB))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    hub = Path(args.hub)

    for sub in SUBFOLDERS:
        p = hub / sub
        if not p.is_dir():
            if args.dry_run:
                print(f"[dry-run] mkdir {p}")
            else:
                p.mkdir(parents=True)
    count = 0
    for src, dst in moves(hub):
        if not src.exists():
            continue
        target = dst / src.name
        if target.exists():
            print(f"skip (exists): {target}", file=sys.stderr)
            continue
        if args.dry_run:
            print(f"[dry-run] move {src} -> {target}")
        else:
            try:
                shutil.move(str(src), str(target))
            except OSError as e:
                print(f"skip {src.name}: {e}", file=sys.stderr)
                continue
            print(f"Moved: {src.name}")
        count += 1
    print(f"{count} item(s) {'would be ' if args.dry_run else ''}moved")


if __name__ == "__main__":
    main()
