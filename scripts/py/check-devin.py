"""List the newest Devin log files (Python port of check-devin.ps1).

Shows the 10 most recently modified files matching *log* under
%LOCALAPPDATA%\\Devin.
"""

import argparse
import json
import os
from pathlib import Path

# CATEGORY: utilities


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit results as JSON")
    parser.add_argument("--count", type=int, default=10, help="Number of files to show")
    args = parser.parse_args()

    root = Path(os.environ.get("LOCALAPPDATA", "")) / "Devin"
    entries = []
    if root.exists():
        for f in root.rglob("*"):
            try:
                if f.is_file() and "log" in f.name.lower():
                    st = f.stat()
                    entries.append({
                        "FullName": str(f),
                        "Length": st.st_size,
                        "LastWriteTime": st.st_mtime,
                    })
            except OSError:
                continue
    entries.sort(key=lambda e: e["LastWriteTime"], reverse=True)
    entries = entries[: args.count]

    if args.json:
        print(json.dumps(entries, indent=2))
        return
    import datetime
    for e in entries:
        ts = datetime.datetime.fromtimestamp(e["LastWriteTime"]).strftime("%Y-%m-%d %H:%M")
        print(f"{ts}  {e['Length']:>12}  {e['FullName']}")


if __name__ == "__main__":
    main()
