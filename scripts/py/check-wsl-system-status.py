"""Port of scripts/check-wsl-system-status.ps1.

Read-only WSL fine-tune status: host RAM, vmmemWSL
working set, in-VM memory/swap, on-demand container
set, docker disk usage. -ApplySafeCleanup also runs
win11-safe-cleanup.ps1.
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


def run(cmd, timeout=30):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=timeout)
    except Exception:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-ApplySafeCleanup",
                    action="store_true")
    a = ap.parse_args()

    import datetime
    print(f"=== WSL & System Fine-Tune Status -- "
          f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} "
          "===")
    r = run(["powershell", "-NoProfile", "-Command",
             "(Get-CimInstance Win32_OperatingSystem)"
             ".FreePhysicalMemory"])
    try:
        free_gb = round(int(r.stdout.strip()) / 2**20, 1)
    except Exception:
        free_gb = 0
    print(f"Host RAM free : {free_gb} GB")

    r = run(["tasklist", "/FI",
             "IMAGENAME eq vmmemWSL", "/FO", "CSV",
             "/NH"])
    vmmem = bool(r and "vmmemWSL" in r.stdout)
    if vmmem:
        m = re.search(r'"([\d,\.]+)\s*K"',
                      r.stdout.split(",")[-1])
        ws = ""
        r2 = run(["powershell", "-NoProfile", "-Command",
                  "(Get-Process vmmemWSL | "
                  "Select-Object -First 1).WS"])
        try:
            ws = f"{int(r2.stdout.strip())/2**30:.2f} GB"
        except Exception:
            ws = "?"
        print(f"vmmemWSL      : {ws} working set "
              "(WSL running)")
        r = run(["wsl", "-e", "bash", "-c",
                 "free -m; df -h /mnt/wslg/distro | "
                 "tail -1"])
        for line in ((r.stdout if r else "")
                     .splitlines()):
            if re.match(r"^(Mem|Swap):", line):
                f = line.split()
                print(f"WSL {f[0]:<10} total {f[1]} MB, "
                      f"used {f[2]} MB")
        r = run(["wsl", "-e", "docker", "ps", "-a",
                 "--format",
                 "{{.Names}} {{.Status}}"])
        print("\nOn-demand containers:")
        print(r.stdout if r and r.stdout
              else "  (docker unavailable)")
    else:
        print("vmmemWSL      : not running (skipping "
              "in-VM checks)")
    u = shutil.disk_usage("C:\\")
    print(f"C: free {u.free/2**30:.1f} / "
          f"{u.total/2**30:.1f} GB")

    if a.ApplySafeCleanup:
        p = Path("D:/DevOptimizer/scripts/"
                 "win11-safe-cleanup.ps1")
        if p.exists():
            ps = (shutil.which("pwsh")
                  or shutil.which("powershell"))
            subprocess.run(
                [ps, "-NoProfile", "-File", str(p)])
    return 0


if __name__ == "__main__":
    sys.exit(main())
