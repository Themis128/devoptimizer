"""Cursor AI optimization (Python port of cursor-ai-optimization.ps1).

Python port of cursor-ai-optimization.ps1
Cursor AI optimization: settings profiles, extensions, cache, updates.
"""

import argparse
import asyncio
import ctypes
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command  # noqa: E402

# CATEGORY: ai-ml
# TAGS: cursor, ai, editor, optimization

FONT = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace"

PROFILES: dict[str, dict] = {
    "Performance": {
        "editor.fontSize": 14, "editor.fontFamily": FONT, "editor.minimap.enabled": False,
        "editor.wordWrap": "off", "editor.renderWhitespace": "none",
        "editor.renderControlCharacters": False, "editor.smoothScrolling": False,
        "editor.cursorSmoothCaretAnimation": "off", "workbench.reduceMotion": "on",
        "extensions.autoUpdate": False, "telemetry.telemetryLevel": "off",
        "workbench.enableExperiments": False, "search.searchOnType": False,
        "files.autoSave": "onFocusChange",
        "editor.quickSuggestions": {"other": True, "comments": False, "strings": False},
        "cursor.ai.enabled": True, "cursor.ai.autoComplete": False,
        "cursor.ai.codeGeneration": True, "cursor.ai.contextLimit": 4000,
    },
    "Balanced": {
        "editor.fontSize": 14, "editor.fontFamily": FONT, "editor.fontLigatures": True,
        "editor.minimap.enabled": True, "editor.minimap.maxColumn": 80,
        "editor.wordWrap": "on", "editor.renderWhitespace": "selection",
        "editor.smoothScrolling": True, "editor.cursorSmoothCaretAnimation": "on",
        "workbench.iconTheme": "material-icon-theme", "workbench.colorTheme": "One Dark Pro",
        "extensions.autoUpdate": True, "telemetry.telemetryLevel": "error",
        "files.autoSave": "afterDelay", "files.autoSaveDelay": 1000,
        "cursor.ai.enabled": True, "cursor.ai.autoComplete": True,
        "cursor.ai.codeGeneration": True, "cursor.ai.contextLimit": 8000,
        "cursor.ai.modelSelection": "gpt-4", "cursor.ai.enhancedSuggestions": True,
    },
    "Feature-Rich": {
        "editor.fontSize": 15, "editor.fontFamily": FONT, "editor.fontLigatures": True,
        "editor.bracketPairColorization.enabled": True, "editor.guides.bracketPairs": "active",
        "editor.minimap.enabled": True, "editor.wordWrap": "on",
        "editor.renderWhitespace": "all", "editor.smoothScrolling": True,
        "editor.cursorSmoothCaretAnimation": "on",
        "workbench.iconTheme": "material-icon-theme", "workbench.colorTheme": "One Dark Pro",
        "workbench.tree.renderIndentGuides": "always", "extensions.autoUpdate": True,
        "files.autoSave": "afterDelay", "files.autoSaveDelay": 500,
        "editor.inlineSuggest.enabled": True, "editor.suggest.preview": True,
        "breadcrumbs.enabled": True,
        "cursor.ai.enabled": True, "cursor.ai.autoComplete": True,
        "cursor.ai.codeGeneration": True, "cursor.ai.contextLimit": 16000,
        "cursor.ai.modelSelection": "gpt-4", "cursor.ai.enhancedSuggestions": True,
        "cursor.ai.codeReview": True, "cursor.ai.explanations": True,
    },
    "AI-Focused": {
        "editor.fontSize": 14, "editor.fontFamily": FONT, "editor.fontLigatures": True,
        "editor.minimap.enabled": True, "editor.minimap.renderCharacters": False,
        "editor.wordWrap": "bounded", "editor.wordWrapColumn": 100,
        "editor.rulers": [80, 100], "editor.smoothScrolling": True,
        "workbench.colorTheme": "One Dark Pro", "workbench.iconTheme": "material-icon-theme",
        "files.autoSave": "afterDelay", "files.autoSaveDelay": 1000,
        "editor.formatOnSave": True, "editor.formatOnPaste": True,
        "editor.codeActionsOnSave": {"source.fixAll.eslint": "explicit", "source.organizeImports": "explicit"},
        "cursor.ai.enabled": True, "cursor.ai.autoComplete": True,
        "cursor.ai.codeGeneration": True, "cursor.ai.contextLimit": 20000,
        "cursor.ai.modelSelection": "gpt-4", "cursor.ai.enhancedSuggestions": True,
        "cursor.ai.codeReview": True, "cursor.ai.explanations": True,
        "cursor.ai.refactoring": True, "cursor.ai.documentation": True,
        "cursor.ai.testGeneration": True, "cursor.ai.errorAnalysis": True,
        "cursor.ai.performanceOptimization": True,
        "cursor.chat.enabled": True, "cursor.chat.contextAware": True,
        "cursor.chat.codebaseIndexing": True,
        "cursor.composer.enabled": True, "cursor.composer.autoApply": False,
        "search.useGlobalIgnoreFiles": True, "search.useParentIgnoreFiles": True,
        "files.watcherExclude": {
            "**/.git/objects/**": True, "**/.git/subtree-cache/**": True,
            "**/node_modules/**": True, "**/.next/**": True, "**/.nuxt/**": True,
            "**/dist/**": True, "**/build/**": True, "**/.pnpm-store/**": True,
        },
    },
    "Development": {
        "editor.fontSize": 14, "editor.fontFamily": FONT, "editor.fontLigatures": True,
        "editor.minimap.enabled": True, "editor.wordWrap": "on",
        "editor.bracketPairColorization.enabled": True, "editor.guides.bracketPairs": "active",
        "workbench.colorTheme": "One Dark Pro", "workbench.iconTheme": "material-icon-theme",
        "files.autoSave": "afterDelay", "files.autoSaveDelay": 1000,
        "editor.formatOnSave": True,
        "editor.codeActionsOnSave": {"source.fixAll.eslint": "explicit", "source.organizeImports": "explicit"},
        "git.autoFetch": True, "git.confirmSync": False, "git.enableSmartCommit": True,
        "terminal.integrated.fontSize": 13, "terminal.integrated.fontFamily": "Cascadia Code",
        "terminal.integrated.defaultProfile.windows": "PowerShell",
        "cursor.ai.enabled": True, "cursor.ai.autoComplete": True,
        "cursor.ai.codeGeneration": True, "cursor.ai.contextLimit": 12000,
        "cursor.ai.modelSelection": "gpt-4", "cursor.ai.enhancedSuggestions": True,
        "cursor.ai.codeReview": True,
        "typescript.preferences.includePackageJsonAutoImports": "auto",
        "typescript.suggest.autoImports": True,
        "typescript.updateImportsOnFileMove.enabled": "always",
        "javascript.preferences.includePackageJsonAutoImports": "auto",
        "javascript.suggest.autoImports": True,
        "javascript.updateImportsOnFileMove.enabled": "always",
        "extensions.ignoreRecommendations": False,
        "extensions.showRecommendationsOnlyOnDemand": False,
    },
}

