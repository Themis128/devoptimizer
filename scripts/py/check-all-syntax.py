"""Check .ps1 syntax across the tree (Python port of check-all-syntax.ps1).

Recursively scans for *.ps1 (excluding backups/logs/node_modules/.zcode)
and parses each with the PowerShell parser via the pwsh shim. Exit 1 when
any file has parse errors.
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: powershell, syntax, lint

EXCLUDE = ("backups", "backup-", "logs", "node_modules", ".zcode")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="Root directory to scan")
    parser.add_argument("--json", action="store_true", help="Emit errors as JSON")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    files = [f for f in root.rglob("*.ps1")
             if f.is_file() and not any(p in str(f) for p in EXCLUDE)]
    print(f"Scanned {len(files)} .ps1 files")

    bad = []
    for f in files:
        escaped = str(f).replace("'", "''")
        script = (
            "$e = $null; "
            f"$null = [System.Management.Automation.Language.Parser]::ParseFile('{escaped}', "
            "[ref]$null, [ref]$e); "
            "if ($e) { $e | ForEach-Object { "
            "  \"L$($_.Extent.StartLineNumber): $($_.Message)\" } } | "
            "ConvertTo-Json -Compress"
        )
        result = asyncio.run(run_ps_command(script, timeout=120))
        if result.returncode == 0 and result.stdout.strip() not in ("", "null"):
            errs = json.loads(result.stdout)
            if isinstance(errs, str):
                errs = [errs]
            bad.append({"File": str(f.relative_to(root)), "Errors": " | ".join(errs)})

    if args.json:
        print(json.dumps(bad, indent=2))
    if not bad:
        print("ALL SYNTAX OK")
        return
    print(f"{len(bad)} files with syntax errors:\n")
    for b in bad:
        print(f"[{b['File']}]\n  {b['Errors']}\n")
    sys.exit(1)


if __name__ == "__main__":
    main()
