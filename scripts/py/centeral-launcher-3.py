"""Port of scripts/CENTERAL-LAUNCHER.ps1 — DevOptimizer central
unified launcher menu (30 entries). --quick runs quick
optimization, --status shows the optimizer status, --help prints
help. Interactive menu when attached to a TTY.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

DEVOPT = Path("D:" + chr(92) + "DevOptimizer")

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
          "014-Cursor-AI-Optimization.bat", "AI development setup"),
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


def execute_tool(name, filename, desc):
    path = DEVOPT / filename
    print(f"\nExecuting: {name} - {desc}")
    if not path.exists():
        print(f"Tool not found: {path}")
        return
    try:
        if filename.endswith(".ps1"):
            subprocess.run(["powershell", "-ExecutionPolicy",
                            "Bypass", "-File", str(path)])
        else:
            subprocess.run(["cmd.exe", "/c", str(path)])
        print(f"Successfully executed: {name}")
    except OSError as e:
        print(f"Error executing {name}: {e}")


def optimizer(flag):
    subprocess.run(["powershell", "-ExecutionPolicy", "Bypass",
                    "-File", str(DEVOPT / "optimizer.ps1"), flag])


def show_help():
    print("DevOptimizer Central Launcher Help")
    print("==================================\n")
    print("Usage: centeral-launcher.py [options]\n")
    print("Options:")
    print("  --quick    Run quick optimization immediately")
    print("  --status   Show system status")
    print("  --help     Show this help message")


def config_menu():
    print("\nConfiguration Menu:")
    print("1. View Current Config")
    print("2. Edit Configuration")
    print("3. Open Config Folder")
    c = input("Enter choice (1-3): ").strip()
    cfg = DEVOPT / "bat.config.json"
    if c == "1":
        try:
            print(json.dumps(json.loads(cfg.read_text()),
                             indent=2))
        except (OSError, ValueError) as e:
            print(f"Config read failed: {e}")
    elif c == "2":
        subprocess.Popen(["notepad", str(cfg)])
    elif c == "3":
        subprocess.Popen(["explorer.exe", str(DEVOPT / "config")])


def help_menu():
    print("\nHelp and Documentation:")
    print("1. Quick Start Guide")
    print("2. Tool Documentation")
    print("3. Troubleshooting")
    c = input("Enter choice (1-3): ").strip()
    if c == "1":
        print("\nQUICK START GUIDE:")
        print("1. Run as Administrator for full functionality")
        print("2. Start with Quick Optimization (Option 1)")
        print("3. Run System Health Check (Option 3) to verify")
        print("4. Use Development Tools (Options 5-9) for coding"
              " setup")
        print("5. Regular maintenance with System Cleanup"
              " (Option 4)")
    elif c == "2":
        optimizer("-List")
    elif c == "3":
        print("\nTROUBLESHOOTING:")
        print("1. 'Access Denied' - Run as Administrator")
        print("2. 'Command not found' - Check PATH configuration")
        print("3. 'PowerShell errors' - Run PowerShell fix tools")
        print("4. 'Tool not working' - Run system validation")


def menu():
    while True:
        print("\n" + "=" * 64)
        print("    DEVOPTIMIZER - CENTRAL UNIFIED LAUNCHER v4.0")
        print("=" * 64)
        print("SYSTEM STATUS: Ready | Tools: 66+ | Scripts: 26+ |"
              " Success Rate: 87.2%\n")
        for k in sorted(TOOLS, key=int):
            n, f, d = TOOLS[k]
            print(f"  [{k:>2}] {n:<26} - {d}")
        print("  [23] TOOL LIST            - all tools")
        print("  [24] SYSTEM STATUS        - detailed info")
        print("  [25] CONFIGURATION        - settings")
        print("  [26] HELP DOCUMENTATION   - guides")
        print("  [29] OPEN FOLDER          - DevOptimizer folder")
        print("  [0]  EXIT\n")
        print("WARNING: Most tools require Administrator privileges\n")
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
    a = p.parse_args()
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
              " --status or --help.")
        return 2
    menu()
    return 0


if __name__ == "__main__":
    sys.exit(main())
