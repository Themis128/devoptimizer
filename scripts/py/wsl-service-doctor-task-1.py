"""WSL service doctor task (port of
scripts/wsl-service-doctor-task.ps1).

Skips when vmmemWSL absent or docker CLI unreachable; otherwise runs
service-doctor.sh per service, appending
logs/service-doctor.log. --dry-run; --json.
"""

import argparse
import asyncio
import datetime
import json
import os
import subprocess
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: maintenance
# TAGS: wsl, docker, services, watchdog

SERVICES = ["mautic", "metabase", "n8n", "social-api", "authentik",
            "nextcloud", "postiz", "espocrm"]
DOCTOR = ("/mnt/c/Users/tbaltzakis/AppData/Roaming/devin/skills/"
          "wsl-service-healer/scripts/service-doctor.sh")
LOG_FILE = r"D:\DevOptimizer\logs\service-doctor.log"


def wsl(args_, timeout=120):
    env = dict(os.environ, WSL_UTF8="1")
    return subprocess.run(["wsl.exe", "-d", "Ubuntu-24.04", "-e",
                           "bash", *args_], capture_output=True,
                          text=True, timeout=timeout, env=env)


def log(line: str, path: Path):
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(path, "a") as fh:
        fh.write(f"{stamp} {line}\n")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--log", default=LOG_FILE)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    env = dict(os.environ, WSL_UTF8="1")
    vm = subprocess.run(["tasklist", "/FI", "IMAGENAME eq vmmemWSL"],
                        capture_output=True, text=True, env=env)
    if "vmmemWSL" not in vm.stdout:
        if args.dry_run:
            print("[dry-run] would skip: vmmemWSL absent")
            return
        log("WSL not running (skipped)", Path(args.log))
        return

    if args.dry_run:
        for s in SERVICES:
            print(f"[dry-run] wsl service-doctor {s}")
        return

    r = wsl(["-c", "command -v docker >/dev/null 2>&1"])
    if r.returncode != 0:
        log("docker CLI absent in distro (Docker Desktop down?) "
            "- sweep skipped", Path(args.log))
        return

    findings = 0
    results = {}
    for s in SERVICES:
        out = wsl([DOCTOR, s]).stdout
        for line in out.splitlines():
            if line.strip():
                log(f"[{s}] {line}", Path(args.log))
        results[s] = out.strip()
        findings += sum(1 for l in out.splitlines()
                        if "WARN" in l or "FAIL" in l or "DRIFT" in l)
    if findings and not args.dry_run:
        asyncio.run(run_ps_command(
            "Write-EventLog -LogName 'DevOptimizer' "
            "-Source 'DevOptimizer' -EventId 1004 -EntryType Warning "
            "-Message \"service-doctor sweep found " + str(findings) +
            " issue(s) in WSL stack - see " + args.log + "\" "
            "-ErrorAction SilentlyContinue"))
    if args.json:
        print(json.dumps({"findings": findings, "services": results}))
    else:
        print(f"sweep complete: {findings} findings "
              f"-> {args.log}")


if __name__ == "__main__":
    main()
