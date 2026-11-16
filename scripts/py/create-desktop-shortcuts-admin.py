"""Create desktop shortcuts, admin variant (port of
tools/Variants/CREATE-DESKTOP-SHORTCUTS-Admin.bat).

Same 5 shortcuts as create-desktop-shortcuts.py with an admin gate.
Delegates via importlib.
"""

import importlib.util
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: shortcuts, desktop, ui, elevated

_spec = importlib.util.spec_from_file_location(
    "create_desktop_shortcuts",
    Path(__file__).resolve().parent / "create-desktop-shortcuts.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


if __name__ == "__main__":
    if not is_admin():
        print("[ERROR] This script requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)
    _mod.main()
