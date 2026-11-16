"""Port of scripts/git-pr-check.ps1.

Pre-PR situational check: origin/main HEAD, divergence, open PRs,
24h merges, worktree summary. Report-only, always exits 0.
-Json for machine-readable output.
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def git(*args):
    r = subprocess.run(["git"] + list(args),
                       capture_output=True, text=True,
                       cwd=REPO_ROOT)
    return r.stdout.strip() if r.returncode == 0 else ""


def gh(*args):
    r = subprocess.run(["gh"] + list(args),
                       capture_output=True, text=True,
                       cwd=REPO_ROOT)
    if r.returncode != 0:
        return []
    try:
        return json.loads(r.stdout)
    except Exception:
        return []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-NoFetch", action="store_true")
    ap.add_argument("-Json", action="store_true")
    a = ap.parse_args()

    if not a.NoFetch:
        subprocess.run(["git", "fetch", "origin", "--quiet"],
                       capture_output=True, cwd=REPO_ROOT)
    head = git("rev-parse", "--short", "origin/main")
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    ahead = git("rev-list", "--count", "origin/main..HEAD") or "0"
    behind = git("rev-list", "--count", "HEAD..origin/main") or "0"
    dirty = len([l for l in git("status", "--porcelain")
                 .splitlines() if l])

    open_prs = gh("pr", "list", "--state", "open", "--json",
                  "number,title,author,headRefName,createdAt",
                  "--limit", "30")
    merged = gh("pr", "list", "--state", "merged", "--json",
                "number,title,author,mergedAt", "--limit", "50",
                "--search", "merged:>=2026-11-08")
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    merged24 = [p for p in merged
                if datetime.fromisoformat(
                    p["mergedAt"].replace("Z", "+00:00")) > cutoff]

    if a.Json:
        print(json.dumps({
            "originMainHead": head, "branch": branch,
            "ahead": int(ahead), "behind": int(behind),
            "dirtyEntries": dirty, "openPrs": open_prs,
            "mergedLast24h": merged24}, indent=2))
        return 0

    print(f"=== Pre-PR check: {REPO_ROOT} ===")
    print(f"origin/main HEAD : {head}")
    print(f"current branch   : {branch}  (ahead {ahead}, "
          f"behind {behind}, dirty entries {dirty})")
    if branch == "main":
        print("NOTE: on main - create a feature branch before "
              "PR work")
    if int(behind) > 0:
        print(f"NOTE: branch is {behind} commit(s) behind "
              "origin/main - rebase before PR")

    print(f"\n--- Open PRs ({len(open_prs)}) ---")
    if not open_prs:
        print("  (none)")
    for p in open_prs:
        created = datetime.fromisoformat(
            p["createdAt"].replace("Z", "+00:00"))
        print(f"  #{p['number']:<4} {p['headRefName']:<28} "
              f"{p['author']['login']}  "
              f"({created:%m-%d})")
        print(f"        {p['title']}")

    print(f"\n--- Merged in last 24h ({len(merged24)}) ---")
    if not merged24:
        print("  (none)")
    for p in merged24:
        when = datetime.fromisoformat(
            p["mergedAt"].replace("Z", "+00:00"))
        print(f"  #{p['number']:<4} {p['title']}  by "
              f"{p['author']['login']} at {when:%m-%d %H:%M}")

    print("\nReminder: never duplicate another agent's open "
          "PR; branch from latest origin/main.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
