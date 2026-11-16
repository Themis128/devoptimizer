"""Report ACP message-store size (Python port of check-acp-size.ps1).

Counts *.db files under %APPDATA%\\devin\\User\\acp-messages and prints
their total size in MB.
"""

import argparse
import json
import os
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, acp, storage


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit result as JSON")
    args = parser.parse_args()

    acp_dir = Path(os.environ.get("APPDATA", "")) / "devin" / "User" / "acp-messages"
    total = 0
    count = 0
    if acp_dir.exists():
        for f in acp_dir.glob("*.db"):
            try:
                total += f.stat().st_size
                count += 1
            except OSError:
                continue

    result = {"count": count, "totalMB": round(total / 1048576, 1)}
    if args.json:
        print(json.dumps(result))
    else:
        print(f"ACP messages: {count} DB files, {result['totalMB']} MB total")


if __name__ == "__main__":
    main()
