"""ntfy-windows-bridge launcher (Python port of scripts/startup/ntfy-bridge.bat).

Launches scripts\\ntfy-windows-bridge.py under pythonw (hidden window),
mirroring the .bat invoked by ntfy-bridge-hidden.vbs.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: ntfy, bridge, startup

BRIDGE = r"D:\DevOptimizer\scripts\ntfy-windows-bridge.py"
PYTHONW = r"C:\Program Files\Python312\pythonw.exe"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.dry_run:
        print(f'[dry-run] start "" /b "{PYTHONW}" "{BRIDGE}"')
        return
    pythonw = PYTHONW if os.path.exists(PYTHONW) else "pythonw"
    subprocess.Popen([pythonw, BRIDGE],
                     creationflags=getattr(subprocess,
                                           "CREATE_NO_WINDOW", 0))
    print(f"bridge launched: {BRIDGE}", file=sys.stderr)


if __name__ == "__main__":
    main()
