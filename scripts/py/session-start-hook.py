"""SessionStart sync-context hook (Python port of devin/hooks/session-start.ps1).

Injects live git context into the session: latest origin/main head, open
PRs, PRs merged in the last 24h, then processes the next devin-queue
command. Emits hookSpecificOutput JSON.
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

# CATEGORY: utilities
# TAGS: devin, hook, session, queue

QUEUE_MANAGER = Path(r"C:\Users\tbaltzakis\devin-queue\hooks\queue-manager.ps1")
GH = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "gh-cli" / "bin" / "gh.exe"
PWSH = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WindowsApps" / "pwsh.exe"


def run(cmd, timeout=60) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return (out.stdout or "").strip()
    except Exception:
        return ""


def main() -> None:
    sys.stdin.read()  # consume the event JSON
    ctx = []

    run(["git", "fetch", "--all", "--prune", "-q"], timeout=30)
    head = run(["git", "log", "-1", "--format=%h %s (%cr, %an)", "origin/main"])
    if head:
        ctx.append("origin/main head: " + head)

    gh = str(GH) if GH.exists() else "gh"
    open_prs = run([gh, "pr", "list", "--limit", "30"], timeout=45)
    if open_prs:
        ctx.append("Open PRs:\n" + open_prs)
    since = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
    merged = run([gh, "pr", "list", "--state", "merged",
                  "--search", f"merged:>={since}", "--limit", "20"], timeout=45)
    if merged:
        ctx.append("Merged in last 24h:\n" + merged)
    ctx.append("Before any PR or push: re-check this list, never duplicate "
               "another agent's PR, branch from latest origin/main.")

    if QUEUE_MANAGER.exists():
        pwsh = str(PWSH) if PWSH.exists() else "pwsh"
        proc = subprocess.run(
            [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass",
             "-WindowStyle", "Hidden", "-File", str(QUEUE_MANAGER),
             "-Action", "send-next"],
            capture_output=True, timeout=300)
        if proc.returncode == 0:
            ctx.append("\n[Queue] Next queued command executed successfully")
        elif proc.returncode == 1:
            ctx.append("\n[Queue] Queued command failed after retries")
        else:
            ctx.append("\n[Queue] No pending commands in queue")

    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n".join(ctx)}}, separators=(",", ":")))


if __name__ == "__main__":
    main()
