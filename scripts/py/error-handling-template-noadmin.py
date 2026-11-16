"""Error-handling template, standard mode (port of
tools/Variants/error-handling-template-NoAdmin.bat).

Scaffold: logs errors to logs/error.log beside the script,
tracks an error count, and reports admin-limited mode. Copy and
extend the `run_steps` body with real work.
"""

import argparse
import ctypes
import datetime
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: template, error-handling

SCRIPT_DIR = Path(__file__).resolve().parent
LOG_FILE = SCRIPT_DIR / "logs" / "error.log"
error_count = 0


def log_error(msg):
    global error_count
    LOG_FILE.parent.mkdir(exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(f"[{datetime.datetime.now()}] ERROR: {msg}\n")
    error_count += 1


def check_error(msg, rc):
    if rc != 0:
        log_error(f"Command failed: {msg}")
        print(f"ERROR: {msg}")


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def run_steps():
    """Replace with the real work; call check_error() after each."""
    return 0


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true")
    ap.parse_args()

    print("\n" + "=" * 64)
    print("[INFO] Running in standard mode without Administrator "
          "privileges")
    print("[INFO] Some system-level features may be limited")
    print(" " * 20 + Path(sys.argv[0]).name)
    print("=" * 64)
    print("Error handling: ENABLED")
    print(f"Log file: {LOG_FILE}\n")

    run_steps()

    print("\n" + "=" * 64)
    print("Execution Summary")
    print("=" * 64)
    print(f"Errors encountered: {error_count}")
    print(f"Log file: {LOG_FILE}")
    if error_count == 0:
        print("[OK] Script completed successfully!")
    else:
        print(f"[WARN] Script completed with {error_count} error(s)")
    sys.exit(0 if error_count == 0 else 1)


if __name__ == "__main__":
    main()
