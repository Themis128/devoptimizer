"""DevOptimizer global launcher (port of scripts/optimizer.ps1).

--list (bat + ps1 inventory), --status (dir/launcher/PATH checks),
--help. Read-only.
"""

import argparse
import json
import os
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: launcher, status, inventory

ROOT = Path(r"D:\DevOptimizer")
LAUNCHER = ROOT / "00-LAUNCHER.bat"


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--list", action="store_true")
    p.add_argument("--status", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    bats = sorted(f.name for f in ROOT.glob("*.bat")
                  if not f.name.startswith("00-SETUP"))
    ps1s = sorted(f.name for f in ROOT.glob("*.ps1"))

    if args.status:
        on_path = str(ROOT) in os.environ.get("PATH", "")
        status = {"root_exists": ROOT.is_dir(),
                  "launcher_exists": LAUNCHER.is_file(),
                  "bat_count": len(bats), "ps1_count": len(ps1s),
                  "on_path": on_path}
        if args.json:
            print(json.dumps(status))
        else:
            for k, v in status.items():
                print(f"{k}: {v}")
        return
    if args.list:
        if args.json:
            print(json.dumps({"bat": bats, "ps1": ps1s}))
        else:
            print("Batch Files:")
            for b in bats:
                print(f"  {b}")
            print("PowerShell Scripts:")
            for s in ps1s:
                print(f"  {s}")
        return
    p.print_help()


if __name__ == "__main__":
    main()
