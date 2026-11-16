"""Port of tools/update-ollama-scripts.bat — rewrite every
ollama-*.bat in tools/'s parent dir to route through
tools\\ollama-batch-helper.bat with .backup files. Prints a summary;
pauses when run interactively.
"""
import re
import shutil
import sys
from pathlib import Path

HEADER_REPL = {
    "echo            OLLAMA":
        "echo            OLLAMA MULTI-MODEL SYSTEM",
    "echo         OLLAMA":
        "echo         OLLAMA MULTI-MODEL PERFORMANCE SCORER",
    "echo  OLLAMA":
        "echo  OLLAMA MULTI-MODEL INTELLIGENT MONITOR",
}
STRIPS = ["ollama run ", "7b ", "1.5b ", "coder: ", "qwen2.5 ",
          "qwen "]


def _extract(line):
    """Mimic the bat's token stripping to get prompt + output file."""
    s = line
    for t in STRIPS:
        if t in s:
            s = s.split(t, 1)[1]
    s = s.replace(" > ", " ").replace('>"', " ").replace('"', " ")
    toks = s.split()
    prompt = toks[0] if toks else ""
    out = toks[1] if len(toks) > 1 else ""
    return prompt, out


def rewrite(content):
    out = ["@echo off",
           "setlocal EnableExtensions EnableDelayedExpansion",
           "",
           ":: ==================================================",
           "::              UPDATED OLLAMA SCRIPT - MULTI-MODEL"
           " SYSTEM",
           ":: =================================================="]
    for line in content.splitlines():
        if "ollama run" in line.lower():
            prompt, out_f = _extract(line)
            out.append(
                'call "%~dp0tools\\ollama-batch-helper.bat"'
                f' -prompt "{prompt}" -output "{out_f}"')
        elif line.strip() in HEADER_REPL:
            out.append(HEADER_REPL[line.strip()])
        elif re.match(r"^echo\s+OLLAMA", line):
            out.append(line + " MULTI-MODEL")
        else:
            out.append(line)
    return "\n".join(out) + "\n"


def main():
    parent = Path(__file__).resolve().parents[2]
    files = sorted(parent.glob("ollama-*.bat"))
    print("=" * 60)
    print("           UPDATING OLLAMA SCRIPTS TO MULTI-MODEL SYSTEM")
    print("=" * 60 + "\n")
    updated = 0
    for f in files:
        print(f"Processing: {f.name}")
        backup = f.with_suffix(f.suffix + ".backup")
        try:
            shutil.copy2(f, backup)
            content = f.read_text(encoding="utf-8", errors="replace")
            f.write_text(rewrite(content), encoding="utf-8")
            print("   Updated successfully")
            updated += 1
        except OSError as e:
            print(f"   Update failed ({e}), restoring backup")
            if backup.exists():
                shutil.copy2(backup, f)
        print()
    print("=" * 60)
    print("                   UPDATE SUMMARY")
    print("=" * 60)
    print(f"\nTotal scripts found: {len(files)}")
    print(f"Successfully updated: {updated}")
    print(f"Failed updates: {len(files) - updated}")
    print("\nBackup files created: *.backup\n")
    if updated:
        print(" Multi-model system integration completed!\n")
        print("The following scripts now use ALL available Ollama"
              " models:")
        for f in files:
            if f.with_suffix(f.suffix + ".backup").exists():
                print(f"  - {f.name}")
        print("\nNext steps:")
        print("1. Test the updated scripts")
        print("2. Delete .backup files when satisfied")
        print("3. Enjoy enhanced multi-model analysis!")
    else:
        print(" No scripts were updated. Please check for errors.")
    if sys.stdin.isatty():
        input("\nPress Enter to exit...")
    return 0


if __name__ == "__main__":
    sys.exit(main())
