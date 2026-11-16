"""Check .ps1 syntax across the tree (Python port of check-all-syntax.ps1).

Recursively scans for *.ps1 (excluding backups/logs/node_modules/.zcode)
and parses each with the PowerShell parser — pwsh when available so PS7
syntax (e.g. `??`) validates correctly, falling back to Windows
PowerShell 5.1. Exit 1 when any file has parse errors.
"""

import argparse
import asyncio
import json
import sys
import tempfile
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command  # noqa: E402

# CATEGORY: utilities
# TAGS: powershell, syntax, lint

EXCLUDE = ("backups", "backup-", "logs", "node_modules", ".zcode")
PORTABLE_PWSH = r"D:\DevOptimizer\pwsh\pwsh.exe"


async def pick_shell() -> str:
    """Prefer pwsh (portable then PATH) so PS7 syntax parses; fallback powershell."""
    for exe in (PORTABLE_PWSH, "pwsh"):
        try:
            probe = await run_command(
                [exe, "-NoProfile", "-NonInteractive", "-Command", "exit 0"],
                timeout=15)
            if probe.returncode == 0:
                return exe
        except (FileNotFoundError, OSError):
            continue
    return "powershell"


def build_ps(list_path: str) -> str:
    return (
        f"$paths = Get-Content '{list_path}' -Encoding UTF8 | "
        "Where-Object { $_ -ne '' }; "
        "$bad = @(); "
        "foreach ($f in $paths) { "
        "  $e = $null; "
        "  $null = [System.Management.Automation.Language.Parser]::ParseFile("
        "    $f, [ref]$null, [ref]$e); "
        "  if ($e) { $bad += [pscustomobject]@{ "
        "    File = $f; "
        "    Errors = ($e | ForEach-Object { "
        "      \"L$($_.Extent.StartLineNumber): $($_.Message)\" }) -join ' | ' "
        "  } } "
        "}; "
        "@($bad) | ConvertTo-Json -Compress"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="Root directory to scan")
    parser.add_argument("--json", action="store_true", help="Emit errors as JSON")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    files = [str(f) for f in root.rglob("*.ps1")
             if f.is_file() and not any(p in str(f) for p in EXCLUDE)]
    if not args.json:
        print(f"Scanned {len(files)} .ps1 files")

    async def run() -> "object":
        exe = await pick_shell()
        with tempfile.NamedTemporaryFile(
                "w", suffix=".lst", delete=False, encoding="utf-8") as tmp:
            tmp.write("\n".join(files))
            tmp_path = tmp.name.replace("/", "\\")
        return await run_command(
            [exe, "-NoProfile", "-NonInteractive",
             "-Command", build_ps(tmp_path)],
            timeout=600)

    result = asyncio.run(run())
    if result.returncode != 0:
        print(result.stderr.strip() or "syntax scan failed", file=sys.stderr)
        sys.exit(result.returncode if result.returncode else 1)

    raw = (result.stdout or "").strip()
    bad = json.loads(raw) if raw and raw != "null" else []
    if isinstance(bad, dict):
        bad = [bad]
    for b in bad:
        try:
            b["File"] = str(Path(b["File"]).relative_to(root))
        except (KeyError, ValueError):
            pass

    if args.json:
        print(json.dumps(bad, indent=2))
        sys.exit(1 if bad else 0)

    if not bad:
        print("ALL SYNTAX OK")
        return
    print(f"{len(bad)} files with syntax errors:\n")
    for b in bad:
        print(f"[{b['File']}]\n  {b['Errors']}\n")
    sys.exit(1)


if __name__ == "__main__":
    main()