KEYBINDINGS = [
    {"key": "ctrl+shift+i", "command": "cursor.ai.generateCode", "when": "editorTextFocus"},
    {"key": "ctrl+shift+e", "command": "cursor.ai.explainCode", "when": "editorHasSelection"},
    {"key": "ctrl+shift+r", "command": "cursor.ai.refactorCode", "when": "editorHasSelection"},
    {"key": "ctrl+shift+t", "command": "cursor.ai.generateTests", "when": "editorTextFocus"},
    {"key": "ctrl+shift+d", "command": "cursor.ai.generateDocs", "when": "editorTextFocus"},
    {"key": "ctrl+shift+c", "command": "cursor.chat.open"},
    {"key": "ctrl+k ctrl+i", "command": "cursor.composer.open"},
]

ESSENTIAL_EXTENSIONS = [
    "ms-vscode.vscode-typescript-next", "bradlc.vscode-tailwindcss",
    "esbenp.prettier-vscode", "dbaeumer.vscode-eslint", "ms-vscode.vscode-json",
    "PKief.material-icon-theme", "zhuangtongfa.Material-theme",
    "formulahendry.auto-rename-tag", "christian-kohler.path-intellisense",
    "usernamehw.errorlens", "ms-vscode.hexeditor",
]
ADDITIONAL_EXTENSIONS = [
    "yzhang.markdown-all-in-one", "ms-vscode.powershell", "ms-python.python",
    "ms-toolsai.jupyter", "ms-vscode.remote-wsl", "ms-vscode-remote.remote-containers",
    "GitHub.vscode-pull-request-github", "eamodio.gitlens", "ritwickdey.LiveServer",
    "ms-vscode.vscode-docker", "bradlc.vscode-tailwindcss", "Vue.volar",
    "johnsoncodehk.vscode-typescript-vue-plugin",
]


def log(level: str, message: str) -> None:
    print(f"[{level}] {message}")


def _exec_args(name: str, extra: list[str]) -> list[str]:
    full = shutil.which(name)
    argv = [full or name] + extra
    if full and full.lower().endswith((".cmd", ".bat")):
        argv = ["cmd.exe", "/c"] + argv
    return argv


async def cursor_cli(args: list[str], timeout: int = 120) -> tuple[int, str]:
    if not shutil.which("cursor"):
        return 127, "cursor not on PATH"
    result = await run_command(_exec_args("cursor", args), timeout=timeout)
    return result.returncode, (result.stdout or "") + (result.stderr or "")


