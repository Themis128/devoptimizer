"""Scan D:\\Nuxt Projects usage (Python port of scan-nuxt-projects.ps1).

Per-project node_modules size and days since last non-node_modules file
activity.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

# CATEGORY: utilities
# TAGS: nuxt, disk, usage


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=r"D:\Nuxt Projects", help="Root to scan")
    parser.add_argument("--json", action="store_true", help="Emit result as JSON")
    args = parser.parse_args()

    root = Path(args.root)
    if not root.exists():
        print(f"not found: {root}", file=sys.stderr)
        sys.exit(1)

    rows = []
    for proj in sorted(root.iterdir()):
        if not proj.is_dir():
            continue
        nm_bytes = 0
        last_mtime = 0.0
        for dirpath, dirs, files in os.walk(proj, onerror=lambda e: None):
            in_nm = "node_modules" in Path(dirpath).parts
            if in_nm:
                for name in files:
                    try:
                        nm_bytes += (Path(dirpath) / name).stat().st_size
                    except OSError:
                        continue
            else:
                dirs[:] = [d for d in dirs if d != "node_modules"]
                for name in files:
                    try:
                        m = (Path(dirpath) / name).stat().st_mtime
                        last_mtime = max(last_mtime, m)
                    except OSError:
                        continue
        age = round((time.time() - last_mtime) / 86400) if last_mtime else -1
        rows.append({"project": proj.name,
                     "nodeModulesGB": round(nm_bytes / 1073741824, 2),
                     "lastActivityDays": age})

    if args.json:
        print(json.dumps(rows, indent=2))
        return
    for r in rows:
        print(f"{r['project']:<40} node_modules={r['nodeModulesGB']:>8} GB   "
              f"lastActivity={r['lastActivityDays']} days ago")


if __name__ == "__main__":
    main()
