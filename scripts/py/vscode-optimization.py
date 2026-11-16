"""Port of scripts/vscode-optimization.ps1 — applies a curated
settings.json profile to VS Code Stable or Insiders, optionally
installing extensions (--install-extensions, --extensions list).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

SETTINGS = {
    "editor.fontSize": 14,
    "editor.tabSize": 2,
    "editor.insertSpaces": True,
    "editor.formatOnSave": True,
    "files.autoSave": "afterDelay",
    "workbench.colorTheme": "Dark+ (default dark)",
    "terminal.integrated.fontSize": 14,
}
DEFAULT_EXTS = ["ms-vscode.powershell", "ms-python.python",
                "esbenp.prettier-vscode"]


def code_info(insiders):
    edition = "Insiders" if insiders else "Stable"
    cmd = "code-insiders" if insiders else "code"
    info = {"installed": False, "version": None, "edition": edition,
            "command": cmd}
    exe = shutil.which(cmd)
    if not exe:
        return info
    info["installed"] = True
    info["install_path"] = str(Path(exe).parent)
    try:
        r = subprocess.run([cmd, "--version"],
                           capture_output=True, text=True,
                           timeout=15)
        lines = r.stdout.splitlines()
        if lines:
            info["version"] = lines[0]
    except (OSError, subprocess.SubprocessError):
        print("Could not determine VS Code version")
    appdata = os.environ.get("APPDATA", "")
    home = Path(os.environ.get("USERPROFILE", str(Path.home())))
    if insiders:
        info["config_path"] = Path(appdata) / "Code - Insiders" \
            / "User"
        info["extensions_path"] = home / ".vscode-insiders" \
            / "extensions"
    else:
        info["config_path"] = Path(appdata) / "Code" / "User"
        info["extensions_path"] = home / ".vscode" / "extensions"
    return info


def apply_settings(info):
    try:
        spath = info["config_path"] / "settings.json"
        spath.parent.mkdir(parents=True, exist_ok=True)
        spath.write_text(json.dumps(SETTINGS, indent=4),
                         encoding="utf-8")
        print("VS Code settings applied successfully")
        return True
    except OSError as e:
        print(f"Error applying settings: {e}")
        return False


def install_extensions(info, exts):
    exts = exts or DEFAULT_EXTS
    try:
        for ext in exts:
            print(f"Installing {ext}...")
            subprocess.run([info["command"],
                            "--install-extension", ext,
                            "--force"], capture_output=True)
            print(f"Installed {ext}")
        return True
    except (OSError, subprocess.SubprocessError) as e:
        print(f"Error installing extensions: {e}")
        return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--insiders", action="store_true")
    p.add_argument("--install-extensions", action="store_true")
    p.add_argument("--extensions", nargs="*", default=[])
    a = p.parse_args()

    print(f"Gathering Visual Studio Code"
          f" {'Insiders' if a.insiders else 'Stable'} installation"
          " information...")
    info = code_info(a.insiders)
    if not info["installed"]:
        print("VS Code is not installed")
        return 1

    print("Running VS Code optimization...")
    ok = apply_settings(info)
    if a.install_extensions:
        ok = install_extensions(info, a.extensions) and ok
    print("VS Code optimization completed"
          + (" successfully" if ok else " with warnings"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
