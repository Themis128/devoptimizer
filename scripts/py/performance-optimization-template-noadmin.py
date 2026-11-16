"""Performance-optimized script template (port of
tools/Variants/performance-optimization-template-NoAdmin.bat).

Scaffold helpers: timestamped logging, progress display,
smart_wait (ping-based delay, no timeout.exe), process checks.
Standard (non-admin) mode — system-level features may be limited.
"""

import datetime
import shutil
import subprocess
import sys

# CATEGORY: utilities
# TAGS: template, optimization, scaffold

SCRIPT_DIR = __file__ and __import__("pathlib").Path(__file__).resolve().parent
LOG_FILE = SCRIPT_DIR / "logs" / "performance-template.log"


def log_message(msg):
    LOG_FILE.parent.mkdir(exist_ok=True)
    line = f"[{datetime.datetime.now()}] {msg}"
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(line + "\n")
    print(line)


def show_progress(step, total, desc=""):
    pct = int(step / max(total, 1) * 100)
    bar = "#" * (pct // 5) + "-" * (20 - pct // 5)
    print(f"\r[{bar}] {pct:3d}% {desc}", end="", flush=True)
    if step >= total:
        print()


def smart_wait(seconds):
    """ping-based delay — works under conhost --headless unlike timeout."""
    subprocess.run(
        ["ping", "127.0.0.1", "-n", str(max(1, int(seconds) + 1))],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def check_process(name):
    """Return True if a process named `name` is running."""
    try:
        out = subprocess.run(
            ["tasklist", "/FI", f"IMAGENAME eq {name}"],
            capture_output=True, text=True).stdout
        return name.lower() in out.lower()
    except OSError:
        return False


def main():
    start = datetime.datetime.now()
    log_message("Starting performance optimized execution")
    print(f"Start time: {start}\nLog file: {LOG_FILE}\n")
    # Your optimized operations here, e.g.:
    # for i in range(1, 11):
    #     show_progress(i, 10, "Optimizing")
    #     smart_wait(1)
    log_message("Template scaffold ready — add operations above.")


if __name__ == "__main__":
    sys.exit(main() or 0)
