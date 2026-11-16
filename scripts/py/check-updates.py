"""Port of scripts/check-updates.ps1 — list pending Windows updates
via the Microsoft.Update.Session COM object. --json for machine output.
"""
# REQUIRES: admin
import ctypes

def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required", file=sys.stderr)
        sys.exit(1)

import json
import subprocess
import sys


def main():
    ps = r"""
$session = New-Object -ComObject Microsoft.Update.Session
$searcher = $session.CreateUpdateSearcher()
$result = $searcher.Search("IsInstalled=0")
$out = [PSCustomObject]@{
    Pending = $result.Updates.Count
    Updates = @($result.Updates | ForEach-Object {
        [PSCustomObject]@{
            Title = $_.Title
            IsDownloaded = [bool]$_.IsDownloaded
            IsMandatory = [bool]$_.IsMandatory
            RebootRequired = [bool]$_.RebootRequired
        }
    })
}
if ($null -eq $result) { exit 5 }
$out | ConvertTo-Json -Depth 4
"""
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr or "update search failed",
              file=sys.stderr)
        return r.returncode
    raw = r.stdout.strip()
    data = (json.loads(raw) if raw else None) \
        or {"Pending": 0, "Updates": []}
    if "--json" in sys.argv:
        print(json.dumps(data, indent=2))
        return 0
    print(f"Pending updates: {data['Pending']}")
    for u in data.get("Updates", []):
        flags = [k for k in ("IsDownloaded", "IsMandatory",
                           "RebootRequired") if u.get(k)]
        print(f"  {u['Title']}"
              + (f"  [{', '.join(flags)}]" if flags else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
