"""Port of scripts/check-restore-points.ps1.

Lists the 10 most recent system restore points via WMI SystemRestore.
"""

import subprocess
import sys


def restore_points():
    """Return [(SequenceNumber, Description, CreationTime, Type)]."""
    r = subprocess.run(
        ["wmic", "/namespace:\\\\root\\default", "path",
         "SystemRestore", "get",
         "Description,CreationTime,SequenceNumber,RestorePointType",
         "/format:csv"],
        capture_output=True, text=True)
    rows = []
    for line in r.stdout.splitlines():
        line = line.strip()
        if not line or line.lower().startswith("node,"):
            continue
        f = line.split(",")
        # Node,CreationTime,Description,RestorePointType,SequenceNumber
        if len(f) >= 5 and f[-1].isdigit():
            rows.append({
                "seq": int(f[-1]), "created": f[1],
                "desc": f[2], "type": f[3]})
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
