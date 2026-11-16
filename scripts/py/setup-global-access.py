"""Setup global access (port of
tools/Variants/00-SETUP-GLOBAL-ACCESS-*.bat).

Appends D:\\DevOptimizer to the SYSTEM PATH (HKLM Environment) when
elevated. The NoAdmin variant only explains the requirement — the port
does the same check and exits. Mutating; --dry-run, -y to skip confirm.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: setup, path, system, elevated

ADDITION = r"D:\DevOptimizer"
HKLM_PATH = (r"HKLM\SYSTEM\CurrentControlSet\Control"
             r"\Session Manager\Environment")


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("-y", "--yes", action="store_true",
                   help="skip the confirmation prompt")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if not is_admin():
        print("[INFO] Running in standard mode without Administrator "
              "privileges\n\n"
              "ADMINISTRATOR PRIVILEGES REQUIRED\n\n"
              "This script requires Administrator privileges to modify "
              "the system PATH.\nPlease right-click this file and select "
              '"Run as administrator"', file=sys.stderr)
        sys.exit(1)

    if not args.yes and not args.dry_run:
        if input("Continue with setup? (Y/N): ").strip().upper() != "Y":
            return

    ps = (
        "$ErrorActionPreference = 'Stop'; "
        f"$cur = (Get-ItemProperty 'HKLM:{HKLM_PATH}' -Name PATH).PATH; "
        f"if ($cur -like '*{ADDITION}*') "
        "{ Write-Host 'DevOptimizer already in system PATH'; exit 0 }; "
        f"Set-ItemProperty 'HKLM:{HKLM_PATH}' -Name PATH "
        f"-Value ($cur + ';{ADDITION}'); "
        "Write-Host 'Added DevOptimizer to system PATH'")
    if args.dry_run:
        print("[dry-run] " + ps)
        return

    r = asyncio.run(run_ps_command(ps))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip() or "failed to update system PATH",
              file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
