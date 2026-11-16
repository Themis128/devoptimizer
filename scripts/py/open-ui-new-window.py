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
        line = 'start "{}" {}'.format(
            title.replace('"', ''),
            " ".join('"{}"'.format(a) if " " in a else a for a in cmd))
        subprocess.Popen(line, shell=True)
    else:
        print("start " + " ".join(cmd))


def apply_choice(choice: str) -> bool:
    if choice == "6" or not choice:
        return True
    if choice in ("1", "2", "3", "4"):
        _name, title, cmd = OPTIONS[int(choice) - 1]
        print(f"Opening {title} in new window...")
        launch(cmd, title)
        return True
    if choice == "5":
        for _name, title, cmd in OPTIONS:
            launch(cmd, title)
        return True
    print("Invalid choice.")
    return False


def menu(choice: str = "") -> None:
    print("Choose how to open the UI:\n")
    for i, (name, *_rest) in enumerate(OPTIONS, 1):
        print(f"{i}. {name} (New Window)")
    print("5. All Options (Multiple Windows)")
    print("6. Exit\n")
    if choice:
        apply_choice(choice)
        return
    if not sys.stdin.isatty():
        # hidden runner (hub/app): no console to read from — print
        # the menu and exit so the caller can pass --choice.
        print("(non-interactive: pass --choice N)", file=sys.stderr)
        return
    while not apply_choice(input("Select (1-6): ").strip()):
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--admin", action="store_true",
                        help="admin variant: require elevation")
    parser.add_argument("--choice", default="",
                        help="menu choice 1-6 for non-interactive runs")
    args = parser.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] This script requires Administrator privileges.\n"
              "Please run this script as Administrator.", file=sys.stderr)
        sys.exit(1)
    if not args.admin:
        print("[INFO] Running in standard mode without Administrator "
              "privileges\n[INFO] Some system-level features may be "
              "limited\n")
    menu(args.choice)


if __name__ == "__main__":
    main()
