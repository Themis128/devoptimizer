"""Port of scripts/check-disks.ps1 - C/D/E usage table."""
import shutil
import sys


def main():
    print(f"{'Name':<6}{'UsedGB':>10}{'FreeGB':>10}"
          f"{'TotalGB':>10}{'FreePct':>9}")
    for d in "CDE":
        try:
            u = shutil.disk_usage(f"{d}:\\")
            used = u.total - u.free
            print(f"{d:<6}{used/2**30:>10.1f}"
                  f"{u.free/2**30:>10.1f}"
                  f"{u.total/2**30:>10.1f}"
                  f"{100*u.free/u.total:>8.0f}%")
        except OSError:
            print(f"{d:<6}  not present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
