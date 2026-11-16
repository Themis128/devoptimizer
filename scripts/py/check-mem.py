"""Show free and total physical memory (Python port of check-mem.ps1).

Reads Win32_OperatingSystem via a PowerShell CIM shim and prints
free/total GB.
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit result as JSON")
    args = parser.parse_args()

    script = (
        "Get-CimInstance Win32_OperatingSystem | "
        "Select-Object FreePhysicalMemory, TotalVisibleMemorySize | "
        "ConvertTo-Json -Compress"
    )
    result = asyncio.run(run_ps_command(script))
    if result.returncode != 0:
        print(result.stderr.strip() or "memory query failed", file=sys.stderr)
        sys.exit(result.returncode)

    mem = json.loads(result.stdout or "{}")
    free_gb = (mem.get("FreePhysicalMemory") or 0) / 1048576
    total_gb = (mem.get("TotalVisibleMemorySize") or 0) / 1048576

    if args.json:
        print(json.dumps({"FreeGB": round(free_gb, 2), "TotalGB": round(total_gb, 2)}))
    else:
        print(f"Free: {free_gb:.2f} GB")
        print(f"Total: {total_gb:.2f} GB")


if __name__ == "__main__":
    main()
