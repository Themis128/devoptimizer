"""Delete oversized ACP databases (Python port of remove-large-acp.ps1).

Deletes *.db files under %APPDATA%\\devin\\User\\acp-messages larger than
--threshold-mb (default 50), plus their .db-shm/.db-wal sidecars.
"""

import argparse
import os
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, acp, cleanup, storage


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--threshold-mb", type=float, default=50,
                        help="Delete .db files larger than this (MB)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Report what would be deleted without deleting")
    args = parser.parse_args()

    acp_dir = Path(os.environ.get("APPDATA", "")) / "devin" / "User" / "acp-messages"
    if not acp_dir.exists():
        print(f"not found: {acp_dir}")
        return

    threshold = args.threshold_mb * 1048576
    deleted = 0
    freed = 0
    for f in sorted(acp_dir.glob("*.db")):
        try:
            size = f.stat().st_size
        except OSError:
            continue
        if size < threshold:
            continue
        print(f"{'Would delete' if args.dry_run else 'Deleting'} large DB: "
              f"{f.name} ({size / 1048576:.1f} MB)")
        if not args.dry_run:
            f.unlink()
            for side in (f.with_suffix(f.suffix + "-shm"),
                         f.with_suffix(f.suffix + "-wal")):
                if side.exists():
                    side.unlink()
        deleted += 1
        freed += size

    verb = "Would delete" if args.dry_run else "Deleted"
    print(f"{verb} {deleted} large DB files, freed {freed / 1048576:.1f} MB")


if __name__ == "__main__":
    main()
