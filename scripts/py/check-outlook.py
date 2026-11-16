"""Outlook health snapshot (Python port of check-outlook.ps1).

Shows outlook/olk processes, the last 20 AppModel-Runtime admin events,
and any outlook/olk crash dumps.
"""

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: outlook, diagnostics, eventlog


async def run(script: str) -> list:
    result = await run_ps_command(script + " | ConvertTo-Json -Compress -Depth 3")
    if result.returncode != 0 or not result.stdout.strip():
        return []
    data = json.loads(result.stdout)
    return data if isinstance(data, list) else [data]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit all sections as JSON")
    args = parser.parse_args()

    processes = asyncio.run(run(
        "Get-Process | Where-Object { $_.Name -match 'outlook|olk' } | "
        "Select-Object Name, Id, StartTime, Responding, MainWindowTitle, Path"))
    events = asyncio.run(run(
        "Get-WinEvent -LogName 'Microsoft-Windows-AppModel-Runtime/Admin' "
        "-MaxEvents 20 -ErrorAction SilentlyContinue | "
        "Select-Object TimeCreated, Id, LevelDisplayName, Message"))

    dumps_dir = Path(os.environ.get("LOCALAPPDATA", "")) / "CrashDumps"
    dumps = []
    if dumps_dir.exists():
        dumps = [
            {"Name": f.name, "Length": f.stat().st_size,
             "LastWriteTime": f.stat().st_mtime}
            for f in dumps_dir.iterdir()
            if f.is_file() and any(k in f.name.lower() for k in ("outlook", "olk"))
        ]

    if args.json:
        print(json.dumps({"processes": processes, "events": events,
                          "crashDumps": dumps}, indent=2, default=str))
        return

    print("=== Outlook-ish processes ===")
    for p in processes:
        print(f"{p.get('Name', ''):<20} pid={p.get('Id', '')} "
              f"responding={p.get('Responding', '')} {p.get('MainWindowTitle', '')}")
    print("\n=== Recent AppModel events (last 20) ===")
    for e in events:
        print(f"{e.get('TimeCreated', '')} [{e.get('LevelDisplayName', '')}] "
              f"id={e.get('Id', '')} {(e.get('Message') or '')[:160]}")
    print("\n=== Reliability / crash dumps for olk ===")
    for d in dumps:
        print(f"{d['Name']}  {d['Length']} bytes  {d['LastWriteTime']}")


if __name__ == "__main__":
    main()
