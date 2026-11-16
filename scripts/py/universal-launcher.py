"""Port of tools/Old-Launchers/UNIVERSAL-LAUNCHER.bat — 4-option
menu: no-admin health check, no-admin quick optimization, elevated
RUN-AS-ADMIN.bat via Start-Process -Verb RunAs, exit.
"""
import subprocess
import sys

DEVOPT = "D:" + chr(92) + "DevOptimizer"


def run_bat(name):
    subprocess.run(["cmd", "/c", DEVOPT + chr(92) + name])


def run_admin():
    print("Starting PowerShell as Administrator...")
    subprocess.run(
        ["powershell", "-Command",
         "Start-Process PowerShell -ArgumentList"
         " '-ExecutionPolicy Bypass -File \""
         + DEVOPT + chr(92)
         + "RUN-AS-ADMIN.bat\"' -Verb RunAs"])


def menu():
    while True:
        print("\n" + "=" * 60)
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
            run_bat("06-System-Health-Check-NoAdmin.bat")
        elif c == "2":
            run_bat("01-Quick-Optimization-NoAdmin.bat")
        elif c == "3":
            run_admin()
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
