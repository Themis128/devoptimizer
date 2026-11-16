"""Cleanup orphaned .db-shm/.db-wal files (port of
scripts/cleanup-orphan-shmwal.ps1).

Deletes acp-messages *.db-shm / *.db-wal whose base .db is gone.
Mutating; --dry-run; --json.
"""

import argparse
import json
import os
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: cleanup, sqlite, devin


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dir", default=os.path.join(
        os.environ.get("APPDATA", ""), r"devin\User\acp-messages"))
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    acp = Path(args.dir)
    deleted = []
    for f in sorted(acp.glob("*.db-shm")) + sorted(acp.glob("*.db-wal")):
        base = f.name.replace(".db-shm", "").replace(".db-wal", "")
        if not (acp / (base + ".db")).is_file():
            deleted.append(f.name)
            if args.dry_run:
                print(f"[dry-run] delete {f.name}", file=sys.stderr)
            else:
                f.unlink(missing_ok=True)
                print(f"Deleting orphan: {f.name}")
    if args.json:
        print(json.dumps({"deleted": deleted, "count": len(deleted)}))
    else:
        print(f"Deleted {len(deleted)} orphaned shm/wal files")


if __name__ == "__main__":
    main()
