"""Port of tools/Old-Launchers/CREATE-DESKTOP-LAUNCHER.bat — runs
tools\\create-desktop-shortcut.ps1 (pwsh preferred, powershell
fallback) and reports the exit code.
"""
import shutil
import subprocess
import sys
from pathlib import Path


def main():
    print("\n" + "=" * 70)
    print("              CREATE DESKTOP LAUNCHER - DEVOPTIMIZER SYSTEM")
    print("=" * 70 + "\n")

    try:
        needs7 = any(t in PS1.read_text(
            encoding="utf-8", errors="replace")
            for t in ("-AsHashtable", "??", ".Where("))
    except OSError:
        needs7 = False
    order = ("pwsh", "powershell") if needs7 \
        else ("powershell", "pwsh")
    ps = next((shutil.which(h) for h in order
               if shutil.which(h)), None)
    if not ps:
        print("ERROR: Neither pwsh nor powershell found in PATH")
        return 1

    here = Path(__file__).resolve().parent
    target = (here / "tools" / "create-desktop-shortcut.ps1")
    if not target.exists():
        # original bat runs relative to %~dp0 (tools/Old-Launchers);
        # fall back to the repo-level tools/ dir
        target = here.parent.parent / "tools" \
            / "create-desktop-shortcut.ps1"
    print("[INFO] Creating desktop launcher for DevOptimizer"
          " System...")
    print("[INFO] Target: DEVOPTIMIZER-WORKING-LAUNCHER.bat\n")
    if not target.exists():
        print(f"[ERROR] PowerShell script not found: {target}")
        return 1
    r = subprocess.run([ps, "-NoProfile", "-ExecutionPolicy",
                        "Bypass", "-File", str(target)])
    code = r.returncode
    print()
    if code == 0:
        print("[SUCCESS] Desktop launcher created successfully!")
        print("[INFO] Check your desktop for the new shortcut")
        print("[INFO] The launcher works both with and without"
              " admin privileges")
    else:
        print("[ERROR] Failed to create desktop launcher. Check"
              " the output above for details.")
    if sys.stdin.isatty():
        input("\nPress Enter to exit...")
    return code


if __name__ == "__main__":
    sys.exit(main())