def ram_gb() -> float:
    try:

        class MEMORYSTATUSEX(ctypes.Structure):
            _fields_ = [
                ("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
            ]

        stat = MEMORYSTATUSEX()
        stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
        if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
            raise OSError("GlobalMemoryStatusEx failed")
        return round(stat.ullTotalPhys / 1073741824, 2)
    except (OSError, AttributeError):
        return 16.0


def get_info() -> dict:
    log("INFO", "Gathering Cursor AI installation information...")
    info: dict = {"installed": False, "version": None, "install_path": None,
                  "config_path": None, "extensions_path": None, "user_data_path": None,
                  "workspace_path": None, "settings": {}}
    exe = shutil.which("cursor")
    if exe:
        info["installed"] = True
        info["install_path"] = str(Path(exe).parent)
    else:
        for candidate in (
            os.path.expandvars(r"%LOCALAPPDATA%\Programs\cursor\cursor.exe"),
            os.path.expandvars(r"%ProgramFiles%\Cursor\cursor.exe"),
        ):
            if Path(candidate).exists():
                info["installed"] = True
                info["install_path"] = str(Path(candidate).parent)
                break

    if info["installed"]:
        info["config_path"] = os.path.expandvars(r"%APPDATA%\Cursor\User")
        info["extensions_path"] = os.path.expandvars(r"%USERPROFILE%\.cursor\extensions")
        info["user_data_path"] = os.path.expandvars(r"%APPDATA%\Cursor")
        info["workspace_path"] = os.path.expandvars(r"%APPDATA%\Cursor\User\workspaceStorage")
        settings_file = Path(info["config_path"]) / "settings.json"
        if settings_file.exists():
            try:
                info["settings"] = json.loads(settings_file.read_text(encoding="utf-8-sig"))
            except ValueError:
                log("WARN", "Could not parse existing settings.json")
        log("SUCCESS", f"Cursor AI found: Version {info['version'] or 'unknown'}")
        log("INFO", f"Config Path: {info['config_path']}")
    else:
        log("WARN", "Cursor AI not found on this system")
    return info


async def apply_settings(profile: str, dry_run: bool) -> bool:
    log("INFO", f"Optimizing Cursor AI settings for profile: {profile}")
    info = get_info()
    if not info["installed"]:
        log("ERROR", "Cursor AI is not installed. Cannot optimize settings.")
        return False
    Path(info["config_path"]).mkdir(parents=True, exist_ok=True)

    settings = dict(PROFILES[profile])
    final = dict(info["settings"]) if info["settings"] else {}
    final.update(settings)
    settings_path = Path(info["config_path"]) / "settings.json"
    keybindings_path = Path(info["config_path"]) / "keybindings.json"

    if dry_run:
        log("INFO", f"[DRY RUN] Would write {len(settings)} settings to {settings_path}")
        log("INFO", f"[DRY RUN] Would write {len(KEYBINDINGS)} keybindings to {keybindings_path}")
        return True

    settings_path.write_text(json.dumps(final, indent=2), encoding="utf-8")
    log("SUCCESS", f"Cursor AI settings optimized for {profile} profile")
    keybindings_path.write_text(json.dumps(KEYBINDINGS, indent=2), encoding="utf-8")
    log("SUCCESS", "AI-optimized keybindings configured")
    return True


async def install_extensions(essential_only: bool, dry_run: bool) -> int:
    log("INFO", "Installing Cursor AI extensions...")
    info = get_info()
    if not info["installed"]:
        log("ERROR", "Cursor AI is not installed. Cannot install extensions.")
        return 0
    extensions = list(ESSENTIAL_EXTENSIONS)
    if not essential_only:
        extensions += ADDITIONAL_EXTENSIONS
    installed = failed = 0
    for ext in extensions:
        if dry_run:
            log("INFO", f"[DRY RUN] Would install extension: {ext}")
            installed += 1
            continue
        log("INFO", f"Installing extension: {ext}")
        code, _out = await cursor_cli(["--install-extension", ext, "--force"])
        if code == 0:
            log("SUCCESS", f"Successfully installed: {ext}")
            installed += 1
        else:
            log("WARN", f"Failed to install: {ext}")
            failed += 1
    log("SUCCESS", f"Extension installation completed: {installed} installed, {failed} failed")
    return installed


def dir_size(path: Path) -> int:
    try:
        if not path.exists():
            return 0
    except OSError:
        return 0
    total = 0
    for item in path.rglob("*"):
        try:
            if item.is_file():
                total += item.stat().st_size
        except OSError:
            continue
    return total


def clear_contents(path: Path) -> int:
    import shutil as sh

    freed = 0
    try:
        for item in path.iterdir():
            try:
                if item.is_dir():
                    size = dir_size(item)
                    sh.rmtree(item, ignore_errors=True)
                else:
                    size = item.stat().st_size
                    item.unlink()
                freed += size
            except OSError:
                continue
    except OSError:
        pass
    return freed


def clear_cache(dry_run: bool) -> int:
    log("INFO", "Clearing Cursor AI cache and temporary files...")
    info = get_info()
    if not info["installed"]:
        log("ERROR", "Cursor AI is not installed. Cannot clear cache.")
        return 0
    total = 0
    tmp = Path(tempfile.gettempdir())
    targets = [
        Path(info["user_data_path"]) / "logs",
        Path(info["user_data_path"]) / "CachedExtensions",
        Path(info["user_data_path"]) / "CachedData",
        Path(info["workspace_path"]),
        Path(os.path.expandvars(r"%APPDATA%\Cursor\User\workspaceStorage")),
        Path(os.path.expandvars(r"%APPDATA%\Cursor\User\History")),
    ]
    tmp_cursors = sorted(tmp.glob("cursor-*")) if tmp.exists() else []
    for target in targets + tmp_cursors:
        if not target.exists():
            continue
        size_before = dir_size(target)
        if dry_run:
            log("INFO", f"[DRY RUN] Would clear {target} ({round(size_before / 1048576, 2)} MB)")
            total += size_before
            continue
        freed = clear_contents(target)
        total += freed
        if freed > 0:
            log("SUCCESS", f"Cleaned cache: {round(freed / 1048576, 2)} MB from {target}")
    log("SUCCESS", f"Cursor AI cache cleanup completed: {round(total / 1048576, 2)} MB freed")
    return total


async def update_cursor() -> bool:
    log("INFO", "Checking for Cursor AI updates...")
    info = get_info()
    if not info["installed"]:
        log("ERROR", "Cursor AI is not installed. Cannot check for updates.")
        return False
    code, _out = await cursor_cli(["--update"], timeout=300)
    if code == 0:
        log("SUCCESS", "Cursor AI update initiated successfully")
        return True
    log("INFO", "Cursor AI update command failed or no updates available")
    log("INFO", "You can manually check for updates in Cursor: Help > Check for Updates")
    return False


async def complete(profile: str, dry_run: bool) -> bool:
    log("INFO", "Running complete Cursor AI optimization...")
    ram = ram_gb()
    if profile == "AI-Focused" and ram < 16:
        log("INFO", f"System has limited RAM ({ram} GB), adjusting to Balanced profile")
        profile = "Balanced"
    elif profile == "Feature-Rich" and ram < 8:
        log("INFO", f"System has limited RAM ({ram} GB), adjusting to Performance profile")
        profile = "Performance"
    clear_cache(dry_run)
    await update_cursor()
    settings_ok = await apply_settings(profile, dry_run)
    ext_count = await install_extensions(essential_only=False, dry_run=dry_run)
    if settings_ok and ext_count > 0:
        log("SUCCESS", "Complete Cursor AI optimization finished successfully!")
        log("INFO", f"Profile applied: {profile}")
        log("INFO", f"Extensions installed: {ext_count}")
        log("WARN", "RECOMMENDATION: Restart Cursor AI to apply all changes")
        return True
    log("WARN", "Cursor AI optimization completed with some issues")
    return False


async def main_async() -> int:
    parser = argparse.ArgumentParser(description="Cursor AI optimization")
    parser.add_argument("action", choices=["info", "settings", "extensions", "cache", "update", "complete"],
                        nargs="?", default="info",
                        help="info (read-only) is the default; mutating actions are explicit")
    parser.add_argument("--profile", default="AI-Focused",
                        choices=sorted(PROFILES.keys()), help="Settings profile")
    parser.add_argument("--essential-only", action="store_true", help="extensions: only essential set")
    parser.add_argument("--dry-run", action="store_true", help="Preview without changing")
    parser.add_argument("--json", action="store_true", help="JSON output (info)")
    args = parser.parse_args()

    if not re.fullmatch(r"(Performance|Balanced|Feature-Rich|AI-Focused|Development)", args.profile or "AI-Focused"):
        log("ERROR", f"Unknown profile: {args.profile}")
        return 1

    if args.action == "info":
        info = get_info()
        print(json.dumps(info, indent=2) if args.json else json.dumps(info))
        return 0
    if args.action == "settings":
        return 0 if await apply_settings(args.profile, args.dry_run) else 1
    if args.action == "extensions":
        n = await install_extensions(args.essential_only, args.dry_run)
        return 0 if n > 0 else 1
    if args.action == "cache":
        clear_cache(args.dry_run)
        return 0
    if args.action == "update":
        return 0 if await update_cursor() else 1
    return 0 if await complete(args.profile, args.dry_run) else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main_async()))
