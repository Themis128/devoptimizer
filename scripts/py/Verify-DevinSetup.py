"""Verify Devin Desktop/CLI/WSL/DevOptimizer setup (port of Verify-DevinSetup.ps1).

Read-only checks: Devin.exe, devin-desktop CLI, WSL Ubuntu-24.04,
devin-server, host memory, credentials.toml, required scripts, MCP/hooks/
skills config, and the daily-maintenance task.
Exit: 0 ok, 2 warnings, 1 failures.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: devin, verify, setup

REQUIRED_SCRIPTS = ["Check-DevinHealth.ps1", "Get-DevinDiagnostics.ps1",
                    "Check-DevinDoctor.ps1", "Invoke-DevinDailyMaintenance.ps1",
                    "Repair-Devin.ps1", "Tune-Windows-For-Devin.ps1"]
DISTRO = "Ubuntu-24.04"


def wsl(cmd: str, timeout: int = 30) -> str:
    r = subprocess.run(["wsl.exe", "-d", DISTRO, "--", "bash", "-c", cmd],
                       capture_output=True, text=True, timeout=timeout)
    return r.stdout


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fix-issues", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    results = []

    def add(check, status, detail, fix=""):
        results.append({"check": check, "status": status,
                        "detail": detail, "fix": fix})

    # 1. Devin Desktop
    devin_exe = Path(os.environ.get("LOCALAPPDATA", "")) / r"Programs\Devin\Devin.exe"
    if devin_exe.exists():
        add("Devin Desktop", "OK", f"at {devin_exe}")
    else:
        add("Devin Desktop", "FAIL", f"not found at {devin_exe}",
            "Run Install-DevinCLI.ps1 or download from https://devin.ai")

    # 2. Devin CLI
    cli = shutil.which("devin-desktop")
    if cli:
        try:
            ver = subprocess.run(["devin-desktop", "--version"],
                                 capture_output=True, text=True,
                                 timeout=15).stdout.splitlines()[0]
        except Exception:
            ver = "unknown"
        add("Devin CLI", "OK", f"{ver} at {cli}")
    else:
        add("Devin CLI", "WARN", "not in PATH",
            "Run Install-DevinCLI.ps1 or restart terminal")

    # 3. WSL distro
    try:
        ping = wsl("echo ok")
        if "ok" in ping:
            up = wsl("cat /proc/uptime").split()[0]
            add("WSL Ubuntu-24.04", "OK", f"reachable, uptime {float(up)/3600:.1f}h")
        else:
            add("WSL Ubuntu-24.04", "FAIL", "unreachable",
                "Run: wsl -d Ubuntu-24.04 --exec true")
    except Exception:
        add("WSL Ubuntu-24.04", "FAIL", "unreachable",
            "Run: wsl -d Ubuntu-24.04 --exec true")

    # 4. devin-server
    try:
        procs = wsl("pgrep -af 'devin acp' || true")
        import re
        m = re.search(r"\.devin-server/bin/([a-f0-9]{40})/", procs)
        if m:
            add("devin-server", "OK", f"running (commit {m.group(1)})")
        else:
            add("devin-server", "WARN", "not running",
                "Click 'Reload Window' in Devin Desktop")
    except Exception:
        add("devin-server", "WARN", "check failed")

    # 5. Host memory via PS
    mem = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB,1)"],
        capture_output=True, text=True, timeout=30)
    try:
        free_gb = float(mem.stdout.strip())
        if free_gb >= 2:
            add("Host Memory", "OK", f"{free_gb} GB free")
        elif free_gb >= 1:
            add("Host Memory", "WARN", f"{free_gb} GB free - low",
                "Run win11-safe-cleanup.ps1 -RunNow")
        else:
            add("Host Memory", "FAIL", f"{free_gb} GB free - critical",
                "Run win11-admin-cleanup-elevated.ps1 -Force (elevated)")
    except ValueError:
        add("Host Memory", "WARN", "could not read free memory")

    # 6. Credentials
    creds = Path(os.environ.get("APPDATA", "")) / r"devin\credentials.toml"
    add("Credentials", "OK" if creds.exists() else "WARN",
        f"found at {creds}" if creds.exists() else "not found",
        "" if creds.exists() else "Run: devin login")

    # 7. DevOptimizer scripts
    sdir = Path(r"D:\DevOptimizer\scripts\devin")
    missing = [s for s in REQUIRED_SCRIPTS if not (sdir / s).exists()]
    if not missing:
        add("DevOptimizer Scripts", "OK", "all 6 present")
    else:
        add("DevOptimizer Scripts", "FAIL", f"missing: {', '.join(missing)}")

    # 8. DevOptimizer integration
    cfg_dir = Path(os.environ.get("APPDATA", "")) / "devin"
    missing_cfg = [f for f in ("mcp_config.json", "hooks.v1.json")
                   if not (cfg_dir / f).exists()]
    if not (cfg_dir / r"skills\devin-integration\SKILL.md").exists():
        missing_cfg.append("skills/devin-integration/SKILL.md")
    if not missing_cfg:
        add("DevOptimizer Integration", "OK", "MCP config, hooks, skill configured")
    else:
        add("DevOptimizer Integration", "WARN",
            f"missing: {', '.join(missing_cfg)}")

    # 9. Scheduled task
    task = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "if (Get-ScheduledTask -TaskName 'Devin-Daily-Maintenance' "
         "-ErrorAction SilentlyContinue) { 'yes' }"],
        capture_output=True, text=True, timeout=30)
    if "yes" in task.stdout:
        add("Daily Maintenance Task", "OK", "registered")
    else:
        add("Daily Maintenance Task", "WARN", "not registered",
            "Run Register-Devin-Maintenance.ps1")

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print("=== Devin Setup Verification ===")
        for r in results:
            mark = {"OK": "[OK]", "WARN": "[!]", "FAIL": "[X]"}[r["status"]]
            print(f"{mark} {r['check']}: {r['detail']}")

    ok = sum(1 for r in results if r["status"] == "OK")
    warn = sum(1 for r in results if r["status"] == "WARN")
    fail = sum(1 for r in results if r["status"] == "FAIL")
    print(f"\nOK: {ok}  WARN: {warn}  FAIL: {fail}", file=sys.stderr)
    if args.fix_issues and (warn or fail):
        print("auto-fix not implemented - run the individual fix scripts",
              file=sys.stderr)
    sys.exit(1 if fail else (2 if warn else 0))


if __name__ == "__main__":
    main()
