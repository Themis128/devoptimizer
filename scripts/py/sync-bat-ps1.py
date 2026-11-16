"""Generate .bat launchers for every .ps1 (Python port of sync-bat-ps1.ps1).

Walks the DevOptimizer root for *.ps1 (excluding backups/History/Temp/
node_modules) and writes a DEVOPT_HOME-aware .bat shim per script into
the portable folder. Mutating (writes launchers); --dry-run previews.
"""

import argparse
from pathlib import Path

# CATEGORY: utilities
# TAGS: sync, launcher, portable

EXCLUDE_PARTS = {"backups", "History", "Temp", "node_modules"}

BAT_TEMPLATE = """@echo off
setlocal EnableExtensions
if defined DEVOPT_HOME goto rootReady
set "DEVOPT_HOME={root}"
:rootReady
set "TARGET_PS1=%DEVOPT_HOME%\\{relative}"
if not exist "%TARGET_PS1%" (
    echo [ERROR] PowerShell script not found: %TARGET_PS1%
    exit /b 1
)
where pwsh >nul 2>nul
if %errorlevel% EQU 0 (
    set "PS_CMD=pwsh"
) else (
    set "PS_CMD=powershell"
)
%PS_CMD% -NoProfile -ExecutionPolicy Bypass -File "%TARGET_PS1%" %*
endlocal
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=r"D:\DevOptimizer")
    parser.add_argument("--output-folder", default=r"D:\DevOptimizer\portable")
    parser.add_argument("--dry-run", action="store_true",
                        help="Count launchers without writing them")
    args = parser.parse_args()

    root = Path(args.root)
    if not root.exists():
        print(f"DevOptimizer root '{root}' not found.")
        raise SystemExit(1)

    out_dir = Path(args.output_folder)
    if not args.dry_run:
        out_dir.mkdir(parents=True, exist_ok=True)

    generated = 0
    for ps1 in root.rglob("*.ps1"):
        if EXCLUDE_PARTS & set(ps1.parts):
            continue
        relative = ps1.relative_to(root)
        content = BAT_TEMPLATE.format(root=args.root, relative=relative)
        if not args.dry_run:
            (out_dir / (ps1.stem + ".bat")).write_bytes(
                content.replace("\n", "\r\n").encode("ascii", errors="replace"))
        generated += 1

    verb = "Would generate" if args.dry_run else "Generated or refreshed"
    print(f"{verb} {generated} launcher(s) in {out_dir}")


if __name__ == "__main__":
    main()
