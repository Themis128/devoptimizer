"""Tail the newest Devin log files (Python port of check-devin-logs.ps1).

Prints the last 100 lines of the 5 newest files in the most recently
written directory under %APPDATA%\\Devin\\logs.
"""

import argparse
import os
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, logs


def tail_lines(path: Path, n: int) -> list[str]:
    try:
        with path.open(encoding="utf-8", errors="replace") as f:
            return f.read().splitlines()[-n:]
    except OSError as e:
        return [f"<unreadable: {e}>"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--count", type=int, default=5, help="Files to show")
    parser.add_argument("--tail", type=int, default=100, help="Lines per file")
    args = parser.parse_args()

    logs_root = Path(os.environ.get("APPDATA", "")) / "Devin" / "logs"
    if not logs_root.exists():
        print(f"not found: {logs_root}", file=sys.stderr)
        sys.exit(1)

    dirs = [d for d in logs_root.iterdir() if d.is_dir()]
    if not dirs:
        print("no log directories", file=sys.stderr)
        sys.exit(0)
    newest = max(dirs, key=lambda d: d.stat().st_mtime)

    files = sorted(
        (f for f in newest.iterdir() if f.is_file()),
        key=lambda f: f.stat().st_mtime,
        reverse=True,
    )[: args.count]

    for f in files:
        print(f"=== {f.name} ===")
        print("\n".join(tail_lines(f, args.tail)))


if __name__ == "__main__":
    main()
