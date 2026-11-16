"""Enhanced dev-tools installer (port of
tools/Variants/ENHANCED-DEV-TOOLS-INSTALLER-*.bat).

choco installs (nodejs, yarn, vscode, terminal, 7zip, cmake, powertoys,
fiddler, mongodb-compass, dbeaver, github-desktop, gitkraken) then
npm -g installs + npm/pnpm config. Mutating; --dry-run; --admin.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: install, choco, npm, dev-tools

CHOCO = ["nodejs", "yarn", "vscode", "microsoft-windows-terminal",
         "7zip", "cmake", "powertoys", "fiddler", "mongodb-compass",
         "dbeaver", "github-desktop", "gitkraken"]
NPM_GLOBAL = ["pnpm@latest", "@vue/cli", "@nuxt/cli", "typescript",
              "eslint", "prettier", "nodemon", "pm2", "@angular/cli",
              "create-react-app", "create-next-app", "@storybook/cli",
              "webpack", "webpack-cli", "parcel", "rollup", "vite"]
CONFIGS = [
    ["npm", "config", "set", "registry", "https://registry.npmjs.org/"],
    ["npm", "config", "set", "cache-max", "3600000"],
    ["npm", "config", "set", "cache-min", "3600000"],
    ["npm", "config", "set", "prefer-offline", "true"],
    ["npm", "config", "set", "audit-level", "moderate"],
    ["npm", "config", "set", "fund", "false"],
    ["pnpm", "config", "set", "registry", "https://registry.npmjs.org/"],
    ["pnpm", "config", "set", "store-dir", r"C:\pnpm-store"],
]


def run(cmd, dry, tag):
    if dry:
        print(f"[dry-run] {' '.join(cmd)}")
        return True
    r = subprocess.run(cmd, shell=(os_name_cmd(cmd)))
    if r.returncode == 0:
        print(f"[SUCCESS] {tag}")
        return True
    print(f"[WARNING] {tag} failed", file=sys.stderr)
    return False


def os_name_cmd(cmd):
    return cmd[0] in {"choco", "npm", "pnpm", "code", "node"}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    for pkg in CHOCO:
        extra = ["--force"] if pkg == "nodejs" else []
        run(["choco", "install", pkg, "-y", *extra], args.dry_run,
            f"{pkg} installed")

    # refreshenv equivalent: re-read Machine+User PATH so the freshly
    # installed node/npm is visible to this process.
    if args.dry_run:
        print("[dry-run] refresh PATH from registry")
    else:
        try:
            import winreg
            paths = []
            for hive, sub in ((winreg.HKEY_LOCAL_MACHINE,
                               r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"),
                              (winreg.HKEY_CURRENT_USER, r"Environment")):
                try:
                    with winreg.OpenKey(hive, sub) as k:
                        paths.append(winreg.QueryValueEx(k, "Path")[0])
                except OSError:
                    pass
            if paths:
                merged = os.pathsep.join(paths)
                merged = os.pathsep.join(
                    os.path.expandvars(e) for e in merged.split(os.pathsep))
                os.environ["PATH"] = merged
        except ImportError:
            pass  # non-Windows

    for pkg in NPM_GLOBAL:
        run(["npm", "install", "-g", pkg], args.dry_run,
            f"{pkg} installed")
    for cmd in CONFIGS:
        run(cmd, args.dry_run, f"{cmd[0]} configured: {cmd[3]}")

    for cfg in (["git", "config", "--global", "init.defaultBranch", "main"],
                ["git", "config", "--global", "core.autocrlf", "true"],
                ["git", "config", "--global", "core.safecrlf", "true"],
                ["git", "config", "--global", "pull.rebase", "true"],
                ["git", "config", "--global", "merge.tool", "vscode"]):
        run(cfg, args.dry_run, " ".join(cfg[3:]))

    import json
    root = Path(os.environ.get("USERPROFILE", "")) / "Desktop" / "DevOptimizer"
    ws = {"folders": [{"path": "./Projects"},
                      {"path": "./Templates"},
                      {"path": "./Scripts"}],
          "settings": {"editor.formatOnSave": True,
                       "editor.codeActionsOnSave":
                           {"source.fixAll.eslint": True},
                       "typescript.preferences.importModuleSpecifier":
                           "relative",
                       "javascript.preferences.importModuleSpecifier":
                           "relative"}}
    if args.dry_run:
        print(f"[dry-run] mkdir {root}\\{{Projects,Templates,Scripts}} "
              "+ DevOptimizer.code-workspace")
    else:
        for sub in ("Projects", "Templates", "Scripts"):
            (root / sub).mkdir(parents=True, exist_ok=True)
        (root / "DevOptimizer.code-workspace").write_text(
            json.dumps(ws, indent=2))
        print(f"[INFO] workspace created at {root}")

    print("[VERIFY] Verifying installations...")
    for probe in (["git", "--version"], ["node", "--version"],
                  ["npm", "--version"], ["code", "--version"]):
        run(probe, args.dry_run, " ".join(probe))


if __name__ == "__main__":
    main()
