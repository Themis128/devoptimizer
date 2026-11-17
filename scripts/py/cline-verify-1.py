"""Verify Cline extension config & health (Python port of cline-verify.ps1).

Read-only: storage paths + sizes, VS Code settings keys (secrets masked),
.clineignore/.clinerules presence, and the NIM free-tier checklist.
"""

import argparse
import json
import os
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: cline, vscode, verify

STORAGE_DIRS = [
    r"Code\User\globalStorage\saoudrizwan.claude-dev",
    r"Code - Insiders\User\globalStorage\saoudrizwan.claude-dev",
]
SETTINGS = [
    r"Code\User\settings.json",
    r"Code - Insiders\User\settings.json",
]
PROJECT_ROOTS = [
    r"D:\DevOptimizer", r"D:\DevOptimizer\scripts",
    os.path.join(os.environ.get("USERPROFILE", ""), "DevOptimizer"),
    os.path.join(os.environ.get("USERPROFILE", ""), "projects"),
    os.path.join(os.environ.get("USERPROFILE", ""), "code"),
    "/home/tbaltzakis/ComfyUI-Docker/cu130-slim",
    "/mnt/d/DevOptimizer", "/mnt/d/DevOptimizer/scripts",
]
CHECKS = [
    ("Plan/Act separate models enabled", "Use ultra for Plan, nano for Act", True),
    ("Reasoning effort = medium", "Not high - saves approx 40% tokens", True),
    ("Prompt caching enabled", "Reuses system prompts on follow-ups", True),
    (".clineignore in project root", "Excludes node_modules, build, media, etc.", True),
    ("Custom instructions configured", "Guides Cline behavior", False),
    ("Model: nemotron-3-ultra-550b (Plan)", "Strong reasoning for architecture", True),
    ("Model: nemotron-3-nano-30b (Act)", "Cheaper, faster for implementation", True),
    ("Context window <= 128K", "Matches NIM free tier limits", True),
    ("Max tokens <= 8192", "Prevents runaway generations", True),
]


def dir_mb(path: Path) -> float:
    total = sum(p.stat().st_size for p in path.rglob("*")
                if p.is_file())
    return round(total / 1_048_576, 2)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    appdata = os.environ.get("APPDATA", "")
    report: dict = {"storage": [], "settings": {}, "clineignore": [],
                    "instructions": []}

    print("\n=== Cline Extension Verification ===", file=sys.stderr)

    for rel in STORAGE_DIRS:
        p = Path(appdata) / rel
        if p.exists():
            entry = {"path": str(p), "sizeMB": dir_mb(p),
                     "sub": {d.name: dir_mb(d) for d in p.iterdir() if d.is_dir()}}
            report["storage"].append(entry)
            print(f"  OK {p} ({entry['sizeMB']} MB)", file=sys.stderr)
    if not report["storage"]:
        print("  No Cline storage found", file=sys.stderr)

    for rel in SETTINGS:
        p = Path(appdata) / rel
        if not p.exists():
            continue
        try:
            settings = json.loads(p.read_text(encoding="utf-8-sig"))
        except json.JSONDecodeError:
            continue
        cline = {k: ("***HIDDEN***" if "key" in k.lower() else v)
                 for k, v in settings.items() if k.startswith("cline.")}
        if cline:
            report["settings"][str(p)] = cline
            print(f"  {p}: {len(cline)} cline keys", file=sys.stderr)
        else:
            print(f"  No Cline settings in {p}", file=sys.stderr)

    for root in PROJECT_ROOTS:
        ig = Path(root) / ".clineignore"
        if ig.exists():
            report["clineignore"].append(
                {"path": str(ig), "lines": len(ig.read_text(errors="replace").splitlines())})
        for f in (".clinerules", ".cline-instructions.md", "CLINE_INSTRUCTIONS.md"):
            p = Path(root) / f
            if p.exists():
                report["instructions"].append(str(p))

    report["checklist"] = [{"name": n, "desc": d, "critical": c}
                           for n, d, c in CHECKS]

    if args.json:
        print(json.dumps(report, indent=2))
        return

    for ig in report["clineignore"]:
        print(f"  OK {ig['path']} ({ig['lines']} lines)", file=sys.stderr)
    for p in report["instructions"]:
        print(f"  OK {p}", file=sys.stderr)
    print("\nNVIDIA NIM Free Tier Optimization Checklist:", file=sys.stderr)
    for n, d, c in CHECKS:
        print(f"  {'[CRITICAL]' if c else '[OPTIONAL]'} {n} — {d}", file=sys.stderr)
    print("=== Verification Complete ===", file=sys.stderr)


if __name__ == "__main__":
    main()
