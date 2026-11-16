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
NAMES = ["01-Quick-Optimization", "02-Ultra-Performance",
         "03-Install-Dev-Tools", "06-System-Health-Check",
         "09-System-Deep-Clean"]
SELF = {"MAKE-ALL-BAT-OPERATIONAL.bat", "FIX-ALL-BAT-FILES.bat"}


def stub(name: str) -> str:
    """NoAdmin stub the original generator writes (basic system
    check only — never a stripped copy of the admin source)."""
    return (
        "@echo off\r\n"
        "setlocal EnableExtensions EnableDelayedExpansion\r\n"
        "set \"SCRIPT_DIR=%~dp0\"\r\n"
        "set \"SCRIPT_DIR=%SCRIPT_DIR:~0,-1%\"\r\n\r\n"
        f"title  - Standard Mode- No Admin Required\r\n"
        "echo.\r\n"
        f"echo Running {name}-NoAdmin.bat...\r\n"
        "echo.\r\n"
        "echo NOTE: This is a non-admin version with limited "
        "functionality.\r\n"
        "echo For full functionality, run as Administrator.\r\n"
        "echo.\r\n"
        "powershell -ExecutionPolicy Bypass -NoProfile -Command "
        "\"Write-Host 'Running basic system check...' "
        "-ForegroundColor Green; Get-ComputerInfo | Select-Object "
        "WindowsProductName, WindowsVersion, TotalPhysicalMemory | "
        "Format-Table -AutoSize\"\r\n"
        "echo.\r\n"
        "echo Operation completed!\r\n"
        "pause\r\n")


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
    for name in NAMES:
        dst = s / f"{name}-NoAdmin.bat"
        if args.dry_run:
            print(f"[dry-run] write {dst.name}")
        else:
            s.mkdir(parents=True, exist_ok=True)
            dst.write_text(stub(name))
        created += 1
        print(f"created {dst.name}")

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
