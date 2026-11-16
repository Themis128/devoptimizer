"""List ACP message databases (Python port of list-acp-dbs.ps1).

Lists *.db files under %APPDATA%\\devin\\User\\acp-messages with size in MB
and last write time, newest first.
"""

import argparse
import json
import os
from pathlib import Path

# CATEGORY: utilities


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit results as JSON")
    args = parser.parse_args()

    acp_dir = Path(os.environ.get("APPDATA", "")) / "devin" / "User" / "acp-messages"
    entries = []
    if acp_dir.exists():
        for f in acp_dir.glob("*.db"):
            try:
                st = f.stat()
            except OSError:
                continue
            entries.append({
                "Name": f.name,
                "SizeMB": round(st.st_size / 1048576, 1),
                "LastWriteTime": st.st_mtime,
            })
    entries.sort(key=lambda e: e["LastWriteTime"], reverse=True)

    if args.json:
        print(json.dumps(entries, indent=2))
        return
    import datetime
    print(f"{'Name':<40} {'SizeMB':>8}  LastWriteTime")
    for e in entries:
        ts = datetime.datetime.fromtimestamp(e["LastWriteTime"]).strftime("%Y-%m-%d %H:%M")
        print(f"{e['Name']:<40} {e['SizeMB']:>8}  {ts}")


if __name__ == "__main__":
    main()
