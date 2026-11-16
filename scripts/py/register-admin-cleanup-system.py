"""Register Admin-Cleanup-System task (port of
scripts/register-admin-cleanup-system.ps1).

Same registration as register-admin-task-elevated.py — delegates to
that port via importlib.
"""

import importlib.util
from pathlib import Path

# CATEGORY: utilities
# TAGS: scheduled-task, cleanup, system, elevated

_spec = importlib.util.spec_from_file_location(
    "register_admin_task_elevated",
    Path(__file__).resolve().parent / "register-admin-task-elevated.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

if __name__ == "__main__":
    _mod.main()
