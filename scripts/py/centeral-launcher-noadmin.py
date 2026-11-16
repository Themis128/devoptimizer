"""Port of tools/Old-Launchers/CENTERAL-LAUNCHER-NoAdmin.bat.

Displays the numbered tools menu, config/help submenus and
status lines, then delegates to the selected .bat/.ps1.
The .py side handles the UI; each target keeps its own runner.
"""

import ctypes
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from datetime import datetime

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = REPO_ROOT / "tools" / "Old-Launchers"
LOG_DIR = REPO_ROOT / "logs"
LOG_FILE = LOG_DIR / "centeral-launcher-noadmin.log"
def _resolve_config():
    for cand in (SCRIPT_DIR / "devoptimizer.config.json",
                 REPO_ROOT / "config"
                 / "devoptimizer.config.json",
                 REPO_ROOT / "devoptimizer.config.json"):
        if cand.exists():
            return cand
    return SCRIPT_DIR / "devoptimizer.config.json"


CONFIG_JSON = _resolve_config()

DEVOPT = os.environ.get("DEVOPT_HOME", "D:\\DevOptimizer")


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def log(line):
    try:
        LOG_DIR.mkdir(exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {line}\n")
    except OSError:
        pass


def _find_tool(script_name, exts):
    for base in (SCRIPT_DIR, REPO_ROOT / "tools" / "Variants"):
        for ext in exts:
            cand = base / f"{script_name}.{ext}"
            if cand.exists():
                return cand
    return None


def run_bat(script_name):
    bat = _find_tool(script_name, ("bat",))
    if not bat:
        print(f"  {script_name}.bat not found under "
              f"{SCRIPT_DIR} or tools/Variants")
        log(f"MISS {script_name}.bat")
        return 1
    log(f"RUN {bat.name}")
    return subprocess.run(["cmd", "/c", str(bat)],
                          cwd=str(bat.parent)).returncode

def run_ps(script_name, args=None):
    ps1 = _find_tool(script_name, ("ps1",))
    if not ps1:
        print(f"  {script_name}.ps1 not found under "
              f"{SCRIPT_DIR} or tools/Variants")
        log(f"MISS {script_name}.ps1")
        return 1
    log(f"RUN {ps1.name}")
    pwsh = shutil.which("pwsh") or shutil.which("powershell")
    cmd = [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass",
           "-File", str(ps1)] + (args or [])
    return subprocess.run(cmd, cwd=str(ps1.parent)).returncode

def execute_with_admin_check(script_name, admin_required):
    if admin_required and not is_admin():
        if not sys.stdin.isatty():
            print(f"  {script_name} requires elevation")
            return 1
        ans = input(f"  {script_name} requires admin. "
                    "Elevate and run? [Y/n]: ").strip().lower()
        if ans in ("", "y"):
            return subprocess.run(
                ["powershell", "-Command",
                 f"Start-Process '{sys.executable}' "
                 f"-ArgumentList '{sys.argv[0]} "
                 f"admin_{script_name}' -Verb RunAs"]).returncode
        print("  Skipped")
        return 0
    if script_name == "__EXPLORER__":
        subprocess.Popen(["explorer", str(SCRIPT_DIR)])
        return 0
    if script_name == "config":
        config_menu()
        return 0
    if _find_tool(script_name, ("ps1",)):
        return run_ps(script_name)
    return run_bat(script_name)


def status_lines():
    print("  Status:")
    for proc, label in (("ollama", "Ollama"),
                        ("OneDrive", "OneDrive"),
                        ("Cursor", "Cursor")):
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             f"Get-Process {proc} -ErrorAction SilentlyContinue"
             " | Select-Object -First 1"],
            capture_output=True, text=True)
        state = "running" if r.stdout.strip() else "stopped"
        print(f"    {label:.<24} {state}")
    print()


