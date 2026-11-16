"""Port of tools/Variants/CURSOR-AI-COMPLETE-OPTIMIZER-Admin.bat — interactive
menu: deep clean, cursor config, packages, perf, security, network, memory, dev tools, analytics, complete, report. --mode runs non-interactively; --dry-run prints.
"""
# REQUIRES: admin
import ctypes

def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required", file=sys.stderr)
        sys.exit(1)

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def run(cmd):
    try:
        return subprocess.run(cmd).returncode
    except FileNotFoundError:
        print(f"[WARNING] not found: {cmd[0]}")
        return 127


def git_cache_clear():
    for cmd in (["git", "gc", "--prune=now"],
                ["git", "reset", "--hard", "HEAD"],
                ["git", "stash", "clear"],
                ["git", "reflog", "expire", "--expire=now", "--all"],
                ["git", "remote", "prune", "origin"],
                ["git", "lfs", "prune"],
                ["git", "worktree", "prune"]):
        run(list(cmd))


def cursor_config():
    d = Path(os.environ.get("APPDATA", "")) / "Cursor" / "User"
    d.mkdir(parents=True, exist_ok=True)
    settings = {
        "editor.fontSize": 14,
        "editor.fontFamily": "Fira Code, Consolas, 'Courier New', monospace",
        "editor.fontLigatures": True,
        "editor.tabSize": 2,
        "editor.insertSpaces": True,
        "editor.detectIndentation": False,
        "editor.formatOnSave": True,
        "editor.codeActionsOnSave": {
            "source.fixAll.eslint": True,
            "source.organizeImports": True},
        "files.autoSave": "afterDelay",
        "files.autoSaveDelay": 1000,
        "typescript.preferences.importModuleSpecifier": "relative",
        "javascript.preferences.importModuleSpecifier": "relative",
        "emmet.includeLanguages": {
            "javascript": "javascriptreact",
            "typescript": "typescriptreact"},
        "git.enableSmartCommit": True,
        "git.confirmSync": False,
        "git.autofetch": True,
        "terminal.integrated.fontSize": 14,
        "terminal.integrated.fontFamily": "Fira Code, Consolas, 'Courier New', monospace",
        "workbench.colorTheme": "Default Dark+",
        "workbench.iconTheme": "material-icon-theme",
        "extensions.autoUpdate": True,
        "extensions.autoCheckUpdates": True,
        "cursor.ai.enabled": True,
        "cursor.ai.autoComplete": True,
        "cursor.ai.suggestions": True,
    }
    (d / "settings.json").write_text(
        json.dumps(settings, indent=4), encoding="utf-8")
    print(f"[INFO] wrote {d / 'settings.json'}")


def package_optimization():
    for k, v in (("registry", "https://registry.npmjs.org/"),
                 ("cache-max", "3600000"), ("cache-min", "3600000"),
                 ("prefer-offline", "true"),
                 ("audit-level", "moderate"), ("fund", "false"),
                 ("save-exact", "true"), ("save-prefix", "")):
        run(["npm", "config", "set", k, v])
    for k, v in (("registry", "https://registry.npmjs.org/"),
                 ("store-dir", r"C:\pnpm-store"),
                 ("cache-dir", r"C:\pnpm-cache"),
                 ("auto-install-peers", "true"),
                 ("strict-peer-dependencies", "false")):
        run(["pnpm", "config", "set", k, v])
    for k, v in (("registry", "https://registry.npmjs.org/"),
                 ("cache-folder", r"C:\yarn-cache"),
                 ("network-timeout", "300000"),
                 ("network-concurrency", "1")):
        run(["yarn", "config", "set", k, v])


def performance_optimization():
    tmp = Path(os.environ.get("TEMP", ""))
    if tmp.is_dir():
        for c in tmp.iterdir():
            try:
                if c.is_dir():
                    shutil.rmtree(c, ignore_errors=True)
                else:
                    c.unlink(missing_ok=True)
            except OSError:
                pass
    for k, v in (("core.preloadindex", "true"),
                 ("core.fscache", "true"), ("gc.auto", "256"),
                 ("pack.windowMemory", "100m"),
                 ("pack.packSizeLimit", "2g")):
        run(["git", "config", "--global", k, v])
    run(["powercfg", "-h", "off"])


