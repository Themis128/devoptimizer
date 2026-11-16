"""Create desktop shortcuts (port of
tools/Variants/CREATE-DESKTOP-SHORTCUTS-NoAdmin.bat).

Five WScript.Shell .lnk files on %USERPROFILE%\\Desktop pointing at the
hub launchers. Mutating; --dry-run.
"""

import argparse
import asyncio
import os
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: shortcuts, desktop, ui

SHORTCUTS = [
    ("DevOptimizer Universal Launcher.lnk",
     r"D:\DevOptimizer\UNIVERSAL-LAUNCHER.bat", "",
     "DevOptimizer Universal Launcher - Main UI"),
    ("DevOptimizer Admin Mode.lnk", "powershell.exe",
     r'-ExecutionPolicy Bypass -File "D:\DevOptimizer\RUN-AS-ADMIN.bat"',
     "DevOptimizer Admin Mode - Full Features"),
    ("DevOptimizer System Health.lnk",
     r"D:\DevOptimizer\06-System-Health-Check.bat", "",
     "DevOptimizer System Health Check"),
    ("DevOptimizer Quick Optimization.lnk",
     r"D:\DevOptimizer\01-Quick-Optimization.bat", "",
     "DevOptimizer Quick Optimization"),
    ("DevOptimizer Quick Access.lnk",
     r"D:\DevOptimizer\QUICK-UI-ACCESS.bat", "",
     "DevOptimizer Quick UI Access - All Options"),
]


def ps_create(desktop: str, name: str, target: str, args_: str,
              desc: str) -> str:
    arg_line = (f"$s.Arguments = '{args_}'; " if args_ else "")
    return (
        "$WshShell = New-Object -ComObject WScript.Shell; "
        f"$s = $WshShell.CreateShortcut('{desktop}\\{name}'); "
        f"$s.TargetPath = '{target}'; {arg_line}"
        "$s.WorkingDirectory = 'D:\\DevOptimizer'; "
        f"$s.Description = '{desc}'; $s.Save()")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    desktop = Path(os.environ.get("USERPROFILE",
                                  str(Path.home()))) / "Desktop"
    print("Creating desktop shortcuts for easy UI access...\n")
    for i, (name, target, argline, desc) in enumerate(SHORTCUTS, 1):
        ps = ps_create(str(desktop), name, target, argline, desc)
        print(f"[{i}/{len(SHORTCUTS)}] Creating {name}...")
        if args.dry_run:
            print("    [dry-run] " + ps)
            continue
        r = asyncio.run(run_ps_command(ps))
        if r.returncode != 0:
            print(f"    failed: {r.stderr.strip()}", file=sys.stderr)


if __name__ == "__main__":
    main()
