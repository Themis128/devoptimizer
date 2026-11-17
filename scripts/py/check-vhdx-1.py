"""Show the docker_data.vhdx size (Python port of check-vhdx.ps1).

Reports Name, Length and SizeGB for
C:\\ProgramData\\DockerDesktop\\vm-data\\docker_data.vhdx.
"""

import argparse
import json
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: vhdx, docker, storage

VHDX_PATH = Path(r"C:\ProgramData\DockerDesktop\vm-data\docker_data.vhdx")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit result as JSON")
    args = parser.parse_args()

    if not VHDX_PATH.exists():
        print(f"not found: {VHDX_PATH}", file=sys.stderr)
        sys.exit(1)

    size = VHDX_PATH.stat().st_size
    info = {"Name": VHDX_PATH.name, "Length": size, "SizeGB": round(size / 1073741824, 2)}
    if args.json:
        print(json.dumps(info, indent=2))
    else:
        print(f"{info['Name']}  {info['Length']} bytes  {info['SizeGB']} GB")


if __name__ == "__main__":
    main()