def security_hardening():
    for k, v in (("core.protectNTFS", "true"),
                 ("core.protectHFS", "true"),
                 ("core.fsmonitor", "true")):
        run(["git", "config", "--global", k, v])
    for k, v in (("audit-level", "high"), ("fund", "false"),
                 ("save-exact", "true")):
        run(["npm", "config", "set", k, v])
    run(["netsh", "advfirewall", "set", "allprofiles",
         "state", "on"])


def network_optimization():
    for k, v in (("autotuninglevel", "normal"),
                 ("chimney", "enabled"), ("rss", "enabled"),
                 ("netdma", "enabled")):
        run(["netsh", "int", "tcp", "set", "global",
             f"{k}={v}"])


def memory_optimization():
    os.environ["NODE_OPTIONS"] = "--max-old-space-size=8192"
    os.environ["NODE_ENV"] = "development"
    print("[INFO] NODE_OPTIONS=--max-old-space-size=8192 "
          "NODE_ENV=development (current session)")


def dev_tools():
    for pkg in ("@vue/cli", "@nuxt/cli", "typescript", "eslint",
                "prettier", "nodemon", "pm2"):
        run(["npm", "install", "-g", pkg])


def analytics_setup():
    d = Path(os.environ.get("USERPROFILE", "")) / "Desktop" \
        / "DevOptimizer" / "Analytics"
    d.mkdir(parents=True, exist_ok=True)
    bat = d / "cursor-analytics.bat"
    bat.write_text(
        "@echo off\n"
        "echo Cursor AI Development Analytics\n"
        "echo ==================================\n"
        "echo.\n"
        "echo Git commits today:\n"
        'git log --since="1 day ago" --oneline | wc -l\n'
        "echo.\n"
        "echo Git commits this week:\n"
        'git log --since="1 week ago" --oneline | wc -l\n'
        "echo.\n"
        "echo Git commits this month:\n"
        'git log --since="1 month ago" --oneline | wc -l\n'
        "echo.\n"
        "pause\n", encoding="ascii")
    print(f"[INFO] wrote {bat}")


def system_deep_clean():
    ps = shutil.which("pwsh") or shutil.which("powershell") \
        or "powershell"
    script = (Path(__file__).resolve().parents[2]
              / "scripts" / "FIXED-SYSTEM-DEEP-CLEAN.ps1")
    return run([ps, "-ExecutionPolicy", "Bypass", "-File",
                str(script)])


def system_report():
    for cmd in (["git", "--version"],
                ["git", "config", "--global", "user.name"],
                ["git", "config", "--global", "user.email"],
                ["node", "--version"], ["npm", "--version"],
                ["pnpm", "--version"], ["yarn", "--version"]):
        run(list(cmd))
    cursor = Path(os.environ.get("APPDATA", "")) / "Cursor"
    print("Cursor config:", "present" if cursor.exists()
          else "absent")


MODES = {
    "system-deep-clean": system_deep_clean,
    "cursor-config": cursor_config,
    "package-optimization": package_optimization,
    "performance-optimization": performance_optimization,
    "security-hardening": security_hardening,
    "network-optimization": network_optimization,
    "memory-optimization": memory_optimization,
    "dev-tools-setup": dev_tools,
    "analytics-monitoring": analytics_setup,
    "complete-optimization": complete,
    "system-report": system_report,
}


def complete():
    for m in ["system-deep-clean","cursor-config","package-optimization","performance-optimization","security-hardening","network-optimization","memory-optimization","dev-tools-setup","analytics-monitoring"]:
        MODES[m]()


def main():
    _ensure_admin()
    ap = argparse.ArgumentParser(description="Cursor AI complete-optimizer (admin)")
    ap.add_argument("--mode", choices=list(MODES) + ["all"])
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.dry_run:
        print("[dry-run] mode", args.mode or "menu")
        return 0
    if args.mode == "all" or args.mode == "complete-optimization":
        complete()
        return 0
    if args.mode:
        MODES[args.mode]()
        return 0
    names = list(MODES)
    for i, m in enumerate(names, 1):
        print(f"  {i}) {m}")
    print("  0) exit")
    if not sys.stdin.isatty():
        print("Non-interactive launch: pass --mode <name> or "
              "--mode all")
        return 0
    sel = input("Enter your choice: ").strip()
    if sel.isdigit() and 1 <= int(sel) <= len(names):
        MODES[names[int(sel) - 1]]()
    return 0


if __name__ == "__main__":
    sys.exit(main())
