"""Create Admin + NoAdmin variants of .bat scripts (port of simple-dual-version-creator.ps1).

Pure-Python port: inserts an admin check / no-admin notice after the first
`echo ... ===` banner line past line 3, retitles, appends :checkAdmin.
Mutating; --force overwrites, --dry-run lists candidates.
"""

import argparse
import fnmatch
import re
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: batch, generator, admin

ADMIN_CHECK = """
:: Check for admin privileges
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
    echo.
    echo [ERROR] This script requires Administrator privileges.
    echo Please run this script as Administrator.
    echo.
    pause
    exit /b 1
) else (
    echo [INFO] Running with Administrator privileges
)
"""

ADMIN_FUNCS = """

:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
"""

NOADMIN_NOTICE = """
:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited
"""


def insert_after_banner(content: str, block: str) -> str:
    lines = content.split("\n")
    for i, line in enumerate(lines):
        if i > 3 and re.search(r"echo.*===", line):
            lines[i:i + 1] = [line, "", *block.strip("\n").split("\n"), ""]
            return "\n".join(lines)
    return content


def retitle(content: str, suffix: str) -> str:
    return re.sub(r"title ([^\r\n-]+)", lambda m: f"title {m.group(1)} - {suffix}",
                  content, count=1)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--pattern", default="*.bat")
    parser.add_argument("--dir", default=".")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    scripts = [p for p in Path(args.dir).iterdir()
               if p.is_file() and fnmatch.fnmatch(p.name, args.pattern)
               and not re.search(r"-(Admin|NoAdmin)$", p.stem)
               and "CREATE-DUAL-VERSIONS" not in p.name.upper()
               and "TEST-DUAL-VERSIONS" not in p.name.upper()]
    print(f"Found {len(scripts)} scripts to process", file=sys.stderr)

    processed = failed = 0
    for script in scripts:
        admin_v = script.with_name(script.stem + "-Admin.bat")
        noadmin_v = script.with_name(script.stem + "-NoAdmin.bat")
        if (admin_v.exists() or noadmin_v.exists()) and not args.force:
            print(f"  skipping {script.name} (versions exist)", file=sys.stderr)
            continue
        if args.dry_run:
            print(f"  [dry-run] would create {admin_v.name} + {noadmin_v.name}",
                  file=sys.stderr)
            continue
        try:
            content = script.read_text(encoding="utf-8", errors="replace")
            admin_content = insert_after_banner(content, ADMIN_CHECK)
            admin_content += "\n" + ADMIN_FUNCS
            admin_v.write_text(retitle(admin_content, "Admin Mode"),
                               encoding="utf-8")
            noadmin_content = insert_after_banner(content, NOADMIN_NOTICE)
            noadmin_v.write_text(retitle(noadmin_content, "Standard Mode"),
                                 encoding="utf-8")
            processed += 1
            print(f"  created {admin_v.name} + {noadmin_v.name}", file=sys.stderr)
        except OSError as e:
            failed += 1
            print(f"  FAILED {script.name}: {e}", file=sys.stderr)

    print(f"\nProcessed: {processed}  Failed: {failed}", file=sys.stderr)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
