"""Create DevOptimizer desktop shortcuts (port of tools/create-desktop-shortcut.ps1).

Creates the master-launcher .lnk plus a red-themed wrapper .bat + .lnk on
the desktop via WScript.Shell (run through a PS block — COM has no Python
binding in this repo's shim layer). Mutating; --dry-run.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: desktop, shortcut, launcher


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--target", default=r"D:\DevOptimizer\DEVOPTIMIZER-WORKING-LAUNCHER.bat")
    parser.add_argument("--shortcut-name", default="DevOptimizer System Launcher")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ps = (
        "$desktop = [Environment]::GetFolderPath('Desktop'); "
        f"if (-not (Test-Path '{args.target}')) {{ Write-Error 'target missing'; exit 1 }}; "
        "$w = New-Object -ComObject WScript.Shell; "
        f"$sc = $w.CreateShortcut((Join-Path $desktop '{args.shortcut_name}.lnk')); "
        f"$sc.TargetPath = '{args.target}'; "
        f"$sc.WorkingDirectory = (Split-Path '{args.target}'); "
        "$sc.Description = 'DevOptimizer Master Launcher'; "
        "$sc.WindowStyle = 1; "
        "$sc.IconLocation = \"$env:SystemRoot\\System32\\shell32.dll,3\"; "
        "$sc.Hotkey = 'CTRL+ALT+D'; $sc.Save(); "
        "$wrapper = Join-Path $desktop 'DevOptimizer-Red-Launcher.bat'; "
        "$wc = \"@echo off`r`ntitle DevOptimizer System Launcher - Red Edition`r`n\""
        "  + \"color 0C`r`ntimeout /t 2 >nul`r`n\""
        f"  + 'start \"\" \"{args.target}\"' + \"`r`nexit /b 0`r`n\"; "
        "Set-Content $wrapper $wc -Encoding ASCII; "
        "$sc2 = $w.CreateShortcut((Join-Path $desktop 'DevOptimizer-Red-Launcher.lnk')); "
        "$sc2.TargetPath = $wrapper; "
        "$sc2.Description = 'DevOptimizer Red Launcher'; "
        "$sc2.WindowStyle = 1; "
        "$sc2.IconLocation = \"$env:SystemRoot\\System32\\shell32.dll,3\"; "
        "$sc2.Hotkey = 'CTRL+ALT+R'; $sc2.Save(); "
        "Write-Output 'shortcuts created'"
    )

    if args.dry_run:
        print(f"[dry-run] would create 2 .lnk + red wrapper for {args.target}:")
        print(ps)
        return

    result = asyncio.run(run_ps_command(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or result.stdout.strip() or "failed",
              file=sys.stderr)
        sys.exit(result.returncode)
    print("Desktop shortcuts created: master .lnk + red launcher .lnk/.bat",
          file=sys.stderr)


if __name__ == "__main__":
    main()
