"""One-command verification battery for the DevOptimizer repo.

Runs the 7 test surfaces and prints a verdict table. Exit 0 = all green
(health is exempt from the elevated admin check).

Usage: python tools/run-battery.py [--skip-slow]
"""

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PY = REPO / "py"
PW = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WindowsApps" / "pwsh.exe"


def run(name: str, cmd: list[str], cwd: Path, timeout: int, check) -> tuple[str, bool, float, str]:
    started = time.time()
    try:
        proc = subprocess.run(
            cmd, cwd=str(cwd), capture_output=True, text=True,
            timeout=timeout, shell=False,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        ok, detail = check(proc.returncode, out)
    except subprocess.TimeoutExpired:
        return name, False, time.time() - started, "TIMEOUT"
    except OSError as e:
        return name, False, time.time() - started, str(e)[:80]
    return name, ok, time.time() - started, detail


def check_pytest(rc: int, out: str) -> tuple[bool, str]:
    m = re.search(r"(\d+) passed", out)
    return rc == 0, (f"{m.group(1)} passed" if m else "?") + (", warnings" if "warnings" in out else "")


def check_xunit(rc: int, out: str) -> tuple[bool, str]:
    m = re.search(r"Passed! \s*- Failed:\s*(\d+), Passed:\s*(\d+)", out)
    if m:
        return int(m.group(1)) == 0, f"{m.group(2)} passed, {m.group(1)} failed"
    return rc == 0, out.strip().splitlines()[-1][:60] if out.strip() else "?"


def check_pester(rc: int, out: str) -> tuple[bool, str]:
    m = re.search(r"App tests: (\d+) total, (\d+) passed, (\d+) failed", out)
    if m:
        return int(m.group(3)) == 0, f"{m.group(2)}/{m.group(1)} passed"
    return rc == 0, "?"


def check_zero_errors(rc: int, out: str) -> tuple[bool, str]:
    n = len(re.findall(r"^\[ERROR\]", out, re.M))
    return n == 0, f"{n} errors"


def check_syntax(rc: int, out: str) -> tuple[bool, str]:
    ok = "ALL SYNTAX OK" in out
    return ok, "ALL SYNTAX OK" if ok else out.strip().splitlines()[-1][:60]


def check_parity(rc: int, out: str) -> tuple[bool, str]:
    ok = "PARITY OK" in out
    fails = [line for line in out.splitlines() if line.startswith("FAIL")]
    return ok, ("PARITY OK" if ok else "; ".join(fails)[:70])


def check_health(rc: int, out: str) -> tuple[bool, str]:
    m = re.search(r"Score: (\d+) / (\d+)", out)
    if not m:
        return False, "no score"
    score, total = int(m.group(1)), int(m.group(2))
    # 270/275 is the known non-elevated ceiling (AdminRights check);
    # anything below 270 or any error other than AdminRights is a failure.
    errs = re.search(r"Errors:\s*(\d+)", out)
    n_errs = int(errs.group(1)) if errs else 1
    admin_only = "AdminRights" in out and n_errs <= 1
    ok = score >= 270 and (score == total or admin_only)
    return ok, f"{score}/{total}" + (" (admin-only gap)" if score < total and admin_only else "")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the DevOptimizer verification battery")
    parser.add_argument("--skip-slow", action="store_true", help="Skip pytest and health (slowest)")
    args = parser.parse_args()

    pw = str(PW) if PW.exists() else "powershell"

    surfaces = [
        ("xUnit", ["dotnet", "test", "app/DevOptimizer.App.Tests", "-c", "Release",
                   "--nologo", "-v", "q"], REPO, 600, check_xunit),
        ("Pester", [pw, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                    "scripts/Test-App.ps1"], REPO, 600, check_pester),
        ("validate-all", [pw, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                          "validate-all-scripts.ps1"], REPO, 600, check_zero_errors),
        ("ps-syntax", [pw, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                       "scripts/check-all-syntax.ps1"], REPO, 300, check_syntax),
        ("parity", ["python", "tools/parity-check.py"], REPO, 300, check_parity),
    ]
    if not args.skip_slow:
        surfaces.insert(0, ("pytest", ["python", "-m", "pytest", "tests/", "-q"], PY, 600, check_pytest))
        surfaces.append(("health", [pw, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                                    "Check-Health.ps1"], REPO, 600, check_health))

    print(f"=== DevOptimizer battery ({len(surfaces)} surfaces) ===")
    results = []
    for name, cmd, cwd, timeout, check in surfaces:
        sys.stdout.write(f"  {name:<13} ")
        sys.stdout.flush()
        name, ok, secs, detail = run(name, cmd, cwd, timeout, check)
        print(f"{'PASS' if ok else 'FAIL'}  {secs:5.1f}s  {detail}")
        results.append((name, ok))

    failed = [n for n, ok in results if not ok]
    print("=== VERDICT:", "ALL GREEN" if not failed else f"FAILURES: {', '.join(failed)}", "===")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
