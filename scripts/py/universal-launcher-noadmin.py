"""Port of tools/Variants/UNIVERSAL-LAUNCHER-NoAdmin.bat — same
4-option universal launcher menu, standard-mode banner.
"""
import subprocess
import sys

DEVOPT = "D:" + chr(92) + "DevOptimizer"


def menu():
    while True:
        print("\n" + "=" * 60)
        print("[INFO] Running in standard mode without Administrator"
              " privileges")
        print("[INFO] Some system-level features may be limited")
        print("                     UNIVERSAL LAUNCHER")
        print("=" * 60 + "\n")
        print("Choose an option:")
        print("1. System Health Check (No Admin)")
        print("2. Quick Optimization (No Admin)")
        print("3. Run as Administrator (Full Features)")
        print("4. Exit\n")
        try:
            c = input("Enter your choice (1-4): ").strip()
        except (EOFError, KeyboardInterrupt):
            return
        if c == "1":
            subprocess.run(["cmd", "/c", DEVOPT + chr(92)
                            + "06-System-Health-Check-NoAdmin.bat"])
        elif c == "2":
            subprocess.run(["cmd", "/c", DEVOPT + chr(92)
                            + "01-Quick-Optimization-NoAdmin.bat"])
        elif c == "3":
            print("Starting PowerShell as Administrator...")
            subprocess.run(
                ["powershell", "-Command",
                 "Start-Process PowerShell -ArgumentList"
                 " '-ExecutionPolicy Bypass -File \""
                 + DEVOPT + chr(92)
                 + "RUN-AS-ADMIN.bat\"' -Verb RunAs"])
        elif c == "4":
            return
        else:
            print("Invalid choice. Please try again.")
        input("\nPress any key to return to menu...")


def main():
    if not sys.stdin.isatty():
        print("Interactive menu requires a console.")
        return 2
    menu()
    return 0


if __name__ == "__main__":
    sys.exit(main())