def config_menu():
    while True:
        print("\n--- Config ---")
        print("  [1] View devoptimizer.config.json")
        print("  [2] Edit in notepad")
        print("  [3] Run QUICK-GLOBAL-SETUP")
        print("  [4] Open config dir")
        print("  [5] Backup config")
        print("  [6] Restore latest backup")
        print("  [0] Back")
        sel = input("  Select: ").strip()
        if sel == "0":
            return
        if sel == "1":
            print(CONFIG_JSON.read_text(encoding="utf-8-sig")
                  if CONFIG_JSON.exists() else "  Not found")
        elif sel == "2":
            subprocess.Popen(["notepad", str(CONFIG_JSON)])
        elif sel == "3":
            run_bat("QUICK-GLOBAL-SETUP")
        elif sel == "4":
            subprocess.Popen(
                ["explorer", str(SCRIPT_DIR / "config")])
        elif sel == "5" and CONFIG_JSON.exists():
            dst = SCRIPT_DIR / (
                f"bat.config.backup.{datetime.now():%Y%m%d}.json")
            shutil.copy2(CONFIG_JSON, dst)
            print(f"  Backup -> {dst.name}")
        elif sel == "6":
            backups = sorted(SCRIPT_DIR.glob(
                "bat.config.backup.*.json"))
            if backups:
                shutil.copy2(backups[-1], CONFIG_JSON)
                print(f"  Restored {backups[-1].name}")
            else:
                print("  No backups found")


def help_menu():
    while True:
        print("\n--- Help ---")
        print("  [1] QUICK-START-GUIDE.md")
        print("  [2] optimizer -List")
        print("  [3] Troubleshooting guide")
        print("  [4] Latest validation report")
        print("  [5] Resources")
        print("  [0] Back")
        sel = input("  Select: ").strip()
        if sel == "0":
            return
        if sel == "1":
            p = SCRIPT_DIR / "QUICK-START-GUIDE.md"
            print(p.read_text(encoding="utf-8-sig")
                  if p.exists() else "  Not found")
        elif sel == "2":
            run_bat("optimizer")
        elif sel == "3":
            p = SCRIPT_DIR / "TROUBLESHOOTING.md"
            print(p.read_text(encoding="utf-8-sig")
                  if p.exists() else "  Not found")
        elif sel == "4":
            reps = sorted(SCRIPT_DIR.glob(
                "validation-report-*.html"))
            subprocess.Popen(["explorer", str(
                reps[-1] if reps else SCRIPT_DIR)])
        elif sel == "5":
            subprocess.Popen(["explorer", str(SCRIPT_DIR)])


TOOLS = {
    1: ("01-Quick-Optimization-NoAdmin", "Quick optimization", False),
    2: ("02-Ultra-Performance-NoAdmin", "Ultra performance", False),
    3: ("03-AI-Development-Tools-NoAdmin", "AI dev tools", False),
    4: ("04-Ollama-Optimization-NoAdmin", "Ollama optimize", False),
    5: ("05-System-Cleanup-NoAdmin", "System cleanup", False),
    6: ("06-System-Health-Check-NoAdmin", "Health check", False),
    7: ("07-Auto-Recovery-NoAdmin", "Auto recovery", False),
    8: ("08-Temporary-Files-Cleanup-NoAdmin", "Temp cleanup", False),
    9: ("09-System-Deep-Clean-NoAdmin", "Deep clean", False),
    10: ("10-Network-Optimization-NoAdmin", "Network optimize", False),
    11: ("11-Registry-Optimizer-NoAdmin", "Registry optimize", False),
    12: ("12-Startup-Programs-NoAdmin", "Startup programs", False),
    13: ("13-Windows-Updates-NoAdmin", "Windows updates", False),
    14: ("14-Driver-Updates-NoAdmin", "Driver updates", False),
    15: ("15-Gaming-Optimization-NoAdmin", "Gaming optimize", False),
    16: ("16-Privacy-Hardening-NoAdmin", "Privacy hardening", False),
    17: ("17-Service-Optimizer-NoAdmin", "Service optimizer", False),
    18: ("18-Disk-Defragment-NoAdmin", "Disk defrag", False),
    19: ("19-Memory-Optimizer-NoAdmin", "Memory optimize", False),
    20: ("20-Battery-Optimization-NoAdmin", "Battery optimize", False),
    21: ("REAL-TIME-MONITOR", "Real-time monitor", False),
    22: ("COMPREHENSIVE-TEST-SUITE", "Test suite", False),
    23: ("ADVANCED-OPTIMIZATIONS", "Advanced optimizations", True),
    24: ("ADVANCED-SCRIPT-UPDATER", "Script updater", True),
    25: ("DEVOPTIMIZER-CORE", "Core module", True),
    26: ("config", "Configuration", False),
    27: ("setup-global-access", "Global access", False),
    28: ("validate-system", "Validate system", True),
    29: ("__EXPLORER__", "Open script dir", False),
    30: ("QUICK-FIX-POWERSHELL-ERROR", "Quick PS fix", True),
}


