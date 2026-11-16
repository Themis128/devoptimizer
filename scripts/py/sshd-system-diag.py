"""sshd system-context diagnostics (Python port of sshd-system-diag.ps1).

Runs `sshd -t` and a 10s foreground `sshd -ddd -p 22222` capture, logging
to D:\\DevOptimizer\\logs\\sshd-system-diag.log. Designed to run once as
SYSTEM via a temp scheduled task.
"""

import argparse
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# CATEGORY: utilities
# TAGS: sshd, diagnostics, admin

OUT = Path(r"D:\DevOptimizer\logs\sshd-system-diag.log")
SSHD = r"C:\Windows\System32\OpenSSH\sshd.exe"
DEBUG_LOG = Path(r"D:\DevOptimizer\logs\sshd-system-debug.log")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Describe the capture without running sshd")
    args = parser.parse_args()

    if args.dry_run:
        print(f"[dry-run] would run '{SSHD} -t' then 10s of "
              f"'sshd -ddd -p 22222 -E {DEBUG_LOG}', appending to {OUT}")
        return

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as log:
        user = subprocess.run(["whoami"], capture_output=True, text=True)
        log.write(f"=== system-diag {datetime.now(timezone.utc).isoformat()} "
                  f"user={user.stdout.strip()} ===\n")
        log.write(user.stdout)

        t = subprocess.run([SSHD, "-t"], capture_output=True, text=True)
        log.write(t.stdout + t.stderr)
        log.write(f"--- sshd -t exit={t.returncode} ---\n")

        p = subprocess.Popen([SSHD, "-ddd", "-p", "22222", "-E", str(DEBUG_LOG)])
        try:
            p.wait(timeout=10)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait()
        time.sleep(1)
        log.write(f"--- sshd -d exit={p.returncode} ---\n")
        if DEBUG_LOG.exists():
            log.write(DEBUG_LOG.read_text(encoding="utf-8", errors="replace"))
        log.write("=== done ===\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
