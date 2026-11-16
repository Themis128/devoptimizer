"""WSL Ubuntu deep clean (port of scripts/wsl-deep-clean.ps1).

Standard cleanups (apt, journals, docker prune, package caches, LSP
caches, VS Code server caches, git gc) + aggressive passes
(node_modules, build artifacts, editor temp). --distro; --dry-run;
--no-aggressive.
"""

import argparse
import subprocess
import sys

# CATEGORY: cleanup
# TAGS: wsl, ubuntu, apt, caches, docker

STANDARD = [
    ("apt-get clean -y 2>/dev/null", "apt clean"),
    ("apt-get autoclean -y 2>/dev/null", "apt autoclean"),
    ("apt-get autoremove -y 2>/dev/null", "apt autoremove"),
    ("rm -rf /tmp/* /var/tmp/* 2>/dev/null", "temp folders"),
    ("journalctl --vacuum-time=3d 2>/dev/null", "journald (3 days)"),
    ("docker system prune -f --volumes "
     "--filter 'label!=com.docker.desktop.service=model-runner' "
     "--filter 'label!=com.docker.model-runner.role=model-storage' "
     "2>/dev/null", "docker system prune"),
    ("npm cache clean --force 2>/dev/null", "npm cache"),
    ("pip cache purge 2>/dev/null", "pip cache"),
    ("yarn cache clean 2>/dev/null", "yarn cache"),
    ("pnpm store prune 2>/dev/null", "pnpm store"),
    ("cargo clean 2>/dev/null", "cargo cache"),
    ("go clean -cache 2>/dev/null", "go cache"),
    ("rm -rf /home/*/.cache/pip /home/*/.cache/pipx 2>/dev/null",
     "pip user cache"),
    ("rm -rf /home/*/.cache/yarn /home/*/.cache/pnpm 2>/dev/null",
     "yarn/pnpm user cache"),
    ("rm -rf /home/*/.cache/pre-commit 2>/dev/null",
     "pre-commit cache"),
    ("rm -rf /home/*/.ccache 2>/dev/null", "ccache"),
    ("flatpak uninstall --unused -y 2>/dev/null", "flatpak unused"),
    ("snap list --all 2>/dev/null | awk '/disabled/{print $1}' | "
     "xargs -r snap remove 2>/dev/null", "snap disabled revisions"),
    ("rm -rf /var/lib/apt/lists/* 2>/dev/null; apt-get update "
     "2>/dev/null", "apt lists refresh"),
    ("rm -rf /home/*/.vscode-server/data/CachedData 2>/dev/null",
     "VS Code CachedData"),
    ("rm -rf /home/*/.vscode-server/data/User/workspaceStorage "
     "2>/dev/null", "VS Code workspaceStorage"),
    ("rm -rf /home/*/.vscode-server/data/logs 2>/dev/null",
     "VS Code logs"),
    ("rm -rf /home/*/.vscode-server/extensionsCache 2>/dev/null",
     "VS Code extensions cache"),
    ("rm -rf /home/*/.vscode-server/bin/*/node_modules 2>/dev/null",
     "VS Code server node_modules"),
    ("rm -rf /home/*/.cache/typescript 2>/dev/null",
     "TypeScript language server cache"),
    ("rm -rf /home/*/.cache/pylint 2>/dev/null", "pylint cache"),
    ("rm -rf /home/*/.cache/mypy 2>/dev/null", "mypy cache"),
    ("rm -rf /home/*/.cache/ruff 2>/dev/null", "ruff cache"),
    ("rm -rf /home/*/.cache/jedi 2>/dev/null", "jedi cache"),
    ("rm -rf /home/*/.cache/gopls 2>/dev/null", "gopls cache"),
    ("rm -rf /home/*/.cache/rust-analyzer 2>/dev/null",
     "rust-analyzer cache"),
    ("rm -rf /home/*/.cache/clangd 2>/dev/null", "clangd cache"),
    ("find /home -name '.git' -type d -execdir git -C {} gc "
     "--aggressive --prune=now \\; 2>/dev/null", "Git GC (aggressive)"),
]

AGGRESSIVE = [
    ("find /home -name 'node_modules' -type d -prune -exec rm -rf {} "
     "+ 2>/dev/null", "node_modules (requires npm install)"),
    ("find /home -name 'dist' -o -name 'build' -o -name '.next' -o "
     "-name '.nuxt' -o -name 'target' -o -name '__pycache__' -o -name "
     "'*.pyc' -o -name '.pytest_cache' -o -name '.coverage' -o -name "
     "'.tox' -o -name '.mypy_cache' -o -name '.ruff_cache' | xargs -r "
     "rm -rf 2>/dev/null", "Build/test artifacts"),
    ("find /home -name '*~' -o -name '*.swp' -o -name '*.swo' -o "
     "-name '.#*' | xargs -r rm -f 2>/dev/null", "Editor temp files"),
]

PROBE_DIRS = ("du -sh /home/*/.cache /home/*/.npm /home/*/.cargo "
              "/home/*/go/pkg /var/cache/apt /var/log /tmp /var/tmp "
              "2>/dev/null | sort -hr")


def wsl(distro, cmd, dry=False):
    if dry:
        print(f"[dry-run] wsl -d {distro} bash -c \"{cmd}\"")
        return ""
    r = subprocess.run(["wsl.exe", "-d", distro, "-e", "bash", "-c",
                        cmd], capture_output=True, text=True,
                       errors="replace")
    return r.stdout


def run_set(items, distro, dry):
    for cmd, desc in items:
        if dry:
            print(f"[dry-run] {desc}: {cmd}")
            continue
        try:
            out = wsl(distro, f"{cmd}; echo 'DONE:{desc}'")
            lines = [l for l in out.splitlines() if l.strip()]
            last = lines[-1].strip() if lines else ""
            if last.startswith("DONE:"):
                print(f"  [OK] {desc}")
            elif last:
                print(f"  [INFO] {desc}: {last}")
        except Exception as e:
            print(f"  [WARN] {desc} failed: {e}", file=sys.stderr)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--distro", default="Ubuntu-24.04")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-aggressive", action="store_true")
    args = p.parse_args()
    d, dry = args.distro, args.dry_run

    print(f"=== WSL Deep Clean: {d} ===")
    running = subprocess.run(["wsl.exe", "-l", "--running"],
                             capture_output=True, text=True,
                             errors="replace").stdout if not dry else ""
    if dry or d not in running.replace("\x00", ""):
        print(f"Starting {d}...")
        wsl(d, "true", dry)

    print("\n--- Disk Usage BEFORE ---")
    print(wsl(d, "df -h / | tail -1", dry))
    print("--- Top Space Consumers BEFORE ---")
    print(wsl(d, PROBE_DIRS, dry))

    print("\n--- Running Standard Cleanups ---")
    run_set(STANDARD, d, dry)
    if not args.no_aggressive:
        print("\n--- Aggressive Cleanups (removes build artifacts) ---")
        run_set(AGGRESSIVE, d, dry)

    print("\n--- Disk Usage AFTER ---")
    print(wsl(d, "df -h / | tail -1", dry))
    print("--- Top Space Consumers AFTER ---")
    print(wsl(d, PROBE_DIRS, dry))

    print("\n--- WSL vhdx Compaction ---")
    print("To compact the virtual disk:")
    print("  1. wsl --shutdown")
    print(f"  2. optimize-vhd -Path '\\\\wsl.localhost\\{d}\\ext4.vhdx' "
          "-Mode Full   (Administrator PowerShell)")


if __name__ == "__main__":
    main()
