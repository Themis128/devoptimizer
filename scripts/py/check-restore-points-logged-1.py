"""Port of scripts/check-restore-points-logged.ps1.

Lists restore points and writes them to
D:\\DevOptimizer\\logs\\restore-points-<ts>.log.
"""

import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def restore_points():
    try:
        r = subprocess.run(
            ["wmic", "/namespace:\\\\root\\default", "path",
             "SystemRestore", "get",
             "Description,CreationTime,SequenceNumber,"
             "RestorePointType", "/format:csv"],
            capture_output=True, text=True)
        rows = []
        for line in r.stdout.splitlines():
            line = line.strip()
            if not line or line.lower().startswith("node,"):
                continue
            f = line.split(",")
            if len(f) >= 5 and f[-1].strip().isdigit():
                rows.append({
                    "seq": int(f[-1]), "created": f[1],
                    "desc": ",".join(f[2:-2]), "type": f[-2]})
        if rows:
            return rows
    except FileNotFoundError:
        pass
    import json
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Get-ComputerRestorePoint | Select-Object "
         "SequenceNumber,Description,CreationTime,"
         "RestorePointType | ConvertTo-Json -Compress"],
        capture_output=True, text=True)
    rows = []
    try:
        data = json.loads(r.stdout)
    except Exception:
        return rows
    if isinstance(data, dict):
        data = [data]
    for d in data:
        rows.append({
            "seq": int(d.get("SequenceNumber") or 0),
            "created": str(d.get("CreationTime") or ""),
            "desc": str(d.get("Description") or ""),
            "type": str(d.get("RestorePointType") or "")})
    return rows


def main():
    home = Path(os.environ.get("DEVOPT_HOME", "D:\\DevOptimizer"))
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    log = home / "logs" / f"restore-points-{ts}.log"
    try:
        pts = restore_points()
    except FileNotFoundError:
        pts = []
    if pts:
        pts.sort(key=lambda p: -p["seq"])
        out = "".join(
            f'{p["seq"]:>10}  {p["created"]:<15} '
            f'{p["type"]:<4} {p["desc"]}\n'
            for p in pts[:10])
        out += f"\nTotal restore points: {len(pts)}"
    else:
        out = "No restore points found or access denied."
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(out, encoding="utf-8")
    print(out)
    if pts:
        print(f"Restore points logged to: {log}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
