"""DevOptimizer system launcher (port of
tools/Old-Launchers/DEVOPTIMIZER-WORKING-LAUNCHER.bat).

Shows a quick status check (Ollama / OneDrive / Cursor AI online),
then an interactive menu that calls the sibling .bat tools in
tools/Old-Launchers (the original launcher dir). Choice keys and
targets match the original. --dry-run prints instead of running.
"""

import argparse
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: launcher, menu, interactive

SCRIPT_DIR = Path(__file__).resolve().parent
_LAUNCHER_DIR = SCRIPT_DIR.parents[1] / "tools" / "Old-Launchers"
LAUNCH_DIR = (_LAUNCHER_DIR if _LAUNCHER_DIR.is_dir() else SCRIPT_DIR)
LOG_DIR = LAUNCH_DIR / "logs"

OPTIONS = {
    "1": ("Ollama Model Manager", "OLLAMA-MODEL-MANAGER.bat"),
    "2": ("Ollama Server Manager", "OLLAMA-SERVER-MANAGER.bat"),
    "3": ("Ollama Quick Tests", "OLLAMA-QUICK-TESTS.bat"),
    "4": ("M365 Troubleshooter", "M365-TROUBLESHOOTER.bat"),
    "5": ("Cursor AI Troubleshooter", "CURSOR-AI-TROUBLESHOOTER.bat"),
    "6": ("Ollama Troubleshooter", "OLLAMA-TROUBLESHOOTER.bat"),
    "7": ("OneDrive Manager", "ONEDRIVE-MANAGER.bat"),
    "8": ("System Health Check", "06-System-Health-Check.bat"),
    "9": ("Performance Optimization", "001-Quick-Optimization.bat"),
    "A": ("Development Tools Manager", "DEVTOOLS-MANAGER.bat"),
    "B": ("System Backup Manager", "SYSTEM-BACKUP-MANAGER.bat"),
    "C": ("Network Manager", "NETWORK-MANAGER.bat"),
    "D": ("Security Manager", "SECURITY-MANAGER.bat"),
    "E": ("System Performance Monitor",
          "SYSTEM-PERFORMANCE-MONITOR.bat"),
    "F": ("DevOptimizer Comprehensive Launcher",
          "DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat"),
}

STATUS_PROCS = [("Ollama", "ollama"), ("OneDrive", "onedrive"),
                ("Cursor AI", "cursor")]


def _proc_running(needle):
    try:
        out = subprocess.run(["tasklist"], capture_output=True,
                             text=True).stdout
        return needle.lower() in out.lower()
    except OSError:
        return False


def quick_status():
    print("=" * 64)
    print("                     QUICK SYSTEM STATUS")
    print("=" * 64)
    for label, needle in STATUS_PROCS:
        state = "ONLINE" if _proc_running(needle) else "OFFLINE"
        print(f"[STATUS] {label}: {state}")
    print()



def find_tool(name):
    """Locate a sibling .bat the launcher menu points at.

    In the deployed flat layout every .bat sits beside the launcher;
    in the repo they are spread across categories/*, tools/*, root.
    """
    cands = [LAUNCH_DIR]
    root = SCRIPT_DIR.parents[1]
    cands += [root, root / "categories", root / "tools",
              root / "tools" / "Variants", root / "portable"]
    for base in cands:
        p = base / name
        if p.exists():
            return p
    # recursive category search as last resort
    hits = list(root.rglob(name))
    return hits[0] if hits else None


def dispatch(target, dry):
    path = find_tool(target)
    if path is None and not dry:
        print(f"[ERROR] tool not found: {target}")
        return 1
    cmd = ["cmd", "/c", str(path)]
    if dry:
        print("[dry-run]", " ".join(cmd))
        return 0
    try:
        return subprocess.run(cmd, cwd=str(LAUNCH_DIR)).returncode
    except OSError as e:
        print(f"failed to run {target}: {e}", file=sys.stderr)
        return 1


def main():
    ap = argparse.ArgumentParser(
        description="DevOptimizer system launcher")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    print("=" * 64)
    print("                 DEVOPTIMIZER SYSTEM LAUNCHER")
    print("=" * 64)
    try:
        LOG_DIR.mkdir(exist_ok=True)
    except OSError:
        print("[ERROR] Failed to create logs directory")
        return 1
    print("[SUCCESS] DevOptimizer System initialized successfully\n")

    while True:
        quick_status()
        print("=" * 64)
        print("                     AVAILABLE OPTIONS")
        print("=" * 64)
        for key, (label, _t) in OPTIONS.items():
            print(f"[{key}] {label}")
        print("[0] Exit\n")
        choice = input("Enter your choice: ").strip().upper()
        if choice == "0":
            return 0
        if choice not in OPTIONS:
            print("Invalid choice. Please try again.\n")
            continue
        label, target = OPTIONS[choice]
        print(f"\n[INFO] Launching {label}...\n")
        dispatch(target, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
