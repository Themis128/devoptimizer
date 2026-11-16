"""Port of scripts/check-restore-points.ps1.

Lists the 10 most recent system restore points via WMI SystemRestore.
"""

import subprocess
import sys


def restore_points():
    """Return [{'seq','created','desc','type'}]."""
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
            # Node,CreationTime,Description,RestorePointType,
            # SequenceNumber - rejoin commas inside Description
            if len(f) >= 5 and f[-1].strip().isdigit():
                rows.append({
                    "seq": int(f[-1]), "created": f[1],
                    "desc": ",".join(f[2:-2]), "type": f[-2]})
        if rows:
            return rows
    except FileNotFoundError:
        pass
    # Fallback: no wmic (deprecated on Win11) -> powershell cmdlet
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
    try:
        pts = restore_points()
    except FileNotFoundError:
        pts = []
    if pts:
        pts.sort(key=lambda p: -p["seq"])
        print(f'{"Sequence":>10}  {"Created":<15} {"Type":<4} '
              f'Description')
        for p in pts[:10]:
            print(f'{p["seq"]:>10}  {p["created"]:<15} '
                  f'{p["type"]:<4} {p["desc"]}')
        print(f"Total restore points: {len(pts)}")
    else:
        print("No restore points found or access denied.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
