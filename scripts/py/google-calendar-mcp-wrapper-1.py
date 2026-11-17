"""Launch the Google Calendar MCP server (Python port of google-calendar-mcp-wrapper.ps1).

Runs `npx -y @cocal/google-calendar-mcp@2.7.0 start` with
GOOGLE_OAUTH_CREDENTIALS set, stderr appended to the MCP log file.
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

# CATEGORY: utilities
# TAGS: mcp, google-calendar, launcher

LOG_FILE = Path(r"C:\Users\tbaltzakis\.zcode\logs\google-calendar-mcp.log")
CREDS = r"C:\Users\tbaltzakis\.config\google-calendar-mcp\gcp-oauth.keys.json"
NPX = r"C:\Program Files\nodejs\npx.cmd"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the command line without running it")
    parser.add_argument("--npx", default=NPX, help="npx.cmd path")
    args = parser.parse_args()

    cmd = [args.npx, "-y", "@cocal/google-calendar-mcp@2.7.0", "start"]
    env = dict(os.environ, GOOGLE_OAUTH_CREDENTIALS=CREDS)

    if args.dry_run:
        print(f"[dry-run] GOOGLE_OAUTH_CREDENTIALS={CREDS}")
        print(f"[dry-run] stderr -> {LOG_FILE}")
        print(f"[dry-run] cmd: {' '.join(cmd)}")
        return

    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    stdout_tmp = Path(tempfile.gettempdir()) / "google-calendar-mcp-stdout.tmp"
    with LOG_FILE.open("ab") as err, stdout_tmp.open("wb") as out:
        proc = subprocess.run(cmd, env=env, stdout=out, stderr=err)
    try:
        stdout_tmp.unlink()
    except OSError:
        pass
    sys.exit(proc.returncode)


if __name__ == "__main__":
    main()
