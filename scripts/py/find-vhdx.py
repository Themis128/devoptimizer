"""Find VHDX files under DockerDesktop (Python port of find-vhdx.ps1).

Recursively lists *.vhdx files under C:\\ProgramData\\DockerDesktop with
full path, byte length and size in GB.
"""

import argparse
import json
from pathlib import Path

# CATEGORY: utilities
# TAGS: vhdx, docker, storage

ROOT = Path(r"C:\ProgramData\DockerDesktop")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit results as JSON")
    args = parser.parse_args()

    entries = []
    if ROOT.exists():
        for f in ROOT.rglob("*.vhdx"):
            try:
                size = f.stat().st_size
            except OSError:
                continue
            entries.append({
                "FullName": str(f),
                "Length": size,
                "SizeGB": round(size / 1073741824, 2),
            })

    if args.json:
        print(json.dumps(entries, indent=2))
        return
    for e in entries:
        print(f"{e['FullName']}  {e['Length']}  {e['SizeGB']} GB")


if __name__ == "__main__":
    main()
