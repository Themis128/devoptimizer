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
    q = lambda *a: a  # noqa: E731
    return [
        ("Critical Files Existence",
         f'if exist "{s}\\01-Quick-Optimization.bat" if exist '
         f'"{s}\\06-System-Health-Check.bat" if exist '
         f'"{s}\\00-LAUNCHER.bat" echo Files exist'),
        ("PowerShell Script Integrity",
         f'if exist "{s}\\dev-optimizer-fixed.ps1" echo Script exists'),
        ("Configuration File Integrity",
         f'if exist "{s}\\bat.config.json" echo Config exists'),
        ("Error Logging Implementation",
         f'findstr /c:":log_error" "{s}\\01-Quick-Optimization.bat"'),
        ("Error Checking Implementation",
         f'findstr /c:":check_error" "{s}\\01-Quick-Optimization.bat"'),
        ("Retry Logic Implementation",
         f'findstr /c:"RETRY_COUNT" "{s}\\06-System-Health-Check.bat"'),
        ("Progress Indicators",
         f'findstr /c:":show_progress" "{s}\\06-System-Health-Check.bat"'),
        ("No Timeout Delays",
         f'findstr /v /c:"timeout /t" "{s}\\01-Quick-Optimization.bat"'),
        ("Fast Delay Implementation",
         f'findstr /c:"ping -n" "{s}\\01-Quick-Optimization.bat"'),
        ("Optimized Loops",
         f'findstr /c:"for /l" "{s}\\06-System-Health-Check.bat"'),
        ("PowerShell Execution Policy",
         'powershell -Command "Get-ExecutionPolicy" | '
         'findstr /i "Bypass"'),
        ("File System Access", f'dir "{s}"'),
        ("README Documentation",
         f'if exist "{s}\\README.md" echo README exists'),
        ("Troubleshooting Guide",
         f'if exist "{s}\\TROUBLESHOOTING.md" '
         'echo Troubleshooting exists'),
        ("Configuration Documentation",
         f'findstr /c:"success_rate" "{s}\\bat.config.json"'),
        ("Auto-Recovery System",
         f'if exist "{s}\\AUTO-RECOVERY-SYSTEM.bat" '
         'echo Auto-recovery exists'),
        ("Health Monitoring",
         f'if exist "{s}\\HEALTH-MONITOR.bat" '
         'echo Health monitor exists'),
        ("Real-Time Monitoring",
         f'if exist "{s}\\REAL-TIME-MONITOR.bat" '
         'echo Real-time monitor exists'),
        ("Test Suite Implementation",
         f'if exist "{s}\\COMPREHENSIVE-TEST-SUITE.bat" '
         'echo Test suite exists'),
        ("Quality Gates Implementation",
         f'if exist "{s}\\QUALITY-GATES.bat" echo Quality gates exist'),
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
    for i, (name, cmd) in enumerate(gates(s), 1):
        cmd += " >nul 2>&1" if ">nul" not in cmd else ""
        log(logf, f"Running Quality Gate: {name}")
        r = subprocess.run(cmd, shell=True,
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
        passed = r.returncode == 0
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
