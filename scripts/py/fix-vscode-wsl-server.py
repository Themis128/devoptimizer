"""Fix corrupted VS Code Server in WSL (port of
scripts/fix-vscode-wsl-server.ps1).

Enumerates `wsl -l -q` distros (skipping docker-desktop/*data*) and
removes ~/.vscode-server + ~/.vscode-remote in each so the next
connect reinstalls. Mutating; --dry-run.
"""

import argparse
import os
import subprocess
import sys

# CATEGORY: utilities
# TAGS: wsl, vscode, server, fix

SKIP = ("docker-desktop", "data")


def wsl(args_, **kw):
    env = dict(os.environ, WSL_UTF8="1")
    return subprocess.run(["wsl.exe", *args_], capture_output=True,
                          text=True, env=env, **kw)


def distros():
    r = wsl(["-l", "-q"])
    out = []
    for line in r.stdout.splitlines():
        name = line.strip().replace("\x00", "")
        if name and not any(s in name for s in SKIP):
            out.append(name)
    return out


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    print("=== Fix VS Code Server in WSL ===")
    if args.dry_run:
        for d in distros():
            print(f"[dry-run] {d}: rm -rf ~/.vscode-server "
                  "~/.vscode-remote")
        return
    for d in distros():
        print(f"-- {d}")
        r = wsl(["-d", d, "--", "bash", "-c",
                 "rm -rf ~/.vscode-server ~/.vscode-remote; "
                 "echo cleaned"])
        if r.returncode == 0:
            print("   cleaned")
        else:
            print(f"   failed: {r.stderr.strip()}", file=sys.stderr)
    print("Reconnect VS Code to WSL — it reinstalls the server.")


if __name__ == "__main__":
    main()
