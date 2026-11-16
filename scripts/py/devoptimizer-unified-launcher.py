"""DevOptimizer unified launcher (port of
tools/Old-Launchers/DEVOPTIMIZER-UNIFIED-LAUNCHER.bat).

Dual-mode menu: detects admin privileges and shows the full admin
menu; standard users get the limited menu (option 4 omitted, and
[S] switches modes). Dispatches to sibling .bat tools in
tools/Old-Launchers. --dry-run prints instead of running.
"""

import argparse
import ctypes
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: launcher, menu, interactive

SCRIPT_DIR = Path(__file__).resolve().parent
_LAUNCHER_DIR = SCRIPT_DIR.parents[1] / "tools" / "Old-Launchers"
LAUNCH_DIR = (_LAUNCHER_DIR if _LAUNCHER_DIR.is_dir() else SCRIPT_DIR)

ADMIN_OPTIONS = {
    "1": ("Ollama Model Manager", "OLLAMA-MODEL-MANAGER.bat"),
    "2": ("Ollama Server Manager", "OLLAMA-SERVER-MANAGER.bat"),
    "3": ("Ollama Quick Tests", "OLLAMA-QUICK-TESTS.bat"),
    "4": ("M365 Troubleshooter", "M365-TROUBLESHOOTER.bat"),
    "5": ("Cursor AI Troubleshooter", "CURSOR-AI-TROUBLESHOOTER.bat"),
    "6": ("Ollama Troubleshooter", "OLLAMA-TROUBLESHOOTER.bat"),
    "7": ("OneDrive Manager", "ONEDRIVE-MANAGER.bat"),
    "8": ("System Health Check", "SYSTEM-HEALTH-CHECK.bat"),
    "9": ("Performance Optimization", "01-Quick-Optimization.bat"),
    "A": ("Development Tools Manager", "DEVTOOLS-MANAGER.bat"),
    "B": ("System Backup Manager", "SYSTEM-BACKUP-MANAGER.bat"),
    "C": ("Network Manager", "NETWORK-MANAGER.bat"),
    "D": ("Security Manager", "SECURITY-MANAGER.bat"),
    "E": ("System Performance Monitor",
          "SYSTEM-PERFORMANCE-MONITOR.bat"),
    "F": ("DevOptimizer Comprehensive Launcher",
          "DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat"),
}
# User menu: same targets minus M365 (admin-only feature).
USER_OPTIONS = {k: v for k, v in ADMIN_OPTIONS.items() if k != "4"}


def is_admin():
    if sys.platform != "win32":
        return False
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False



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


def show_menu(options, admin):
    print("=" * 64)
    print("           DEVOPTIMIZER UNIFIED LAUNCHER "
          f"({'ADMIN' if admin else 'STANDARD'} MODE)")
    print("=" * 64)
    for key, (label, _t) in options.items():
        print(f"[{key}] {label}")
    print(f"[S] Switch to "
          f"{'Standard' if admin else 'Administrator'} Mode"
          + ("" if admin else " (Restart Required)"))
    print("[0] Exit\n")


def main():
    ap = argparse.ArgumentParser(
        description="DevOptimizer unified launcher")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    admin = is_admin()
    if not admin:
        print("[INFO] Running in standard mode without Administrator "
              "privileges")
        print("[INFO] Some system-level features may be limited\n")

    while True:
        options = ADMIN_OPTIONS if admin else USER_OPTIONS
        show_menu(options, admin)
        choice = input("Enter your choice: ").strip().upper()
        if choice == "0":
            return 0
        if choice == "S":
            if not admin and sys.platform == "win32":
                # Relaunch elevated, matching "(Restart Required)".
                try:
                    rc = ctypes.windll.shell32.ShellExecuteW(
                        None, "runas", sys.executable,
                        f'"{Path(__file__)}"', None, 1)
                    if rc > 32:
                        print("[INFO] Elevated relaunch requested; "
                              "exiting.")
                        return 0
                except Exception as e:
                    print(f"[WARN] elevation request failed: {e}")
            admin = not admin
            print(f"\n[INFO] Switched to "
                  f"{'admin' if admin else 'standard'} mode\n")
            continue
        if choice not in options:
            print("Invalid choice. Please try again.\n")
            continue
        label, target = options[choice]
        print(f"\n[INFO] Launching {label}...\n")
        dispatch(target, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
