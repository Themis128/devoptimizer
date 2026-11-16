"""Batch-file normalization (port of tools/normalize-bat-files.bat).

Rewrites D:\\DevOptimizer\\*.bat with the standard header
(@echo off / setlocal / cd /d "%~dp0"), drops the original's own
header lines, and replaces non-ASCII box/emoji characters with ASCII.
Mutating; -dry-run. Backup path: backups\\bat-fixes_*.
"""

import argparse
import re
import shutil
import sys
import time
import unicodedata
from pathlib import Path

# CATEGORY: utilities
# TAGS: normalize, bat, encoding

HEADER = ['@echo off', 'setlocal EnableExtensions EnableDelayedExpansion',
          'cd /d "%~dp0"', '']
SKIP_RE = re.compile(r'^\s*(@echo\s+off|setlocal|cd\s+/d)', re.I)


def normalize(text: str) -> str:
    out = []
    for line in text.splitlines():
        if SKIP_RE.match(line):
            continue
        out.append(unicodedata.normalize("NFKD", line)
                   .encode("ascii", "ignore").decode())
    return "\r\n".join(HEADER + out).rstrip() + "\r\n"


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--root", default=r"D:\DevOptimizer")
    p.add_argument("--backup", default=None)
    p.add_argument("-dry-run", "--dry-run", action="store_true")
    args = p.parse_args()

    root = Path(args.root)
    backup = Path(args.backup) if args.backup else (
        root / "backups" / f"bat-fixes_{time.strftime('%Y%m%d_%H%M%S')}")
    files = sorted(root.glob("*.bat"))
    processed = success = failed = changed = 0
    for f in files:
        processed += 1
        if f.stat().st_size < 10:
            print(f"skip (tiny): {f.name}", file=sys.stderr)
            failed += 1
            continue
        try:
            text = f.read_text(encoding="utf-8-sig", errors="replace")
            new = normalize(text)
            if new != text.replace("\n", "\r\n").rstrip() + "\r\n":
                changed += 1
            if not args.dry_run:
                backup.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, backup / f.name)
                f.write_text(new, encoding="ascii", newline="")
            success += 1
        except OSError as e:
            print(f"failed: {f.name}: {e}", file=sys.stderr)
            failed += 1

    print(f"\nTotal: {len(files)}  Processed: {processed}  "
          f"OK: {success}  Failed: {failed}  Changed: {changed}")
    if args.dry_run:
        print("DRY RUN — remove --dry-run to apply.")
    else:
        print(f"Backups: {backup}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
