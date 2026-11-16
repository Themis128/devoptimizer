"""Normalize .bat files, fixed variant (port of normalize-bat-files-fixed.ps1).

Same normalizer as normalize-bat-files.py, kept as a separate hub command
because the original ships both variants. Mutating; --dry-run.
"""

import importlib.util
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: batch, normalize, maintenance

_spec = importlib.util.spec_from_file_location(
    "normalize_bat_files",
    Path(__file__).resolve().parent / "normalize-bat-files.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

if __name__ == "__main__":
    if "--flat" not in sys.argv:
        sys.argv.append("--flat")
    _mod.main()
