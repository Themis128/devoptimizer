"""Port of scripts/ai-development-tools.ps1 — install/optimize AI dev
tools: --install-all (default), --cursor-only, --copilot-only,
--local-ai-only, --verbose, --dry-run.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

# CATEGORY: ai-ml
# TAGS: cursor, copilot, ollama, setup

CURSOR_SETTINGS = {
    "editor.fontSize": 14,
    "editor.fontFamily": "'Cascadia Code', 'Fira Code', "
    "'JetBrains Mono', Consolas, monospace",
    "editor.fontLigatures": True,
    "editor.bracketPairColorization.enabled": True,
    "editor.guides.bracketPairs": "active",
    "editor.minimap.enabled": True,
    "editor.wordWrap": "bounded",
    "editor.renderWhitespace": "boundary",
    "editor.smoothScrolling": True,
    "workbench.iconTheme": "material-icon-theme",
    "workbench.colorTheme": "One Dark Pro",
    "extensions.autoUpdate": True,
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 500,
    "editor.inlineSuggest.enabled": True,
    "editor.suggest.preview": True,
    "editor.parameterHints.enabled": True,
    "git.autoFetch": True,
    "git.autofetchPeriod": 120,
    "terminal.integrated.fontSize": 13,
    "workbench.editor.enablePreview": False,
    "editor.formatOnSave": True,
    "editor.formatOnPaste": True,
    "editor.linkedEditing": True,
    "editor.hover.sticky": True,
    "editor.stickyScroll.enabled": True,
    "breadcrumbs.enabled": True,
    "explorer.confirmDragAndDrop": False,
    "explorer.confirmDelete": False,
    "github.copilot.enable": {"*": True, "yaml": False,
                              "plaintext": False},
    "cursor.ai.enable": True,
    "cursor.ai.autoComplete": True,
    "cursor.ai.chat.enable": True,
    "search.useGlobalIgnoreFiles": True,
    "search.useParentIgnoreFiles": True,
    "search.followSymlinks": False,
    "files.watcherExclude": {
        "**/.git/objects/**": True, "**/.git/subtree-cache/**": True,
        "**/node_modules/**": True, "**/.hg/store/**": True,
        "**/dist/**": True, "**/build/**": True, "**/.next/**": True,
        "**/.nuxt/**": True, "**/coverage/**": True,
        "**/.pnpm-store/**": True, "**/.pnpm-state/**": True,
        "**/__pycache__/**": True, "**/*.pyc": True,
        "**/.pytest_cache/**": True, "**/.mypy_cache/**": True},
    "typescript.preferences.includePackageJsonAutoImports": "auto",
    "typescript.suggest.autoImports": True,
    "python.formatting.provider": "black",
    "python.linting.enabled": True,
    "python.linting.flake8Enabled": True,
}

CURSOR_EXTENSIONS = [
    "ms-python.python", "ms-python.vscode-pylance",
    "ms-python.black-formatter", "ms-python.flake8",
    "dbaeumer.vscode-eslint", "esbenp.prettier-vscode",
    "GitHub.copilot", "GitHub.copilot-chat",
    "ms-vscode.vscode-typescript-next", "ms-vscode.powershell",
    "redhat.vscode-yaml", "ms-azuretools.vscode-docker",
]

OLLAMA_MODELS = ["codellama", "llama2", "mistral", "neural-chat"]
OLLAMA_URL = ("https://github.com/ollama/ollama/releases/latest/"
              "download/OllamaSetup.exe")


def log(msg, level="INFO"):
    print(f"[{level}] {msg}")


def run(cmd, dry, **kw):
    if dry:
        print("[dry-run]", " ".join(str(c) for c in cmd))
        return 0
    return subprocess.run(cmd, **kw).returncode


def optimize_cursor(dry):
    log("Optimizing Cursor AI for advanced development...")
    cfg = Path(os.environ.get("APPDATA", "")) / "Cursor" / "User"
    sp = cfg / "settings.json"
    if dry:
        log(f"[dry-run] write {len(CURSOR_SETTINGS)} settings to {sp}")
    else:
        cfg.mkdir(parents=True, exist_ok=True)
        existing = {}
        if sp.exists():
            try:
                existing = json.loads(sp.read_text(
                    encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                pass
        existing.update(CURSOR_SETTINGS)
        sp.write_text(json.dumps(existing, indent=2),
                      encoding="utf-8")
        log("Cursor AI optimized for AI development", "SUCCESS")
    cursor = shutil.which("cursor") or "cursor"
    for ext in CURSOR_EXTENSIONS:
        if run([cursor, "--install-extension", ext], dry) == 0 \
                and not dry:
            log(f"Installed extension: {ext}", "SUCCESS")


def optimize_copilot(dry):
    log("Optimizing GitHub Copilot...")
    run(["gh", "extension", "install", "github/gh-copilot"], dry)
    run(["gh", "extension", "install", "github/gh-codeql"], dry)


def install_local_ai(dry):
    log("Installing local AI models...")
    if not shutil.which("ollama"):
        log("Installing Ollama...", "INFO")
        if dry:
            log(f"[dry-run] download {OLLAMA_URL}")
        else:
            tmp = Path(tempfile.gettempdir()) / "ollama-installer.exe"
            urllib.request.urlretrieve(OLLAMA_URL, tmp)
            subprocess.run([str(tmp)], check=False)
    for m in OLLAMA_MODELS:
        run(["ollama", "pull", m], dry)


def main():
    ap = argparse.ArgumentParser(description="AI development tools")
    ap.add_argument("--install-all", action="store_true")
    ap.add_argument("--cursor-only", action="store_true")
    ap.add_argument("--copilot-only", action="store_true")
    ap.add_argument("--local-ai-only", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if not (args.cursor_only or args.copilot_only
            or args.local_ai_only):
        args.install_all = True
    if args.install_all or args.cursor_only:
        optimize_cursor(args.dry_run)
    if args.install_all or args.copilot_only:
        optimize_copilot(args.dry_run)
    if args.install_all or args.local_ai_only:
        install_local_ai(args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
