"""Port of scripts/fix-remaining-tasks-elevated.ps1 — fix the three
\\DevOptimizer\\ tasks missing `-WindowStyle Hidden` in their action
args (Devin-Weekly-Restart, WSL-Memory-Watchdog,
Devin-Daily-Maintenance) via schtasks /change. Elevated.
--dry-run prints only.
"""
# REQUIRES: admin

import argparse
import subprocess
import sys

# CATEGORY: maintenance
# TAGS: scheduled-task, popup-suppression

TASKS = {
    "Devin-Weekly-Restart": (
        '--headless C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\'
        'powershell.exe -WindowStyle Hidden -NoProfile '
        '-ExecutionPolicy Bypass -File '
        '"D:\\DevOptimizer\\scripts\\restart-devin-weekly.ps1"'),
    "WSL-Memory-Watchdog": (
        '--headless C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\'
        'powershell.exe -WindowStyle Hidden -NoProfile '
        '-ExecutionPolicy Bypass -File '
        '"D:\\DevOptimizer\\scripts\\check-wsl-memory-pressure.ps1"'),
    "Devin-Daily-Maintenance": (
        '--headless C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\'
        'powershell.exe -WindowStyle Hidden -NoProfile '
        '-ExecutionPolicy Bypass -File '
        '"D:\\DevOptimizer\\scripts\\devin\\'
        'Invoke-DevinDailyMaintenance.ps1"'),
}


def current_args(task_name, dry):
    """Read the task's current action args via schtasks /query /v."""
    if dry:
        return ""
    r = subprocess.run(["schtasks", "/query", "/tn",
                        rf"\DevOptimizer\{task_name}", "/v",
                        "/fo", "LIST"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return None
    for line in r.stdout.splitlines():
        if line.strip().startswith("Task To Run:"):
            return line.split(":", 1)[1].strip()
    return ""


def main():
    ap = argparse.ArgumentParser(
        description="Add -WindowStyle Hidden to DevOptimizer tasks")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    print("Fixing scheduled tasks (requires elevation)...")
    for name, wanted in TASKS.items():
        old = current_args(name, args.dry_run)
        if old is None:
            print(f"Failed {name}: task not found", file=sys.stderr)
            continue
        if not args.dry_run and "WindowStyle Hidden" in old:
            print(f"Already has WindowStyle Hidden: {name}")
            continue
        new_cmd = f"conhost.exe {wanted}"
        if args.dry_run:
            print(f"[dry-run] schtasks /change /tn "
                  f"\\DevOptimizer\\{name} /tr \"{new_cmd}\"")
            continue
        r = subprocess.run(["schtasks", "/change", "/tn",
                            rf"\DevOptimizer\{name}",
                            "/tr", new_cmd],
                           capture_output=True, text=True)
        if r.returncode == 0:
            print(f"Fixed: {name}")
            print(f"   Old: {old}")
            print(f"   New: {new_cmd}")
        else:
            print(f"Failed {name}: {r.stderr.strip()}",
                  file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
