"""Quick global setup (port of tools/Variants/QUICK-GLOBAL-SETUP-*.bat).

Adds DevOptimizer dir + %USERPROFILE%\\bin to user PATH (setx), creates
a desktop shortcut and global batch launchers in %USERPROFILE%\\bin.
Mutating; --dry-run. --admin selects the admin variant (same actions —
both .bats are identical apart from the admin banner).
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: setup, path, shortcuts, global-access

SCRIPT_DIR = Path(__file__).resolve().parents[1]

GLOBAL_BATS = {
    "DevOptimizer.bat": "DEVOPTIMIZER-MASTER-SUITE.bat",
    "DevOpt.bat": "DEVOPTIMIZER-MASTER-SUITE.bat",
    "M365Fix.bat": "m365-fix-system.bat",
    "OneDriveFix.bat": "onedrive-fix-system.bat",
}


def setx_path(addition: str, dry_run: bool) -> bool:
    current = os.environ.get("PATH", "")
    cmd = ["setx", "PATH", f"{current};{addition}"]
    if dry_run:
        print("[dry-run] " + " ".join(cmd))
        return True
    return subprocess.run(cmd, capture_output=True).returncode == 0


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true",
                   help="admin variant label (actions are identical)")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    home = Path(os.environ.get("USERPROFILE", str(Path.home())))
    bindir = home / "bin"
    desktop = home / "Desktop"

    print("[1] Adding DevOptimizer to PATH...")
    ok = setx_path(str(SCRIPT_DIR), args.dry_run)
    print("   Added to user PATH" if ok else "   Failed to add to PATH")

    print("\n[2] Creating global shortcuts...")
    ps = (
        "$WshShell = New-Object -ComObject WScript.Shell; "
        f"$s = $WshShell.CreateShortcut('{desktop}\\DevOptimizer.lnk'); "
        f"$s.TargetPath = '{SCRIPT_DIR}\\DEVOPTIMIZER-MASTER-SUITE.bat'; "
        f"$s.WorkingDirectory = '{SCRIPT_DIR}'; $s.Save()")
    if args.dry_run:
        print("[dry-run] powershell " + ps)
    else:
        r = subprocess.run(["powershell", "-Command", ps],
                           capture_output=True)
        print("   Desktop shortcut created" if r.returncode == 0
              else "   Failed to create desktop shortcut")

    print("\n[3] Creating global batch files...")
    for name, target in GLOBAL_BATS.items():
        dest = bindir / name
        body = f'@echo off\r\ncall "{SCRIPT_DIR}\\{target}" %*\r\n'
        if args.dry_run:
            print(f"[dry-run] write {dest}")
        else:
            bindir.mkdir(parents=True, exist_ok=True)
            dest.write_text(body)
        print(f"   {name} created in {bindir}")

    print("\n[4] Adding bin directory to PATH...")
    ok = setx_path(str(bindir), args.dry_run)
    print("   Added bin directory to PATH" if ok
          else "   Failed to add bin directory to PATH")

    print("\nSETUP COMPLETE — restart your prompt to use the "
          "global commands.")


if __name__ == "__main__":
    main()
