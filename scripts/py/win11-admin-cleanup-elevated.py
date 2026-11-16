"""Elevated admin cleanup (port of
scripts/win11-admin-cleanup-elevated.ps1).

Delegates to the win11-admin-cleanup-elevated-fixed port (the fixed
variant is the current one; the plain variant differs only in comments
and progress output). --dry-run / --admin pass through.
"""

import importlib.util
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: windows11, admin, delegate
# REQUIRES: admin

_IMPL = (Path(__file__).resolve().parent /
         "win11-admin-cleanup-elevated-fixed.py")
_spec = importlib.util.spec_from_file_location(
    "win11_admin_cleanup_elevated_fixed", _IMPL)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

if __name__ == "__main__":
    sys.argv[0] = str(_IMPL)
    _mod.main()
