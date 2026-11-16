"""Port of scripts/UNIFIED-LAUNCHER.ps1 — DevOptimizer unified
central launcher v4.0: logged 30-entry menu with configuration and
help sub-menus. --quick/--status/--help short-circuit. Per-run log
at logs\\unified-launcher-<ts>.log.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

DEVOPT = Path("D:" + chr(92) + "DevOptimizer")
LOG_FILE = (DEVOPT / "logs"
            / f"unified-launcher-"
              f"{time.strftime('%Y%m%d-%H%M%S')}.log")

TOOLS = {
    "1": ("Quick Optimization", "01-Quick-Optimization.bat",
          "Balanced system settings"),
    "2": ("Ultra Performance", "02-Ultra-Performance.bat",
          "Maximum performance mode"),
    "3": ("System Health Check", "06-System-Health-Check.bat",
          "Performance analysis"),
    "4": ("System Cleanup", "09-System-Deep-Clean.bat",
          "Comprehensive cleanup"),
    "5": ("Install Dev Tools", "03-Install-Dev-Tools.bat",
          "Essential development software"),
    "6": ("Cursor AI Optimization",
          "014-Cursor-AI-Optimization.bat",
          "AI development setup"),
    "7": ("VS Code Optimization", "015-VSCode-Optimization.bat",
          "Code editor optimization"),
    "8": ("Docker Optimization", "08-Docker-Optimization.bat",
          "Container management"),
    "9": ("Nuxt3 Optimization",
          "16-Nuxt3-Windows-Optimization.bat",
          "Nuxt.js development setup"),
    "10": ("Network Optimization", "10-Network-Optimization.bat",
           "Network tuning"),
    "11": ("Security Hardening", "11-Security-Hardening.bat",
           "Security enhancements"),
    "12": ("Power Management", "12-Power-Management.bat",
           "Power optimization"),
    "13": ("Startup Management", "13-Startup-Management.bat",
           "Boot optimization"),
    "14": ("Screen Settings Manager",
           "18-Screen-Settings-Manager.bat", "Display management"),
    "15": ("WSL Ubuntu Fix", "07-Fix-WSL-Ubuntu.bat",
           "WSL configuration"),
    "16": ("Dual GPU Optimization",
           "017-Dual-GPU-NVIDIA-Broadcast-Optimization.bat",
           "GPU and streaming setup"),
    "17": ("Cache Cleaner", "025-Development-Cache-Cleaner.bat",
           "Development cache management"),
    "18": ("Prerequisites Check", "026-Prerequisites-Checker.bat",
           "Check required tools"),
    "19": ("Advanced AI Suite",
           "019-Advanced-AI-Development-Suite.bat",
           "Complete AI/ML environment"),
    "20": ("System Diagnostics",
           "ENHANCED-SYSTEM-DIAGNOSTICS.bat",
           "Advanced system analysis"),
    "21": ("Performance Monitor", "real-time-monitoring.ps1",
           "Real-time monitoring"),
    "22": ("System Validation", "validate-system.ps1",
           "Comprehensive testing"),
    "27": ("Refresh System", "setup-global-access.ps1",
           "Reload and refresh"),
    "28": ("Test All Tools", "validate-system.ps1",
           "Run comprehensive tests"),
    "30": ("Repair System", "QUICK-FIX-POWERSHELL-ERROR.bat",
           "Fix common issues"),
}


def log(msg, level="INFO"):
    line = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] [{level}] {msg}"
    print(line)
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def execute_tool(name, filename, desc):
    path = DEVOPT / filename
    log(f"Executing: {name} - {desc}")
    if not path.exists():
        log(f"Tool not found: {path}", "ERROR")
        return
    try:
        if filename.endswith(".ps1"):
            subprocess.run(["powershell", "-ExecutionPolicy",
                            "Bypass", "-File", str(path)])
        else:
            subprocess.run(["cmd.exe", "/c", str(path)])
        log(f"Successfully executed: {name}", "SUCCESS")
    except OSError as e:
        log(f"Error executing {name}: {e}", "ERROR")


def optimizer(flag):
    subprocess.run(["powershell", "-ExecutionPolicy", "Bypass",
                    "-File", str(DEVOPT / "optimizer.ps1"), flag])


def pause():
    input("Press Enter to continue")


def config_menu():
    cfg = DEVOPT / "bat.config.json"
    bdir = DEVOPT / "backup"
    while True:
        print("\n" + "=" * 60)
        print("                    CONFIGURATION MENU")
        print("=" * 60 + "\n")
        print("  [1] View Current Config")
        print("  [2] Edit Configuration")
        print("  [3] Reset to Defaults")
        print("  [4] Open Config Folder")
        print("  [5] Backup Configuration")
        print("  [6] Restore Configuration")
        print("  [0] Back to Main Menu\n")
        c = input("Enter your choice (0-6): ").strip()
        if c == "0":
            return
        if c == "1":
            try:
                print(json.dumps(json.loads(cfg.read_text()),
                                 indent=2))
            except (OSError, ValueError):
                print("Configuration file not found!")
            pause()
        elif c == "2":
            if cfg.exists():
                subprocess.Popen(["notepad", str(cfg)])
            else:
                print("Configuration file not found!")
        elif c == "3":
            execute_tool("Reset Configuration",
                         "QUICK-GLOBAL-SETUP.bat",
                         "Reset to defaults")
        elif c == "4":
            d = DEVOPT / "config"
            if d.exists():
                subprocess.Popen(["explorer.exe", str(d)])
            else:
                print("Config folder not found!")
        elif c == "5":
            if cfg.exists():
                bdir.mkdir(exist_ok=True)
                dest = bdir / ("bat.config.backup."
                               + time.strftime("%Y%m%d-%H%M%S")
                               + ".json")
                dest.write_bytes(cfg.read_bytes())
                print(f"Configuration backed up to: {dest}")
            else:
                print("Configuration file not found!")
        elif c == "6":
            backups = sorted(bdir.glob("bat.config.backup.*.json"),
                             key=lambda p: p.stat().st_mtime,
                             reverse=True) if bdir.exists() else []
            if backups:
                cfg.write_bytes(backups[0].read_bytes())
                print(f"Configuration restored from:"
                      f" {backups[0].name}")
            else:
                print("No backup files found!")
        else:
            print("Invalid choice! Please enter a number from"
                  " 0-6.")
            pause()


def help_menu():
    while True:
        print("\n" + "=" * 60)
        print("                  HELP & DOCUMENTATION")
        print("=" * 60 + "\n")
        print("  [1] Quick Start Guide")
        print("  [2] Tool Documentation")
        print("  [3] Troubleshooting")
        print("  [4] System Reports")
        print("  [5] External Resources")
        print("  [6] Support Information")
        print("  [0] Back to Main Menu\n")
        c = input("Enter your choice (0-6): ").strip()
        if c == "0":
            return
        if c == "1":
            print("\nDEVOPTIMIZER QUICK START GUIDE")
            print("=" * 30 + "\n")
            print("1. Run as Administrator for full functionality")
            print("2. Start with Quick Optimization (Option 1)")
            print("3. Run System Health Check (Option 3) to verify")
            print("4. Use Development Tools (Options 5-9) for coding"
                  " setup")
            print("5. Regular maintenance with System Cleanup"
                  " (Option 4)\n")
            pause()
        elif c == "2":
            optimizer("-List")
            pause()
        elif c == "3":
            print("\nCOMMON ISSUES AND SOLUTIONS:")
            print("=" * 27 + "\n")
            print("1. 'Access Denied' - Run as Administrator")
            print("2. 'Command not found' - Check PATH"
                  " configuration")
            print("3. 'PowerShell errors' - Run PowerShell fix"
                  " tools")
            print("4. 'Unicode display issues' - Use PowerShell"
                  " launcher")
            print("5. 'Tool not working' - Run system validation")
            print("\nFor more help, run System Validation"
                  " (Option 22)")
            pause()
        elif c == "4":
            reports = sorted(
                DEVOPT.glob("validation-report-*.html"),
                key=lambda p: p.stat().st_mtime, reverse=True)
            if reports:
                print("Opening latest validation report...")
                subprocess.Popen(["explorer.exe",
                                  str(reports[0])])
            else:
                print("No reports found. Run System Validation"
                      " (Option 22) to generate reports.")
            pause()
        elif c == "5":
            print("\n- Microsoft Windows Documentation")
            print("- PowerShell Documentation")
            print("- Docker Documentation")
            print("- VS Code Documentation")
            print("- Cursor AI Documentation")
            print("\nCheck the docs folder for local"
                  " documentation.")
            pause()
        elif c == "6":
            print(f"\n- Check logs in: {DEVOPT / 'logs'}")
            print(f"- View reports in: {DEVOPT / 'reports'}")
            print("- Run diagnostics: Option 20")
            print("- System validation: Option 22")
            pause()
        else:
            print("Invalid choice! Please enter a number from"
                  " 0-6.")
            pause()


def menu():
    while True:
        print("\n" + "=" * 64)
        print("    DEVOPTIMIZER - UNIFIED CENTRAL LAUNCHER v4.0")
        print("=" * 64)
        print("SYSTEM STATUS: Ready | Tools: 66+ | Scripts: 26+ |"
              " Success Rate: 87.2%\n")
        for k in sorted(TOOLS, key=int):
            n, f, d = TOOLS[k]
            print(f"  [{k:>2}] {n:<26} - {d}")
        print("  [23] TOOL LIST            - all tools")
        print("  [24] SYSTEM STATUS        - detailed info")
        print("  [25] CONFIGURATION        - settings")
        print("  [26] HELP & DOCUMENTATION - guides")
        print("  [29] OPEN FOLDER          - DevOptimizer folder")
        print("  [0]  EXIT\n")
        print("WARNING: Most tools require Administrator"
              " privileges\n")
        try:
            choice = input("Enter your choice (0-30): ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if choice == "0":
            print("\nThank you for using DevOptimizer!")
            break
        if choice in TOOLS:
            execute_tool(*TOOLS[choice])
        elif choice == "23":
            optimizer("-List")
        elif choice == "24":
            optimizer("-Status")
        elif choice == "25":
            config_menu()
        elif choice == "26":
            help_menu()
        elif choice == "29":
            subprocess.Popen(["explorer.exe", str(DEVOPT)])
        else:
            print("\nInvalid choice! Please enter a number from"
                  " 0-30.")
        input("\nPress Enter to return to main menu...")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--quick", action="store_true")
    p.add_argument("--status", action="store_true")
    p.add_argument("--help-menu", action="store_true")
    a = p.parse_args()
    if a.help_menu:
        if not sys.stdin.isatty():
            print("Interactive help menu requires a console.")
            return 2
        help_menu()
        return 0
    if a.status:
        optimizer("-Status")
        return 0
    if a.quick:
        execute_tool("Quick Optimization",
                     "01-Quick-Optimization.bat",
                     "Balanced system settings")
        return 0
    if not sys.stdin.isatty():
        print("Interactive menu requires a console. Use --quick,"
              " --status or --help-menu.")
        return 2
    menu()
    return 0


if __name__ == "__main__":
    sys.exit(main())
