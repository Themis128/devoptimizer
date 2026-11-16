"""Install dev tools, admin mode (port of
tools/Variants/03-Install-Dev-Tools-Admin.bat).

Identical to the standard variant — runs
tools/Variants/dev-optimizer-fixed.ps1 -Mode Basic -NoPause; the
:checkAdmin tail in the .bat is dead code. Mutating; --dry-run.
"""

import importlib.util
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: install, dev-tools, elevated

_spec = importlib.util.spec_from_file_location(
    "install_dev_tools_noadmin",
    Path(__file__).resolve().parent / "install-dev-tools-noadmin.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

if __name__ == "__main__":
    _mod.main()
