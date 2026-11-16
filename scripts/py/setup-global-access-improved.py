"""Enhanced global access setup (port of
tools/Variants/00-SETUP-GLOBAL-ACCESS-IMPROVED-*.bat).

System + user PATH append of D:\\DevOptimizer with confirmation prompt.
Mutating; --dry-run, -y to skip confirm; --admin = admin variant.
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
    p.add_argument("--admin", action="store_true")
    p.add_argument("-y", "--yes", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if not is_admin():
        print("[ERROR] This script requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)

    if not args.yes and not args.dry_run:
        if input("Continue with enhanced setup? (Y/N): "
                 ).strip().upper() != "Y":
            return

    ps = (
        "$ErrorActionPreference = 'Stop'; "
        f"$cur = (Get-ItemProperty 'HKLM:{HKLM_PATH}' -Name PATH).PATH; "
        f"if ($cur -notlike '*{ADDITION}*') {{ "
        f"Set-ItemProperty 'HKLM:{HKLM_PATH}' -Name PATH "
        f"-Value ($cur + ';{ADDITION}') }}; "
        f"setx PATH ($cur + ';{ADDITION}') /M | Out-Null; "
        "Write-Host 'PATH updated (system + user)'")
    if args.dry_run:
        print("[dry-run] " + ps)
        return

    r = asyncio.run(run_ps_command(ps))
    if r.stdout.strip():
        print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip() or "setup failed", file=sys.stderr)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
