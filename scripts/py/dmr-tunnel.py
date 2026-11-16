"""DMR SSH reverse-tunnel keep-alive (port of scripts/startup/dmr-tunnel.bat).

Keeps omv:12436 forwarded to this PC's Docker Model Runner for the
Nextcloud assistant on cloud.cloudless.gr. Single-instance guarded;
reconnects every 15s after a drop.
"""

import argparse
import asyncio
import subprocess
import sys
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: ssh, tunnel, dmr, startup

SSH_ARGS = [
    "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
    "-o", "ServerAliveInterval=30", "-o", "ServerAliveCountMax=6",
    "-o", "ExitOnForwardFailure=yes", "-N",
    "-R", "0.0.0.0:12436:127.0.0.1:12436", "github-omv",
]


async def tunnel_running() -> bool:
    r = await run_ps_command(
        "exit [int]((Get-CimInstance Win32_Process | Where-Object { "
        "$_.Name -eq 'ssh.exe' -and $_.CommandLine -match '12436' } | "
        "Measure-Object).Count -gt 0)")
    return r.returncode == 1


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--once", action="store_true",
                        help="single check/connect, no keep-alive loop")
    args = parser.parse_args()

    if args.dry_run:
        print("[dry-run] guard existing ssh -R 12436, then:",
              " ".join(SSH_ARGS))
        return

    if asyncio.run(tunnel_running()):
        print("dmr tunnel already running", file=sys.stderr)
        return

    while True:
        r = subprocess.run(SSH_ARGS)
        print(f"tunnel exited ({r.returncode}); retrying in 15s",
              file=sys.stderr)
        if args.once:
            sys.exit(r.returncode)
        time.sleep(15)


if __name__ == "__main__":
    main()
