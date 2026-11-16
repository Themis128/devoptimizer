"""Devin FCFS queue manager, hooks variant (port of devin/hooks/queue-manager.ps1).

Identical to queue-manager.py except send-next invokes the Devin CLI
directly with an argument array instead of a cmd.exe wrapper — matching
the hooks/ version of the original.
"""

import importlib.util
import subprocess
import sys
import time
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, queue, fcfs

_spec = importlib.util.spec_from_file_location(
    "queue_manager", Path(__file__).resolve().parent / "queue-manager.py")
_qm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_qm)


def send_next(max_retries: int) -> int:
    """hooks/ variant: direct CLI invocation with argv list."""
    entry = _qm.dequeue()
    if not entry:
        print("No pending commands in queue")
        return 0
    print(f"=== Executing queued command [{entry['id'][:8]}] ===")
    cli = str(_qm.DEVIN_CLI) if _qm.DEVIN_CLI.exists() else "devin"
    argv = [cli, "-p", "--permission-mode=dangerous",
            "--respect-workspace-trust=false", "--", entry["command"]]
    last = ""
    for attempt in range(1, max_retries + 1):
        print(f"Attempt {attempt}/{max_retries}...")
        r = subprocess.run(argv, capture_output=True, text=True,
                           cwd=entry.get("workingDir") or None)
        last = r.stdout + r.stderr
        if r.returncode == 0:
            _qm._mark(entry["id"], "completed",
                      completedAt=time.strftime("%Y-%m-%dT%H:%M:%S%z"))
            return 0
        if attempt < max_retries:
            time.sleep(5)
    _qm._mark(entry["id"], "failed",
              failedAt=time.strftime("%Y-%m-%dT%H:%M:%S%z"),
              error=f"Failed after {max_retries} attempts. Last error: {last}")
    return 1


if __name__ == "__main__":
    _qm.send_next = send_next
    if "send-next" in sys.argv:
        args = sys.argv[sys.argv.index("send-next"):]
        retries = 3
        if "--max-retries" in sys.argv:
            retries = int(sys.argv[sys.argv.index("--max-retries") + 1])
        sys.exit(send_next(retries))
    _qm.main()
