"""Port of scripts/Cursor-AI-Module.ps1 — Cursor AI module:
--module-operation configure|keybindings|extensions|test|backup|
restore|getconfig. Writes/merges APPDATA Cursor User settings.json
(38-key base + profile overrides), keybindings.json (17 entries),
installs 14 extensions via `cursor`. --profile overrides base.
--dry-run prints actions.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

# CATEGORY: ai-ml
# TAGS: cursor, ai, config

BASE_CONFIG = {'cursor.ai.enableCodeGeneration': True, 'cursor.ai.enableInlineCompletion': True, 'cursor.ai.enableSmartRename': True, 'cursor.ai.enableContextualSuggestions': True, 'cursor.ai.enableMultiFileContext': True, 'cursor.ai.enableSemanticSearch': True, 'cursor.ai.enableAdvancedRefactoring': True, 'cursor.ai.enableErrorAnalysis': True, 'github.copilot.enable': True, 'github.copilot.advanced.editorPreviewFeatures': True, 'github.copilot.advanced.chat.agent': True, 'github.copilot.chat.agent.runTasks': True, 'github.copilot.chat.agent.available': True, 'github.copilot.chat.agent.editsEnabled': True, 'editor.suggestSelection': 'first', 'editor.tabCompletion': 'on', 'editor.wordBasedSuggestions': 'matchingDocuments', 'editor.suggest.insertMode': 'replace', 'editor.suggest.preview': True, 'editor.suggest.showInlineDetails': True, 'editor.inlineSuggest.enabled': True, 'editor.inlineSuggest.showToolbar': 'always', 'editor.acceptSuggestionOnCommitCharacter': True, 'editor.acceptSuggestionOnEnter': 'smart', 'files.autoSave': 'afterDelay', 'files.autoSaveDelay': 1000, 'files.trimTrailingWhitespace': True, 'files.insertFinalNewline': True, 'files.trimFinalNewlines': True, 'workbench.colorTheme': 'One Dark Modern', 'workbench.iconTheme': 'material-icon-theme', 'workbench.editor.enablePreview': False, 'workbench.editor.enablePreviewFromQuickOpen': False, 'update.releaseTrack': 'prerelease', 'extensions.autoCheckUpdates': True, 'extensions.autoUpdate': 'onlyEnabledExtensions', 'telemetry.telemetryLevel': 'error', 'security.workspace.trust.enabled': True}
PROFILES = {'AI-Focused': {'cursor.ai.maxContextLines': 20000, 'cursor.composer.shouldChimeAfterChatFinishes': True, 'cursor.composer.enableAdvancedMode': True, 'cursor.composer.enableMultiFileEdits': True, 'cursor.composer.enableContextualAwareness': True, 'cursor.composer.maxTokens': 32000, 'cursor.composer.temperature': 0.1, 'cursor.composer.enableCodeReview': True, 'typescript.tsserver.maxTsServerMemory': 6144, 'github.copilot.chat.logging.level': 'INFO', 'github.copilot.logging.level': 'INFO', 'github.copilot.advanced.length': 1000, 'github.copilot.advanced.top_p': 0.1, 'github.copilot.advanced.temperature': 0.1}, 'Development': {'cursor.ai.maxContextLines': 10000, 'typescript.tsserver.maxTsServerMemory': 4096, 'editor.minimap.enabled': True, 'editor.renderWhitespace': 'boundary', 'workbench.editor.limit.enabled': True, 'workbench.editor.limit.value': 15}, 'Performance': {'cursor.ai.maxContextLines': 5000, 'typescript.tsserver.maxTsServerMemory': 2048, 'editor.minimap.enabled': False, 'editor.renderWhitespace': 'none', 'workbench.editor.enablePreview': True, 'extensions.autoUpdate': False}, 'Balanced': {'cursor.ai.maxContextLines': 15000, 'typescript.tsserver.maxTsServerMemory': 4096, 'cursor.composer.maxTokens': 16000}, 'Feature-Rich': {'cursor.ai.maxContextLines': 25000, 'cursor.composer.maxTokens': 50000, 'typescript.tsserver.maxTsServerMemory': 8192, 'editor.minimap.enabled': True, 'editor.bracketPairColorization.enabled': True, 'workbench.editor.decorations.colors': True, 'workbench.editor.decorations.badges': True}}
KEYBINDINGS = [{'key': 'ctrl+i', 'command': 'composerMode.agent', 'when': 'editorTextFocus'}, {'key': 'ctrl+e', 'command': 'composerMode.background', 'when': 'editorTextFocus'}, {'key': 'ctrl+shift+i', 'command': 'cursor.composer.showComposer'}, {'key': 'ctrl+alt+i', 'command': 'cursor.composer.toggleMode'}, {'key': 'ctrl+j', 'command': 'cursor.ai.generateCode'}, {'key': 'ctrl+shift+j', 'command': 'cursor.ai.generateFunction'}, {'key': 'ctrl+alt+j', 'command': 'cursor.ai.generateComment'}, {'key': 'ctrl+shift+alt+j', 'command': 'cursor.ai.generateDocumentation'}, {'key': 'ctrl+r', 'command': 'cursor.ai.refactor'}, {'key': 'ctrl+shift+r', 'command': 'cursor.ai.smartRename'}, {'key': 'ctrl+alt+r', 'command': 'cursor.ai.optimizeCode'}, {'key': 'tab', 'command': 'editor.action.inlineSuggest.commit', 'when': 'editorTextFocus'}, {'key': 'ctrl+right', 'command': 'editor.action.inlineSuggest.acceptNextWord', 'when': 'editorTextFocus'}, {'key': 'alt+right', 'command': 'editor.action.inlineSuggest.acceptNextLine', 'when': 'editorTextFocus'}, {'key': 'escape', 'command': 'editor.action.inlineSuggest.hide', 'when': 'editorTextFocus'}, {'key': 'ctrl+k ctrl+f', 'command': 'editor.action.formatDocument'}, {'key': 'alt+z', 'command': 'editor.action.toggleWordWrap'}]
EXTENSIONS = ['ms-vscode.vscode-typescript-next', 'esbenp.prettier-vscode', 'dbaeumer.vscode-eslint', 'eamodio.gitlens', 'usernamehw.errorlens', 'bradlc.vscode-tailwindcss', 'vue.volar', 'ms-vscode.powershell', 'ms-azuretools.vscode-docker', 'christian-kohler.path-intellisense', 'pkief.material-icon-theme', 'zhuangtongfa.material-theme', 'ms-toolsai.jupyter', 'ms-python.python']
CURSOR_USER = Path(os.environ.get("APPDATA", "")) / "Cursor" / "User"


def status(msg, level="INFO"):
    print(f"[{level}] {msg}")


def _write_json(path, data, dry):
    if dry:
        status(f"[dry-run] write {path} ({len(data)} keys)")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def apply_config(profile, dry):
    cfg = dict(BASE_CONFIG)
    if profile and profile in PROFILES:
        cfg.update(PROFILES[profile])
        status(f"Applying profile: {profile}")
    _write_json(CURSOR_USER / "settings.json", cfg, dry)


def apply_keybindings(dry):
    _write_json(CURSOR_USER / "keybindings.json", KEYBINDINGS, dry)


def install_extensions(dry):
    for ext in EXTENSIONS:
        if dry:
            status(f"[dry-run] cursor --install-extension {ext}")
        else:
            subprocess.run(["cursor", "--install-extension", ext],
                           capture_output=True)


def backup(dry):
    src = CURSOR_USER / "settings.json"
    dst = CURSOR_USER / f"settings-backup-{time.strftime('%Y%m%d-%H%M%S')}.json"
    status(f"Backing up {src} -> {dst}")
    if not dry and src.exists():
        shutil.copy2(src, dst)


def restore(dry):
    backups = sorted(CURSOR_USER.glob("settings-backup-*.json"))
    if not backups:
        status("No backups found", "WARNING")
        return 1
    status(f"Restoring {backups[-1]} -> settings.json")
    if not dry:
        shutil.copy2(backups[-1], CURSOR_USER / "settings.json")
    return 0


def test_module():
    ok = True
    checks = [
        ("settings.json exists",
         (CURSOR_USER / "settings.json").exists()),
        ("keybindings.json exists",
         (CURSOR_USER / "keybindings.json").exists()),
        ("cursor CLI on PATH", shutil.which("cursor") is not None),
    ]
    for name, passed in checks:
        status(("PASS " if passed else "FAIL ") + name,
               "SUCCESS" if passed else "ERROR")
        ok = ok and passed
    return 0 if ok else 1


def getconfig():
    src = CURSOR_USER / "settings.json"
    if not src.exists():
        status("No settings.json", "WARNING")
        return 1
    print(src.read_text(encoding="utf-8"))
    return 0


def main():
    ap = argparse.ArgumentParser(description="Cursor AI module")
    ap.add_argument("--module-operation", default="configure",
                    choices=["configure", "keybindings",
                             "extensions", "test", "backup",
                             "restore", "getconfig"])
    ap.add_argument("--profile", default="")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    op = args.module_operation
    if op == "configure":
        apply_config(args.profile, args.dry_run)
    elif op == "keybindings":
        apply_keybindings(args.dry_run)
    elif op == "extensions":
        install_extensions(args.dry_run)
    elif op == "test":
        return test_module()
    elif op == "backup":
        backup(args.dry_run)
    elif op == "restore":
        return restore(args.dry_run)
    elif op == "getconfig":
        return getconfig()
    return 0


if __name__ == "__main__":
    sys.exit(main())
