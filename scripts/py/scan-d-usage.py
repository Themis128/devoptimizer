"""Show D:\\ top-level directory sizes (Python port of scan-d-usage.ps1).

Read-only scan: total GB per top-level directory, top 25, plus loose
root files.
"""

import argparse
import json
import os
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: disk, usage, scan


def dir_size_gb(path: Path) -> float:
    total = 0
    for root, _dirs, files in os.walk(path, onerror=lambda e: None):
        for name in files:
            try:
                total += (Path(root) / name).stat().st_size
            except OSError:
                continue
    return total / 1073741824


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=r"D:\\", help="Root to scan")
    parser.add_argument("--top", type=int, default=25, help="Rows to print")
    parser.add_argument("--json", action="store_true", help="Emit result as JSON")
    args = parser.parse_args()

    root = Path(args.root)
    if not root.exists():
        print(f"not found: {root}", file=sys.stderr)
        sys.exit(1)

    rows = []
    loose_bytes = loose_count = 0
    for entry in root.iterdir():
        try:
            if entry.is_dir():
                rows.append({"Name": entry.name,
                             "GB": round(dir_size_gb(entry), 2)})
            elif entry.is_file():
                loose_bytes += entry.stat().st_size
                loose_count += 1
        except OSError:
            continue
    rows.sort(key=lambda r: r["GB"], reverse=True)
    loose_gb = round(loose_bytes / 1073741824, 2)

    if args.json:
        print(json.dumps({"dirs": rows, "looseGB": loose_gb,
                          "looseCount": loose_count}))
        return
    for r in rows[: args.top]:
        print(f"{r['GB']:>10.2f} GB  {r['Name']}")
    print(f"{loose_gb:>10.2f} GB  <loose root files ({loose_count} files)>")


if __name__ == "__main__":
    main()
