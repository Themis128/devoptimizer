"""Apply optimal Cline settings for NVIDIA NIM free tier (port of apply-cline-settings.ps1).

Merges the recommended Cline config into VS Code settings.json after a
timestamped backup. Mutating; --dry-run shows the merged diff.
"""

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path

# CATEGORY: utilities
# TAGS: vscode, cline, settings, nvidia

CLINE_SETTINGS = {
    "cline.apiProvider": "openai",
    "cline.openAiBaseUrl": "https://integrate.api.nvidia.com/v1",
    "cline.openAiModelId": "nvidia/nemotron-3-ultra-550b-a55b",
    "cline.usePlanActSeparateModels": True,
    "cline.planModeModelId": "nvidia/nemotron-3-ultra-550b-a55b",
    "cline.actModeModelId": "nvidia/nemotron-3-nano-30b-a3b-reasoning",
    "cline.reasoningEffort": "medium",
    "cline.promptCachingEnabled": True,
    "cline.customHeaders": [],
    "cline.useAzureOpenAI": False,
    "cline.azureApiVersion": "",
    "cline.useAzureIdentityAuth": False,
    "cline.contextWindow": 128000,
    "cline.maxTokens": 8192,
    "cline.autoApproveEnabled": False,
    "cline.diffEnabled": True,
    "cline.showRooCodeIgnoreFiles": True,
    "cline.experiments": {"usePlanActSeparateModels": True},
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--settings", default=None,
                        help="Override settings.json path")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true",
                        help="Emit the applied keys as JSON")
    args = parser.parse_args()

    settings_path = Path(args.settings) if args.settings else Path(
        os.environ.get("APPDATA", "")) / "Code" / "User" / "settings.json"
    if not settings_path.exists():
        print(f"settings.json not found at {settings_path}", file=sys.stderr)
        sys.exit(1)

    current = json.loads(settings_path.read_text(encoding="utf-8-sig"))
    applied = {k: v for k, v in CLINE_SETTINGS.items() if current.get(k) != v}

    if args.json:
        print(json.dumps({"settings": str(settings_path), "applied": applied}))
        if args.dry_run:
            return

    if args.dry_run:
        print(f"[dry-run] would merge {len(applied)} keys into {settings_path}")
        for k in applied:
            print(f"  {k}")
        return

    backup = settings_path.with_name(
        f"{settings_path.name}.backup-{time.strftime('%Y%m%d-%H%M%S')}")
    shutil.copy2(settings_path, backup)
    print(f"Backup created: {backup}", file=sys.stderr)

    current.update(CLINE_SETTINGS)
    settings_path.write_text(
        json.dumps(current, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8")
    for k in CLINE_SETTINGS:
        print(f"  Set: {k}", file=sys.stderr)
    print("Settings applied. Set cline.openAiApiKey manually in VS Code.",
          file=sys.stderr)


if __name__ == "__main__":
    main()
