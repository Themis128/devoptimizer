"""Port of scripts/devin/queue/session-start.ps1.

Devin SessionStart hook: emits additionalContext JSON
with latest origin/main, open PRs, 24h merges, then
runs queue-manager.ps1 -Action send-next via pwsh.
"""

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

GH = (Path(os.environ.get("LOCALAPPDATA", ""))
      / "Programs" / "gh-cli" / "bin" / "gh.exe")
QM = Path("C:/Users/tbaltzakis/devin-queue/hooks/"
          "queue-manager.ps1")


def run(cmd, timeout=30):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True, timeout=timeout)
    except Exception:
        return None


def main():
    sys.stdin.read()
    ctx = []
    run(["git", "fetch", "--all", "--prune", "-q"])
    r = run(["git", "log", "-1",
             "--format=%h %s (%cr, %an)",
             "origin/main"])
    if r and r.stdout.strip():
        ctx.append("origin/main head: "
                   + r.stdout.strip())
    gh = str(GH) if GH.exists() else "gh"
    r = run([gh, "pr", "list", "--limit", "30"])
    if r and r.stdout:
        ctx.append("Open PRs:\n" + r.stdout)
    since = (datetime.now() - timedelta(days=1)
             ).strftime("%Y-%m-%d")
    r = run([gh, "pr", "list", "--state", "merged",
             "--search", f"merged:>={since}",
             "--limit", "20"])
    if r and r.stdout:
        ctx.append("Merged in last 24h:\n" + r.stdout)
    ctx.append("Before any PR or push: re-check this "
               "list, never duplicate another agent's "
               "PR, branch from latest origin/main.")

    if QM.exists():
        pwsh = (os.environ.get("LOCALAPPDATA", "")
                + r"\Microsoft\WindowsApps\pwsh.exe")
        if not Path(pwsh).exists():
            pwsh = shutil.which("pwsh") or "pwsh"
        r = run([pwsh, "-NoProfile", "-ExecutionPolicy",
                 "Bypass", "-WindowStyle", "Hidden",
                 "-File", str(QM), "-Action",
                 "send-next"], timeout=None)
        rc = r.returncode if r else -1
        if rc == 0:
            ctx.append("\n[Queue] Next queued command "
                       "executed successfully")
        elif rc == 1:
            ctx.append("\n[Queue] Queued command "
                       "failed after retries")
        else:
            ctx.append("\n[Queue] No pending commands "
                       "in queue")

    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n".join(ctx)}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
