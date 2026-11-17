"""Register Admin-Cleanup-System task (port of create-admin-task.bat).

Identical registration to create-admin-system-task.bat (weekly SUN 03:00,
SYSTEM/HIGHEST, /IT). Kept as a separate hub command per the original
pair. Mutating; --dry-run.
"""

import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: scheduled-task, cleanup, system

sys.path.insert(0, str(Path(__file__).resolve().parent))
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location(
    "create_admin_system_task",
    Path(__file__).resolve().parent / "create-admin-system-task-1.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

if __name__ == "__main__":
    _mod.main()
