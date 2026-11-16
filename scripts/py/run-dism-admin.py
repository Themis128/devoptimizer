"""Run DISM component cleanup (Python port of run-dism-admin.bat).

Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart.
Requires elevation; --dry-run prints the command.
"""

import argparse
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: dism, cleanup, elevated

CMD = ["Dism", "/Online", "/Cleanup-Image", "/StartComponentCleanup",
       "/NoRestart"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.dry_run:
        print("[dry-run] " + " ".join(CMD))
        return

    r = subprocess.run(CMD)
    print(f"DISM exit code: {r.returncode}")
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
