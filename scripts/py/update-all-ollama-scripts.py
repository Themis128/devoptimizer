"""Port of tools/update-all-ollama-scripts.ps1 — rewrite every
ollama-*.bat in tools/'s parent dir to the multi-model helper, with
.backup files and rollback on failure.
"""
# REQUIRES: admin
import ctypes
import re
import shutil
import sys
from pathlib import Path


def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required",
              file=sys.stderr)
        sys.exit(1)


REPLACES = [
    ("🤖 OLLAMA AI SYSTEM ANALYZER",
     "🤖 OLLAMA MULTI-MODEL AI SYSTEM ANALYZER"),
    ("📈 OLLAMA PERFORMANCE SCORER",
     "📈 OLLAMA MULTI-MODEL PERFORMANCE SCORER"),
    ("🧠 OLLAMA INTELLIGENT MONITOR",
     "🧠 OLLAMA MULTI-MODEL INTELLIGENT MONITOR"),
    ("🔧 OLLAMA INTELLIGENT OPTIMIZER",
     "🔧 OLLAMA MULTI-MODEL INTELLIGENT OPTIMIZER"),
    ("🔮 OLLAMA PREDICTIVE MAINTENANCE",
     "🔮 OLLAMA MULTI-MODEL PREDICTIVE MAINTENANCE"),
    ("📝 OLLAMA SCRIPT GENERATOR",
     "📝 OLLAMA MULTI-MODEL SCRIPT GENERATOR"),
    ("Starting comprehensive AI-powered system analysis...",
     "Starting comprehensive AI-powered system analysis using ALL "
     "available Ollama models..."),
    ("Choose scoring mode:",
     "Choose scoring mode (using multi-model consensus analysis):"),
]
HELPER = r'call "%~dp0tools\ollama-batch-helper.bat" -prompt "\1"' \
    r' -output "\2"'
PATTERNS = [
    (r'ollama run qwen2\.5-coder:7b "([^"]*)" > "([^"]*)"', HELPER),
    (r'ollama run qwen2\.5:1\.5b "([^"]*)" > "([^"]*)"', HELPER),
    (r'ollama run [^"]* "([^"]*)" > "([^"]*)"', HELPER),
]


def main():
    _ensure_admin()
    parent = (Path(__file__).resolve().parents[2]
              if "tools" in str(Path(__file__).resolve())
              else Path.cwd())
    files = sorted(parent.glob("ollama-*.bat"))
    if not files:
        print(f"No Ollama batch files found in: {parent}",
              file=sys.stderr)
        return 1
    print(f"Found {len(files)} Ollama batch files:")
    for f in files:
        print(f"  - {f.name}")
    updated = 0
    for f in files:
        print(f"Processing: {f.name}")
        backup = f.with_suffix(f.suffix + ".backup")
        try:
            shutil.copy2(f, backup)
            content = f.read_text(encoding="utf-8", errors="replace")
            for a, b in REPLACES:
                content = content.replace(a, b)
            for pat, rep in PATTERNS:
                content = re.sub(pat, rep, content)
            if not re.search(r"multi-model|Multi-Model|MULTI-MODEL",
                             content):
                content = re.sub(
                    r"(echo Starting.*analysis\.\.\.)",
                    r"\1\necho - Multi-model consensus analysis for "
                    r"enhanced accuracy", content)
            f.write_text(content, encoding="utf-8")
            print("  Updated successfully")
            updated += 1
        except OSError as e:
            print(f"  Update failed: {e}", file=sys.stderr)
            if backup.exists():
                shutil.copy2(backup, f)
    print(f"Updated {updated}/{len(files)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
