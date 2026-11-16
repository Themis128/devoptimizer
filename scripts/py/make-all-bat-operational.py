"""Make all .bat files operational (port of
tools/Variants/MAKE-ALL-BAT-OPERATIONAL-*.bat).

Creates -NoAdmin copies of the key admin .bats, sets the current-user
execution policy to Bypass, then syntax-checks every .bat for an
@echo off line. Mutating; --dry-run; --admin gate.
"""

import argparse
import asyncio
import re
import shutil
import subprocess
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: bat, variants, operational

SCRIPT_DIR = Path(r"D:\DevOptimizer")
PAIRS = [("01-Quick-Optimization.bat", "01-Quick-Optimization-NoAdmin.bat"),
         ("02-Ultra-Performance.bat", "02-Ultra-Performance-NoAdmin.bat"),
         ("03-Install-Dev-Tools.bat", "03-Install-Dev-Tools-NoAdmin.bat"),
         ("06-System-Health-Check.bat", "06-System-Health-Check-NoAdmin.bat"),
         ("09-System-Deep-Clean.bat", "09-System-Deep-Clean-NoAdmin.bat")]
SELF = {"MAKE-ALL-BAT-OPERATIONAL.bat", "FIX-ALL-BAT-FILES.bat"}
ADMIN_GATE = re.compile(
    r"(?im)^\s*(call :checkAdmin|net session|if not \"%?IS_ADMIN)"
    r".*(\r?\n\s*(pause|exit /b|if not|)[:()\w% ]*){0,3}")


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--script-dir", default=str(SCRIPT_DIR))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)

    s = Path(args.script_dir)
    created = 0
    for src_name, dst_name in PAIRS:
        src, dst = s / src_name, s / dst_name
        if not src.is_file():
            print(f"skip (missing): {src_name}", file=sys.stderr)
            continue
        text = src.read_text(errors="replace")
        new = ADMIN_GATE.sub("", text)
        if args.dry_run:
            print(f"[dry-run] write {dst_name}")
        else:
            dst.write_text(new)
        created += 1
        print(f"created {dst_name}")

    print("\n[2/6] Fixing PowerShell execution policy...")
    if args.dry_run:
        print("[dry-run] Set-ExecutionPolicy Bypass -Scope CurrentUser")
    else:
        asyncio.run(run_ps_command(
            "try { Set-ExecutionPolicy -ExecutionPolicy Bypass "
            "-Scope CurrentUser -Force } catch { }"))

    print("\n[4/6] Testing batch files...")
    working = total = 0
    for f in sorted(s.glob("*.bat")):
        if f.name in SELF:
            continue
        total += 1
        if re.search(r"(?m)^@echo off", f.read_text(errors="replace")):
            working += 1
        else:
            print(f"  missing @echo off: {f.name}", file=sys.stderr)
    print(f"\n[6/6] {working}/{total} batch files operational; "
          f"{created} NoAdmin variants created")


if __name__ == "__main__":
    main()
