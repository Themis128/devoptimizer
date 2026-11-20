"""Quality gates runner (port of tools/Variants/QUALITY-GATES-*.bat).

Runs each named gate command, logs pass/fail to
logs/quality-gates.log, exits non-zero if any gate fails.
--admin variant check; --json for machine output.
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# CATEGORY: utilities
# TAGS: quality, gates, verification

SCRIPT_DIR = Path(r"D:\DevOptimizer")


def gates(s: Path):
    """Gates as (name, check) pairs - no shell, no command strings."""
    bat1 = s / "01-Quick-Optimization.bat"
    bat6 = s / "06-System-Health-Check.bat"

    def exists(*paths: Path) -> bool:
        return all(p.is_file() for p in paths)

    def grep(path: Path, needle: str) -> bool:
        try:
            return needle in path.read_text(encoding="utf-8",
                                             errors="replace")
        except OSError:
            return False

    def grep_any_without(path: Path, needle: str) -> bool:
        try:
            lines = path.read_text(encoding="utf-8",
                                   errors="replace").splitlines()
        except OSError:
            return False
        return any(needle not in ln for ln in lines)

    def exec_policy_allows_bypass() -> bool:
        try:
            r = subprocess.run(
                ["powershell", "-NoProfile", "-Command",
                 "Get-ExecutionPolicy"],
                capture_output=True, text=True)
        except OSError:
            return False
        return "bypass" in (r.stdout or "").strip().lower()

    return [
        ("Critical Files Existence",
         lambda: exists(s / "01-Quick-Optimization.bat",
                        s / "06-System-Health-Check.bat",
                        s / "00-LAUNCHER.bat")),
        ("PowerShell Script Integrity",
         lambda: exists(s / "dev-optimizer-fixed.ps1")),
        ("Configuration File Integrity",
         lambda: exists(s / "bat.config.json")),
        ("Error Logging Implementation",
         lambda: grep(bat1, ":log_error")),
        ("Error Checking Implementation",
         lambda: grep(bat1, ":check_error")),
        ("Retry Logic Implementation",
         lambda: grep(bat6, "RETRY_COUNT")),
        ("Progress Indicators",
         lambda: grep(bat6, ":show_progress")),
        ("No Timeout Delays",
         lambda: grep_any_without(bat1, "timeout /t")),
        ("Fast Delay Implementation",
         lambda: grep(bat1, "ping -n")),
        ("Optimized Loops",
         lambda: grep(bat6, "for /l")),
        ("PowerShell Execution Policy",
         exec_policy_allows_bypass),
        ("File System Access", lambda: s.is_dir()),
        ("README Documentation",
         lambda: exists(s / "README.md")),
        ("Troubleshooting Guide",
         lambda: exists(s / "TROUBLESHOOTING.md")),
        ("Configuration Documentation",
         lambda: grep(s / "bat.config.json", "success_rate")),
        ("Auto-Recovery System",
         lambda: exists(s / "AUTO-RECOVERY-SYSTEM.bat")),
        ("Health Monitoring",
         lambda: exists(s / "HEALTH-MONITOR.bat")),
        ("Real-Time Monitoring",
         lambda: exists(s / "REAL-TIME-MONITOR.bat")),
        ("Test Suite Implementation",
         lambda: exists(s / "COMPREHENSIVE-TEST-SUITE.bat")),
        ("Quality Gates Implementation",
         lambda: exists(s / "QUALITY-GATES.bat")),
    ]


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def log(logf, msg):
    line = f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line, file=sys.stderr)
    logf.parent.mkdir(parents=True, exist_ok=True)
    with open(logf, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--json", action="store_true")
    p.add_argument("--script-dir", default=str(SCRIPT_DIR))
    args = p.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)

    s = Path(args.script_dir)
    logf = s / "logs" / "quality-gates.log"
    results = []
    for i, (name, check) in enumerate(gates(s), 1):
        log(logf, f"Running Quality Gate: {name}")
        try:
            passed = bool(check())
        except OSError:
            passed = False
        results.append({"gate": i, "name": name, "passed": passed})
        log(logf, f"{'PASSED' if passed else 'FAILED'}: {name}")

    passed_n = sum(r["passed"] for r in results)
    if args.json:
        print(json.dumps({"total": len(results), "passed": passed_n,
                          "results": results}))
    print(f"\nQuality Gates: {passed_n}/{len(results)} passed",
          file=sys.stderr)
    sys.exit(0 if passed_n == len(results) else 1)


if __name__ == "__main__":
    main()
