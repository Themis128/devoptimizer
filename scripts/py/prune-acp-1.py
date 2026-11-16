"""Prune old ACP message databases (Python port of prune-acp.ps1).

Deletes *.db, *.db-shm and *.db-wal files under
%APPDATA%\\devin\\User\\acp-messages older than --days (default 14).
"""

import argparse
import os
import time
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, acp, cleanup


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--days", type=int, default=14,
                        help="Delete files older than this many days")
    parser.add_argument("--dry-run", action="store_true",
                        help="Report what would be deleted without deleting")
    args = parser.parse_args()

    acp_dir = Path(os.environ.get("APPDATA", "")) / "devin" / "User" / "acp-messages"
    cutoff = time.time() - args.days * 86400
    if not acp_dir.exists():
        print(f"not found: {acp_dir}")
        return

    db_deleted = shm_wal_deleted = 0
    for f in sorted(acp_dir.iterdir()):
        if not f.is_file() or f.stat().st_mtime >= cutoff:
            continue
        is_db = f.suffix == ".db"
        is_side = f.name.endswith(".db-shm") or f.name.endswith(".db-wal")
        if not (is_db or is_side):
            continue
        if is_db:
            print(f"{'Would delete' if args.dry_run else 'Deleting'}: {f.name} "
                  f"({f.stat().st_size / 1048576:.1f} MB)")
            if not args.dry_run:
                f.unlink()
            db_deleted += 1
        else:
            if not args.dry_run:
                f.unlink()
            shm_wal_deleted += 1

    verb = "Would delete" if args.dry_run else "Deleted"
    print(f"{verb} {db_deleted} DB files and {shm_wal_deleted} shm/wal files "
          f"older than {args.days} days")


if __name__ == "__main__":
    main()
