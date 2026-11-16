"""Register Admin-Cleanup-System task, final variant
(port of create-admin-task-final.bat).

schtasks \\DevOptimizer\\Admin-Cleanup-System, weekly SUN 03:00,
SYSTEM/HIGHEST, /IT. Mutating; --dry-run.
"""

import importlib.util
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: scheduled-task, cleanup, system

_spec = importlib.util.spec_from_file_location(
    "create_admin_system_task",
    Path(__file__).resolve().parent / "create-admin-system-task.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

if __name__ == "__main__":
    _mod.main()
