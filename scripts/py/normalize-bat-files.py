"""Normalize .bat files (Python port of tools/normalize-bat-files.ps1).

CRLF line endings, @echo off + setlocal + cd /d "%~dp0" headers, Unicode
box-drawing/emoji -> ASCII, trailing-space strip, :checkAdmin helpers for
*-Admin.bat. Backups under the given backup dir. Mutating; --dry-run.
"""

import argparse
import re
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: batch, normalize, maintenance

UNICODE_MAP = {
    "█": "=", "╔": "+", "╗": "+", "╚": "+", "╝": "+", "═": "=", "║": "|",
    "╠": "+", "╣": "+", "╦": "+", "╩": "+", "╬": "+",
    "🚀": "[LAUNCH]", "🤖": "[AI]", "⚡": "[PERF]", "🔧": "[TOOL]",
    "📊": "[STATS]", "🌐": "[NET]", "🔒": "[SEC]", "🎨": "[UI]",
    "🧪": "[TEST]", "⚙️": "[CFG]", "✅": "[OK]", "❌": "[ERR]",
    "⚠️": "[WARN]", "💡": "[TIP]", "🎯": "[TARGET]", "📋": "[LIST]",
    "🔍": "[SEARCH]", "🛠️": "[BUILD]", "📁": "[FOLDER]", "📝": "[NOTE]",
    "🔴": "[RED]", "🟢": "[GREEN]", "🟡": "[YELLOW]", "🔵": "[BLUE]",
    "🟣": "[PURPLE]", "🟠": "[ORANGE]",
}

ADMIN_HELPERS = """

REM ================================================================
REM                    ADMIN PRIVILEGE FUNCTIONS
REM ================================================================

:checkAdmin
set "IS_ADMIN=0"
fsutil dirty query %SystemDrive% >nul 2>&1
if not errorlevel 1 (
    set "IS_ADMIN=1"
) else (
    net session >nul 2>&1
    if not errorlevel 1 set "IS_ADMIN=1"
)
exit /b
"""


def normalize(content: str, file_name: str) -> str:
    content = content.replace("\r\n", "\n").replace("\r", "\n")
    content = "\r\n".join(content.split("\n"))
    content = re.sub(r" +\r\n", "\r\n", content)
    content = content.rstrip() + "\r\n"
    if not content.startswith("@echo off"):
        content = "@echo off\r\n" + content
    if "setlocal EnableExtensions EnableDelayedExpansion" not in content:
        content = content.replace(
            "@echo off\r\n",
            "@echo off\r\nsetlocal EnableExtensions EnableDelayedExpansion\r\n",
            1)
    if 'cd /d "%~dp0"' not in content:
        content = content.replace(
            "setlocal EnableExtensions EnableDelayedExpansion\r\n",
            'setlocal EnableExtensions EnableDelayedExpansion\r\ncd /d "%~dp0"\r\n',
            1)
    for u, a in UNICODE_MAP.items():
        content = content.replace(u, a)
    content = content.replace("tools\\\\", "tools\\")
    if re.search(r"-Admin\.bat$", file_name) and ":checkAdmin" not in content:
        content += ADMIN_HELPERS
    return content


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=r"D:\DevOptimizer")
    parser.add_argument("--backup-dir",
                        default=r"backups\bat-fixes_20251004_103512")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    root = Path(args.root)
    backup_root = Path(args.backup_dir)
    changed = skipped = failed = 0

    for f in root.rglob("*.bat"):
        if str(backup_root) in str(f) or not f.is_file():
            continue
        try:
            content = f.read_text(encoding="utf-8", errors="replace")
            if len(content) < 10:
                skipped += 1
                continue
            new = normalize(content, f.name)
            if new == content:
                skipped += 1
                continue
            changed += 1
            if args.verbose or args.dry_run:
                print(f"{'[dry-run] ' if args.dry_run else ''}normalize: {f}",
                      file=sys.stderr)
            if not args.dry_run:
                rel = f.relative_to(root)
                backup = backup_root / rel
                backup.parent.mkdir(parents=True, exist_ok=True)
                backup.write_bytes(f.read_bytes())
                f.write_text(new, encoding="utf-8", newline="")
        except OSError as e:
            failed += 1
            print(f"FAILED {f}: {e}", file=sys.stderr)

    print(f"normalized={changed} skipped={skipped} failed={failed}",
          file=sys.stderr)


if __name__ == "__main__":
    main()