def submenu_g():
    while True:
        print("\n--- System cleanup ---")
        print("  [1] Deep clean")
        print("  [2] Ultra performance")
        print("  [3] Registry cleanup")
        print("  [4] Service optimization")
        print("  [5] Enhanced system diagnostics")
        print("  [0] Back")
        sel = input("  Select: ").strip()
        if sel == "0":
            return
        if sel == "1":
            execute_with_admin_check(
                "09-System-Deep-Clean-NoAdmin", False)
        elif sel == "2":
            execute_with_admin_check(
                "02-Ultra-Performance-NoAdmin", False)
        elif sel == "3":
            ans = input("  Clear RunMRU + ComDlg32 MRU? [y/N]: "
                        ).strip().lower()
            if ans == "y":
                for key in (r"HKCU\Software\Microsoft\Windows"
                            r"\CurrentVersion\Explorer\RunMRU",
                            r"HKCU\Software\Microsoft\Windows"
                            r"\CurrentVersion\Explorer\ComDlg32"
                            r"\LastVisitedPidlMRU"):
                    subprocess.run(["reg", "delete", key, "/f"],
                                   capture_output=True)
                print("  Registry MRU cleared")
        elif sel == "4":
            for svc in ("DiagTrack", "dmwappushservice", "WerSvc"):
                subprocess.run(["sc", "config", svc, "start=",
                                "disabled"], capture_output=True)
                print(f"  {svc} disabled")
        elif sel == "5":
            execute_with_admin_check(
                "ENHANCED-SYSTEM-DIAGNOSTICS", True)


def main():
    print("=" * 58)
    print("  DevOptimizer - Launcher")
    print("=" * 58)
    status_lines()
    if len(sys.argv) > 1 and \
            sys.argv[1].lower().startswith("admin_"):
        # elevated re-launch: run the selected tool directly
        execute_with_admin_check(sys.argv[1][6:], True)
        return
    while True:
        for k in sorted(TOOLS):
            print(f"  [{k:>2}] {TOOLS[k][1]}")
        print("  [G] System cleanup + services   "
              "[H] Help   [J] Advanced diagnostics   [0] Exit")
        sel = input("  Select: ").strip().lower()
        if sel == "0":
            return 0
        if sel == "g":
            submenu_g()
            continue
        if sel == "h":
            help_menu()
            continue
        if sel == "j":
            execute_with_admin_check("ADVANCED-DIAGNOSTICS", True)
            continue
        try:
            k = int(sel)
        except ValueError:
            continue
        if k in TOOLS:
            name, _label, admin = TOOLS[k]
            execute_with_admin_check(name, admin)


if __name__ == "__main__":
    if not sys.stdin.isatty():
        print(__doc__.strip().splitlines()[0])
        status_lines()
        sys.exit(0)
    sys.exit(main())
