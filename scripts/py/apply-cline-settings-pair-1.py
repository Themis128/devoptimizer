"""Port of scripts/apply-cline-settings-pair.ps1 — merge NVIDIA PAIR
(local router on 127.0.0.1:11434, OpenAI-shaped) Cline settings into
VS Code settings.json, preserving existing keys. Timestamped backup
first. --dry-run prints the merged keys without writing.
"""
import argparse
import datetime
import json
import os
import shutil
import sys
from pathlib import Path

# CATEGORY: ai-ml
# TAGS: cline, vscode, settings

CLINE_SETTINGS = {
    "cline.apiProvider": "openai",
    "cline.openAiBaseUrl": "http://127.0.0.1:11434/v1",
    "cline.openAiModelId": "qwen2.5-coder:7b",
    "cline.contextWindow": 32768,
    "cline.maxTokens": 8192,
    "cline.autoApproveEnabled": False,
    "cline.diffEnabled": True,
    "cline.showRooCodeIgnoreFiles": True,
    "cline.experiments": {"usePlanActSeparateModels": True},
}


def main():
    ap = argparse.ArgumentParser(
        description="Merge NVIDIA PAIR Cline settings into VS Code")
    ap.add_argument("--settings",
                    help="settings.json path (default "
                         "%APPDATA%/Code/User/settings.json)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    settings_path = Path(args.settings) if args.settings else Path(
        os.environ.get("APPDATA", "")) / "Code" / "User" / \
        "settings.json"
    if not settings_path.exists() and not args.dry_run:
        print(f"settings.json not found at {settings_path} - "
              "nothing to merge.", file=sys.stderr)
        return 1

    data = {}
    if settings_path.exists():
        try:
            data = json.loads(
                settings_path.read_text(encoding="utf-8-sig"))
        except json.JSONDecodeError as e:
            print(f"settings.json is not valid JSON: {e}",
                  file=sys.stderr)
            return 1

    if settings_path.exists():
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = settings_path.with_name(
            f"{settings_path.name}.backup-{stamp}")
        if args.dry_run:
            print(f"[dry-run] backup -> {backup}")
        else:
            shutil.copy2(settings_path, backup)
            print(f"Backup created: {backup}")

    for k, v in CLINE_SETTINGS.items():
        data[k] = v
        print(f"  Set: {k} = {v}")

    if args.dry_run:
        print("[dry-run] would write merged settings")
        return 0
    settings_path.write_text(json.dumps(data, indent=4) + "\n",
                             encoding="utf-8")
    print("\nCline now points at NVIDIA PAIR: "
          "http://127.0.0.1:11434/v1")
    print("Restart VS Code (or Reload Window) for changes to take "
          "effect.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
