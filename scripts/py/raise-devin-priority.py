"""Port of scripts/raise-devin-priority.ps1 — set Devin Desktop
processes' priority class to High. --loop keeps adjusting every
--interval seconds; --verbose logs every check.
"""
import argparse
import datetime
import subprocess
import sys
import time

# CATEGORY: maintenance
# TAGS: priority, devin, processes

PRIORITY_HIGH = 0x00000080  # HIGH_PRIORITY_CLASS (Win32)


def log(msg, level="INFO", verbose=False):
    if verbose or level in ("WARN", "ERROR"):
        print(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} "
              f"[{level}] {msg}")


def find_devin_pids():
    """PIDs whose image name contains 'devin' (case-insensitive)."""
    try:
        r = subprocess.run(["wmic", "process", "where",
                            "Name like '%Devin%'", "get",
                            "ProcessId"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            raise OSError("wmic failed")
        return [int(t) for t in r.stdout.split() if t.isdigit()]
    except OSError:
        # wmic deprecated on newer Win11 — fall back to tasklist CSV
        out = subprocess.run(
            ["tasklist", "/fo", "csv", "/nh"], capture_output=True,
            text=True).stdout
        import csv
        pids = []
        for row in csv.reader(out.splitlines()):
            if len(row) >= 2 and "devin" in row[0].lower():
                pids.append(int(row[1].strip('"')))
        return pids


def set_priority(pid, priority=PRIORITY_HIGH, verbose=False):
    """Set priority class via PowerShell (native Win32 path)."""
    ps = (f"$p = Get-Process -Id {pid} -ErrorAction SilentlyContinue; "
          f"if (-not $p) {{ exit 2 }}; "
          f"if ($p.PriorityClass -eq {priority}) {{ exit 3 }}; "
          f"$p.PriorityClass = {priority}")
    r = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                       capture_output=True)
    if r.returncode == 3:
        if verbose:
            log(f"PID {pid} already at High", verbose=verbose)
        return False
    if r.returncode == 0:
        log(f"Set PID {pid} priority -> High")
        return True
    if r.returncode != 2:
        log(f"Failed to set priority for PID {pid}", "WARN")
    return False


def adjust(verbose=False):
    pids = find_devin_pids()
    if not pids:
        log("No Devin processes found", verbose=verbose)
        return 0
    return sum(1 for p in pids
               if set_priority(p, verbose=verbose))


def main():
    ap = argparse.ArgumentParser(
        description="Raise Devin Desktop process priority to High")
    ap.add_argument("--loop", action="store_true",
                    help="run continuously")
    ap.add_argument("--interval", type=int, default=30,
                    help="loop interval seconds (default 30)")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    try:
        if args.loop:
            log(f"Loop mode (interval: {args.interval}s). "
                "Ctrl+C to stop.", verbose=True)
            while True:
                n = adjust(args.verbose)
                if n:
                    log(f"Adjusted priority for {n} process(es)")
                time.sleep(args.interval)
        else:
            pids = find_devin_pids()
            n = adjust(args.verbose)
            if pids:
                log(f"Adjusted priority for {n} of "
                    f"{len(pids)} process(es)")
        log("=== Devin Priority Adjustment Completed ===")
        return 0
    except KeyboardInterrupt:
        log("=== Devin Priority Adjustment Completed ===")
        return 0
    except Exception as e:
        log(f"=== Devin Priority Adjustment FAILED: {e} ===", "ERROR")
        return 1


if __name__ == "__main__":
    sys.exit(main())
