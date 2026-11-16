"""Open-UI menu, launches each option in a new window
(port of tools/Variants/OPEN-UI-NEW-WINDOW-Admin.bat / -NoAdmin.bat).

Menu: 1 Universal Launcher, 2 Admin Mode, 3 System Health Check,
4 Quick Optimization, 5 all of them, 6 exit. Admin variant requires
elevation; --admin flag selects it.
"""

import argparse
import os
import subprocess
import sys

# CATEGORY: utilities
# TAGS: ui, launcher, menu

OPTIONS = [
    ("Universal Launcher", "DevOptimizer Universal Launcher",
     ["cmd", "/k", r"D:\DevOptimizer\UNIVERSAL-LAUNCHER.bat"]),
    ("Admin Mode", "DevOptimizer Admin Mode",
     ["powershell", "-ExecutionPolicy", "Bypass", "-File",
      r"D:\DevOptimizer\RUN-AS-ADMIN.bat"]),
    ("System Health Check", "System Health Check",
     ["cmd", "/k", r"D:\DevOptimizer\06-System-Health-Check.bat"]),
    ("Quick Optimization", "Quick Optimization",
     ["cmd", "/k", r"D:\DevOptimizer\01-Quick-Optimization.bat"]),
]


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def launch(cmd, title):
    if os.name == "nt":
        subprocess.Popen(["cmd", "/c", "start", f'"{title}"', *cmd])
    else:
        print("start " + " ".join(cmd))


def menu() -> None:
    print("Choose how to open the UI:\n")
    for i, (name, *_rest) in enumerate(OPTIONS, 1):
        print(f"{i}. {name} (New Window)")
    print("5. All Options (Multiple Windows)")
    print("6. Exit\n")
    while True:
        choice = input("Select (1-6): ").strip()
        if choice == "6" or not choice:
            return
        if choice in ("1", "2", "3", "4"):
            _name, title, cmd = OPTIONS[int(choice) - 1]
            print(f"Opening {title} in new window...")
            launch(cmd, title)
            return
        if choice == "5":
            for _name, title, cmd in OPTIONS:
                launch(cmd, title)
            return
        print("Invalid choice.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--admin", action="store_true",
                        help="admin variant: require elevation")
    args = parser.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] This script requires Administrator privileges.\n"
              "Please run this script as Administrator.", file=sys.stderr)
        sys.exit(1)
    if not args.admin:
        print("[INFO] Running in standard mode without Administrator "
              "privileges\n[INFO] Some system-level features may be "
              "limited\n")
    menu()


if __name__ == "__main__":
    main()
