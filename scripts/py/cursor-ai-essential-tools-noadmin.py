"""Port of tools/Variants/CURSOR-AI-ESSENTIAL-TOOLS-NoAdmin.bat —
installs dev essentials via choco (git-lfs, gh, docker-desktop,
python, rust, golang, openjdk, postman, insomnia, dbeaver,
mongodb-compass, redis-commander), wsl --install, git lfs install,
creates %USERPROFILE%\Desktop\DevOptimizer\CursorAI workspace
dirs + CursorAI.code-workspace, installs Cursor AI extensions.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

CHOCO_PKGS = ["git-lfs", "gh", "docker-desktop", "python", "rust",
              "golang", "openjdk", "postman", "insomnia", "dbeaver",
              "mongodb-compass", "redis-commander"]

WORKSPACE = {
    "folders": [{"path": "./Projects"}, {"path": "./Templates"},
                {"path": "./Scripts"}],
    "settings": {
        "editor.fontSize": 14,
        "editor.fontFamily": "Fira Code, Consolas, 'Courier New', monospace",
        "editor.fontLigatures": True,
        "editor.tabSize": 2,
        "editor.insertSpaces": True,
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
    },
}


def run(cmd, dry):
    if dry:
        print("[dry-run]", " ".join(cmd))
        return 0
    try:
        return subprocess.run(cmd).returncode
    except FileNotFoundError:
        print(f"[WARNING] not found: {cmd[0]}")
        return 127


def main():
    ap = argparse.ArgumentParser(
        description="Cursor AI essential tools installer")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    for i, pkg in enumerate(CHOCO_PKGS, 1):
        print(f"[{i}/{len(CHOCO_PKGS)}] choco install {pkg}")
        run(["choco", "install", pkg, "-y"], args.dry_run)
    print("[wsl] wsl --install")
    run(["wsl", "--install"], args.dry_run)
    run(["wsl", "--set-default-version", "2"], args.dry_run)
    run(["git", "lfs", "install"], args.dry_run)
    base = Path(os.environ.get("USERPROFILE", "")) / "Desktop" \
        / "DevOptimizer" / "CursorAI"
    if args.dry_run:
        print(f"[dry-run] create {base} + workspace file")
    else:
        for d in ("", "Projects", "Templates", "Scripts"):
            (base / d).mkdir(parents=True, exist_ok=True)
        (base / "CursorAI.code-workspace").write_text(
            json.dumps(WORKSPACE, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
