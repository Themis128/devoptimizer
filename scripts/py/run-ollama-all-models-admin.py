"""Port of tools/Variants/RUN-OLLAMA-ALL-MODELS-Admin.bat — positional
prompt -> `tools/run-ollama-all.ps1 -Prompt` via pwsh/powershell.
--dry-run prints; passes through the ps1's exit code.
"""
# REQUIRES: admin
import ctypes
import shutil
import subprocess
import sys
from pathlib import Path

VARIANTS_DIR = Path(__file__).resolve().parents[1].parent / "tools" / "Variants"


def find_tool(name):
    for cand in (VARIANTS_DIR.parent / name,
                 VARIANTS_DIR / name,
                 VARIANTS_DIR.parent / "tools" / name):
        if cand.exists():
            return cand
    return VARIANTS_DIR.parent / "tools" / name


def main():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required",
              file=sys.stderr)
        return 1
    argv = [a for a in sys.argv[1:] if a != "--dry-run"]
    if not argv or argv[0] in ("-help", "--help", "/help"):
        print("Usage: run-ollama-all-models-admin.py <prompt>|"
              "-prompt <prompt>")
        return 0
    prompt = argv[1] if argv[0] == "-prompt" and len(argv) > 1 \
        else argv[0]
    ps = shutil.which("pwsh") or shutil.which("powershell")
    if not ps:
        print("ERROR: Neither pwsh nor powershell found in PATH",
              file=sys.stderr)
        return 1
    flags = (["-NoProfile"] if ps.endswith("pwsh")
             else ["-NoProfile", "-ExecutionPolicy", "Bypass"])
    cmd = [ps, *flags, "-File",
           str(find_tool("run-ollama-all.ps1")),
           "-Prompt", prompt]
    if "--dry-run" in sys.argv:
        print("[dry-run]", " ".join(cmd))
        return 0
    return subprocess.run(cmd).returncode


if __name__ == "__main__":
    sys.exit(main())
