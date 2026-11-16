"""Timeout-delay optimizer for sibling .bat files (port of
tools/Variants/OPTIMIZE-TIMEOUT-DELAYS-NoAdmin.bat).

Scans *.bat files next to the script, backs each up to
<file>.backup, rewrites `timeout /t N` delays as
`ping 127.0.0.1 -n 2`, and injects a
"Performance Optimized - No Timeout Delays" header when absent.
Logs to logs/timeout-optimization.log. Standard (non-admin) mode.
"""

import argparse
import datetime
import re
import shutil
from pathlib import Path

# CATEGORY: utilities
# TAGS: optimization, batch, rewrite

SCRIPT_DIR = Path(__file__).resolve().parent
LOG_FILE = SCRIPT_DIR / "logs" / "timeout-optimization.log"
HEADER = ":: Performance Optimized - No Timeout Delays"


def log(msg):
    LOG_FILE.parent.mkdir(exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(f"[{datetime.datetime.now()}] {msg}\n")


def optimize_file(path: Path) -> None:
    print(f"Optimizing: {path.name}")
    log(f"Optimizing file: {path.name}")
    shutil.copy2(path, path.with_suffix(path.suffix + ".backup"))
    text = path.read_text(encoding="utf-8", errors="replace")
    text = re.sub(r"timeout /t \d+ /nobreak >nul",
                  "ping 127.0.0.1 -n 2 >nul", text)
    text = re.sub(r"timeout /t \d+", "ping 127.0.0.1 -n 2 >nul",
                  text)
    if HEADER not in text:
        print("Adding performance optimization header...")
        lines = text.splitlines()
        new = ["@echo off",
               "setlocal EnableExtensions EnableDelayedExpansion",
               HEADER, "", *lines[1:]]
        text = "\n".join(new)
    path.write_text(text, encoding="utf-8")
    print(f"  Optimized: {path.name}")
    log(f"Successfully optimized: {path.name}")


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true",
                    help="scan and report only, no writes")
    args = ap.parse_args()

    print("=" * 64)
    print("                TIMEOUT DELAY OPTIMIZER")
    print("              Phase 2: Performance Optimization")
    print("=" * 64)
    print("\nStarting timeout delay optimization...")
    log("Starting timeout delay optimization")

    total = optimized = 0
    for bat in sorted(SCRIPT_DIR.glob("*.bat")):
        total += 1
        try:
            text = bat.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if "timeout" in text:
            if args.dry_run:
                print(f"[dry-run] would optimize {bat.name}")
                continue
            optimize_file(bat)
            optimized += 1
            print(f"[{'#' * min(20, optimized):<20}] {optimized} "
                  f"files")

    print("\n" + "=" * 64)
    print("                OPTIMIZATION COMPLETE")
    print("=" * 64)
    print(f"\nFiles scanned: {total}")
    print(f"Files optimized: {optimized}")
    print(f"Log file: {LOG_FILE}\n")
    if optimized:
        print(f"SUCCESS: {optimized} files optimized for "
              "performance")
    else:
        print("INFO: No files with timeout delays found")
    log(f"Optimization completed - {optimized} files optimized")


if __name__ == "__main__":
    main()
