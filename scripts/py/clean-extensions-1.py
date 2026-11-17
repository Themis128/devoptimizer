"""Clean stale WSL vscode-server extensions (port of
scripts/clean-extensions.ps1).

rm -rf's the pinned extension dirs inside Ubuntu-24.04's
~/.vscode-server/extensions. Mutating; --dry-run; --json.
"""

import argparse
import json
import os
import subprocess
import sys

# CATEGORY: cleanup
# TAGS: wsl, vscode, extensions

EXTS = [
    "bradlc.vscode-tailwindcss-0.16.0",
    "christian-kohler.path-intellisense-2.10.0",
    "dbaeumer.vscode-eslint-3.0.34",
    "esbenp.prettier-vscode-12.4.0",
    "github.vscode-github-actions-0.32.3",
    "huggingface.huggingface-vscode-chat-0.3.0",
    "ms-azuretools.vscode-containers-2.5.0",
    "ms-azuretools.vscode-docker-2.0.0",
    "ms-playwright.playwright-1.1.19",
    "ms-python.debugpy-2026.6.0-linux-x64",
    "ms-python.python-2026.4.0-linux-x64",
    "ms-python.vscode-pylance-2026.3.1",
]
BASE = "/home/tbaltzakis/.vscode-server/extensions"


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    if args.dry_run:
        for e in EXTS:
            print(f"[dry-run] rm -rf {BASE}/{e}")
        return
    env = dict(os.environ, WSL_UTF8="1")
    r = subprocess.run(
        ["wsl.exe", "-d", "Ubuntu-24.04", "-e", "bash", "-c",
         "; ".join(f'rm -rf "{BASE}/{e}"' for e in EXTS)],
        capture_output=True, text=True, env=env)
    if args.json:
        print(json.dumps({"removed": EXTS,
                          "returncode": r.returncode}))
    else:
        if r.stderr.strip():
            print(r.stderr.strip(), file=sys.stderr)
        print(f"removed {len(EXTS)} stale extensions")
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
