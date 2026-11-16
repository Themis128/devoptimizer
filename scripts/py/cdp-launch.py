"""CDP launcher (port of scripts/startup/cdp-launch.bat).

Starts headless Chrome on :9330 (debug profile) and the CDP relay on
:9229 — only when each port isn't already listening.
"""

import argparse
import socket
import subprocess
import sys

# CATEGORY: utilities
# TAGS: cdp, chrome, startup

CHROME = (r"C:\Program Files\Google\Chrome\Application\chrome.exe")
CHROME_ARGS = [
    "--headless=new", "--remote-debugging-port=9330",
    "--remote-allow-origins=*",
    "--user-data-dir=C:\\Users\\tbaltzakis\\chrome-debug-profile",
    "about:blank",
]
RELAY = r"C:\Users\tbaltzakis\devin-scripts\cdp_relay.py"


def listening(port: int) -> bool:
    with socket.socket() as s:
        return s.connect_ex(("127.0.0.1", port)) == 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not listening(9330):
        cmd = [CHROME, *CHROME_ARGS]
        if args.dry_run:
            print("[dry-run] " + " ".join(cmd))
        else:
            subprocess.Popen(cmd)
            print("chrome :9330 launched", file=sys.stderr)
    if not listening(9229):
        cmd = ["pythonw", RELAY]
        if args.dry_run:
            print("[dry-run] " + " ".join(cmd))
        else:
            subprocess.Popen(cmd)
            print("cdp relay :9229 launched", file=sys.stderr)


if __name__ == "__main__":
    main()
