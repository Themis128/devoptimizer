# REQUIRES: admin
"""Port of scripts/create-restore-point.ps1.

Creates a MODIFY_SETTINGS system restore point named
"Pre-restore audit <ts>" and verifies it appears.
"""

import subprocess
import sys
from datetime import datetime


def main():
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    desc = f"Pre-restore audit {ts}"
    print(f"Creating system restore point: {desc}")
    # SystemRestore.CreateRestorePoint(desc, type, event=100)
    # RestorePointType 0=APPLICATION_INSTALL, 12=MODIFY_SETTINGS
    r = subprocess.run(
        ["wmic", "/namespace:\\\\root\\default", "path",
         "SystemRestore", "call", "CreateRestorePoint",
         f'"{desc}"', "12", "100"],
        capture_output=True, text=True)
    if r.returncode != 0 or "ReturnValue = 0" not in r.stdout:
        print("Failed to create restore point: "
              f"{(r.stdout + r.stderr).strip()[:400]}",
              file=sys.stderr)
        return 1
    print("System restore point created successfully.")
    # Verify
    v = subprocess.run(
        ["wmic", "/namespace:\\\\root\\default", "path",
         "SystemRestore", "get",
         "Description,CreationTime,SequenceNumber",
         "/format:csv"],
        capture_output=True, text=True)
    for line in v.stdout.splitlines():
        if desc in line:
            f = line.split(",")
            print(f"Verified restore point: Sequence {f[-1].strip()},"
                  f" Time {f[1]}")
            break
    return 0


if __name__ == "__main__":
    sys.exit(main())
