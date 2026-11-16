"""Enhanced dev-tools installer (port of
tools/Variants/ENHANCED-DEV-TOOLS-INSTALLER-*.bat).

choco installs (nodejs, yarn, vscode, terminal, 7zip, cmake, powertoys,
fiddler, mongodb-compass, dbeaver, github-desktop, gitkraken) then
npm -g installs + npm/pnpm config. Mutating; --dry-run; --admin.
"""

import argparse
import subprocess
import sys

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
    return cmd[0] in {"choco", "npm", "pnpm"}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    for pkg in CHOCO:
        extra = ["--force"] if pkg == "nodejs" else []
        run(["choco", "install", pkg, "-y", *extra], args.dry_run,
            f"{pkg} installed")
    for pkg in NPM_GLOBAL:
        run(["npm", "install", "-g", pkg], args.dry_run,
            f"{pkg} installed")
    for cmd in CONFIGS:
        run(cmd, args.dry_run, f"{cmd[0]} configured: {cmd[3]}")


if __name__ == "__main__":
    main()
