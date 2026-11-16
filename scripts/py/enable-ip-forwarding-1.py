"""Enable IP forwarding on Wi-Fi (Python port of enable-ip-forwarding.ps1).

Runs Set-NetIPInterface -InterfaceAlias "Wi-Fi" -Forwarding Enabled and
writes the completion stamp to logs\\.ip-forwarding-done. Requires admin.
"""

import argparse
import asyncio
import re
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: network, forwarding, admin

STAMP = Path(r"D:\DevOptimizer\logs\.ip-forwarding-done")

# Interface aliases are interpolated into elevated PowerShell — restrict to a
# safe charset and reject anything that could break out of the quoted string.
_IFACE_RE = re.compile(r"^[\w .\-()]+$")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Report what would change without applying it")
    parser.add_argument("--interface", default="Wi-Fi",
                        help="Interface alias to enable forwarding on")
    args = parser.parse_args()

    if not _IFACE_RE.fullmatch(args.interface):
        print(f"invalid interface alias: {args.interface!r}", file=sys.stderr)
        sys.exit(2)

    if args.dry_run:
        print(f"[dry-run] would enable IP forwarding on '{args.interface}' "
              f"and write stamp {STAMP}")
        return

    iface = args.interface.replace("'", "''")
    result = asyncio.run(run_ps_command_elevated(
        f"Set-NetIPInterface -InterfaceAlias '{iface}' -Forwarding Enabled -ErrorAction Stop"))
    if result.returncode != 0:
        print(result.stderr.strip() or "Set-NetIPInterface failed", file=sys.stderr)
        sys.exit(result.returncode)

    STAMP.parent.mkdir(parents=True, exist_ok=True)
    STAMP.write_text("forwarding enabled\n", encoding="ascii")
    print("forwarding enabled")


if __name__ == "__main__":
    main()
