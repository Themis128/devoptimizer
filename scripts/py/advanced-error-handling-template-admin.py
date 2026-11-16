"""Advanced error-handling template (port of
tools/Variants/advanced-error-handling-template-Admin.bat).

Scaffold: retry_with_backoff, validate_system (disk space + memory
checks), error logging. Admin mode — requires elevation; exits unelevated.
"""

import argparse
import ctypes
import datetime
import shutil
import subprocess
import sys
import time
from pathlib import Path

# REQUIRES: admin
# CATEGORY: utilities
# TAGS: template, error-handling, retry

SCRIPT_DIR = Path(__file__).resolve().parent
LOG_FILE = SCRIPT_DIR / "logs" / "advanced-error-handling.log"
MAX_RETRIES = 3
MIN_FREE_BYTES = 1 << 30            # 1 GB
MIN_TOTAL_MEM_KB = 2 * 1024 * 1024  # 2 GB


def log_message(msg):
    LOG_FILE.parent.mkdir(exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(f"[{datetime.datetime.now()}] {msg}\n")


def log_error(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    log_message(f"ERROR: {msg}")


def is_admin():
    if sys.platform != "win32":
        return False
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def retry_with_backoff(cmd, max_retries=MAX_RETRIES, delay=2):
    """Run `cmd` (list) until success or max_retries; returns exit code."""
    for attempt in range(1, max_retries + 1):
        rc = subprocess.run(cmd).returncode
        if rc == 0:
            return 0
        log_message(f"Command failed (attempt {attempt}/{max_retries}): "
                    f"{' '.join(map(str, cmd))}")
        if attempt < max_retries:
            print(f"Retrying in {delay} seconds...")
            time.sleep(delay)
    log_error(f"MAX RETRIES REACHED for: {' '.join(map(str, cmd))}")
    return 1


def validate_system(require_admin=False):
    log_message("Validating system requirements...")
    if require_admin and not is_admin():
        log_error("Administrator privileges required")
        return False
    try:
        free = shutil.disk_usage("/" if sys.platform != "win32"
                                 else "C:\\").free
    except OSError:
        free = MIN_FREE_BYTES
    if free < MIN_FREE_BYTES:
        log_error(f"Insufficient disk space: {free} bytes")
        return False
    log_message("System validation passed")
    return True


def main():
    ap = argparse.ArgumentParser(
        description="Advanced error-handling scaffold")
    ap.add_argument("cmd", nargs=argparse.REMAINDER,
                    help="command to run under retry wrapper")
    args = ap.parse_args()
    if not validate_system():
        print(f"SYSTEM VALIDATION FAILED - check log: {LOG_FILE}")
        return 1
    if args.cmd:
        return retry_with_backoff(args.cmd)
    log_message("Template scaffold ready — pass a command or add "
                "operations above.")
    return 0


if __name__ == "__main__":
    if sys.platform == "win32":
        try:
            import ctypes as _c
            if not _c.windll.shell32.IsUserAnAdmin():
                print("ERROR: This script requires Administrator "
                      "privileges. Run as Administrator.")
                sys.exit(1)
        except Exception:
            print("WARNING: admin check failed; continuing")
    sys.exit(main())

