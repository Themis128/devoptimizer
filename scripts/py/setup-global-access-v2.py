"""Setup global access v2 (port of
tools/Variants/SETUP-GLOBAL-ACCESS-*.bat — the non-00 variant).

setx PATH /M (falls back to user scope), 'DevOptimizer Master Suite'
desktop shortcut. Mutating; --dry-run; --admin = admin variant label.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: setup, path, shortcuts

SCRIPT_DIR = Path(__file__).resolve().parents[1]


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    path = os.environ.get("PATH", "")
    print("[1] Adding DevOptimizer to system PATH...")
    cmds = [["setx", "PATH", f"{path};{SCRIPT_DIR}", "/M"],
            ["setx", "PATH", f"{path};{SCRIPT_DIR}"]]
    if args.dry_run:
        print("[dry-run] " + " / ".join(" ".join(c) for c in cmds))
    else:
        r = subprocess.run(cmds[0], capture_output=True)
        if r.returncode != 0:
            r = subprocess.run(cmds[1], capture_output=True)
        print("   Added to PATH" if r.returncode == 0
              else "   Failed to add to PATH")

    desktop = Path(os.environ.get("USERPROFILE",
                                  str(Path.home()))) / "Desktop"
    if desktop.is_dir():
        ps = (
            "$WshShell = New-Object -ComObject WScript.Shell; "
            f"$s = $WshShell.CreateShortcut('{desktop}"
            "\\DevOptimizer Master Suite.lnk'); "
            f"$s.TargetPath = '{SCRIPT_DIR}\\DEVOPTIMIZER-MASTER-SUITE.bat'; "
            f"$s.WorkingDirectory = '{SCRIPT_DIR}'; "
            "$s.Description = 'DevOptimizer Master Suite - All-in-One System'; "
            "$s.Save()")
        print("[2] Creating desktop shortcut...")
        if args.dry_run:
            print("[dry-run] " + ps)
        else:
            import asyncio
            r = asyncio.run(run_ps_command(ps))
            print("   Shortcut created" if r.returncode == 0
                  else "   Failed to create shortcut")


if __name__ == "__main__":
    main()
