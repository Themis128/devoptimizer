"""Quick UI access menu (port of tools/Variants/QUICK-UI-ACCESS-*.bat).

Same targets as open-ui-new-window: 1-5 open launchers in new windows,
ESC/6 exits. --admin selects the admin variant (requires elevation).
"""

import argparse
import sys

import importlib.util
from pathlib import Path

# CATEGORY: utilities
# TAGS: ui, launcher, menu

_spec = importlib.util.spec_from_file_location(
    "open_ui_new_window",
    Path(__file__).resolve().parent / "open-ui-new-window.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--admin", action="store_true")
    args = parser.parse_args()

    print("\n" + "=" * 64 + "\n                     QUICK UI ACCESS\n"
          + "=" * 64 + "\n\nPress a key to open the corresponding UI:\n")
    if args.admin and not _mod.is_admin():
        print("[ERROR] This script requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)
    _mod.menu()


if __name__ == "__main__":
    main()
