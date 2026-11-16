"""Add descriptions to hub scripts missing one (port of add-script-descriptions.ps1).

Reads config\\hub-registry.json for empty descriptions, inserts comment
help (.SYNOPSIS/.DESCRIPTION for .ps1, ":: SYNOPSIS:" for .bat/.cmd).
Byte-level insertion preserves encoding/BOM/line-endings; backups under
logs\\description-backups\\. Mutating; --dry-run.
"""

import argparse
import json
import shutil
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: registry, docs, generator

ROOT = Path(r"D:\DevOptimizer")
REG = ROOT / "config" / "hub-registry.json"

CURATED = {
    "scripts/check-cleanup-status.ps1":
        "Read-only Win11 cleanup status assessment: drives, temp, dev caches, "
        "browser data, VHDX sizes, Docker usage.",
    "scripts/win11-safe-cleanup.ps1":
        "User-level safe cleanup: user/Windows temp, dev caches, crash dumps, "
        "browser-cache subsets, Docker safe subset. No admin required.",
    "scripts/extended-cleanup.ps1":
        "Extended cleanup (weekly): deeper user-level sweeps beyond the daily "
        "safe cleanup.",
    "scripts/elevated-complete-cleanup.ps1":
        "Elevated complete cleanup: DISM component store, WU cache, Delivery "
        "Optimization, shadow copies, VHDX compaction. Requires admin.",
    "scripts/admin-cleanup-elevated.ps1":
        "Admin cleanup suite run elevated: DISM, update caches, shadow-copy pruning.",
    "scripts/win11-admin-cleanup-elevated.ps1":
        "Windows 11 admin cleanup (elevated): component store, update cache, "
        "Delivery Optimization, oldest shadow copy.",
    "scripts/win11-admin-cleanup.ps1":
        "Windows 11 admin cleanup prep/wrapper (non-elevated side of the "
        "elevated cleanup pair).",
    "scripts/dev-cleanup.ps1":
        "Developer environment cleanup: package-manager caches, WSL, VS Code, "
        "leftover dev ports.",
    "scripts/windows-update-cleanup.ps1":
        "Windows Update cache and component cleanup.",
    "scripts/enhanced-system-health.ps1":
        "Enhanced system health report: hardware, services, event logs, "
        "performance counters.",
    "scripts/win11-health-snapshot.ps1":
        "Windows 11 health snapshot: SMART, Defender, PnP devices, services, "
        "event-log errors.",
    "scripts/devin/Check-DevinHealth.ps1":
        "Devin Desktop health check: bundles, tasks, MCP servers, "
        "maintenance-report status.",
    "modules/ollama-analytics.ps1":
        "Ollama usage analytics module for the DevOptimizer hub.",
}

VERB_MAP = {
    "apply": "Applies", "check": "Checks", "start": "Starts",
    "monitor": "Monitors", "cleanup": "Cleans up", "clean": "Cleans up",
    "verify": "Verifies", "create": "Creates", "fix": "Fixes",
    "remove": "Removes", "uninstall": "Uninstalls", "register": "Registers",
    "test": "Tests", "bootstrap": "Bootstraps", "configure": "Configures",
    "config": "Configures", "audit": "Audits", "collect": "Collects",
    "rollback": "Rolls back", "install": "Installs", "setup": "Sets up",
    "update": "Updates", "reorganize": "Reorganizes", "discover": "Discovers",
    "build": "Builds", "run": "Runs", "demo": "Demonstrates",
}


def describe(rel: str, filename: str) -> str:
    if rel in CURATED:
        return CURATED[rel]
    base = Path(filename).stem
    tokens = [t for t in re_split(base) if t]
    first = tokens[0].lower() if tokens else ""
    if len(tokens) > 1 and first in VERB_MAP:
        return f"{VERB_MAP[first]} {' '.join(tokens[1:]).lower()}."
    return f"DevOptimizer automation script: {base}."


def re_split(s: str) -> list[str]:
    import re
    return re.split(r"[-_.]", s)


def insert_ps1(raw: bytes, desc: str) -> bytes:
    """Prepend/merge a comment-help block preserving BOM + line endings."""
    bom = b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b""
    body = raw[len(bom):]
    crlf = b"\r\n" if b"\r\n" in body[:4096] else b"\n"
    block = b"<#" + crlf + b".SYNOPSIS" + crlf + b"    " + desc.encode() \
        + crlf + b".DESCRIPTION" + crlf + b"    " + desc.encode() \
        + crlf + b"#>" + crlf
    # if a help block already exists, inject into it after '<#'
    head = body[:4096].lstrip()
    if head.startswith(b"<#"):
        off = body.index(b"<#")
        return bom + body[:off + 2] + crlf + b".SYNOPSIS" + crlf + b"    " \
            + desc.encode() + crlf + b".DESCRIPTION" + crlf + b"    " \
            + desc.encode() + crlf + body[off + 2:]
    return bom + block + body


def insert_bat(raw: bytes, desc: str) -> bytes:
    crlf = b"\r\n" if b"\r\n" in raw[:4096] else b"\n"
    line = b":: SYNOPSIS: " + desc.encode() + crlf
    bom = b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b""
    body = raw[len(bom):]
    return bom + line + body


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    reg = json.loads(REG.read_text(encoding="utf-8-sig"))
    missing = [c for c in reg["commands"]
               if not c.get("description")
               or c["description"] == "No description available"]
    print(f"Missing descriptions: {len(missing)}", file=sys.stderr)

    done = skipped = errors = 0
    changes = []
    for entry in missing:
        rel = entry.get("path", "")
        full = ROOT / rel
        if not full.exists():
            skipped += 1
            continue
        desc = describe(rel.replace("/", "\\"), Path(rel).name)
        ext = full.suffix.lower()
        try:
            raw = full.read_bytes()
            if ext == ".ps1":
                new = insert_ps1(raw, desc)
            elif ext in (".bat", ".cmd"):
                new = insert_bat(raw, desc)
            else:
                skipped += 1
                continue
            changes.append({"path": rel, "desc": desc})
            if not args.dry_run:
                backup = ROOT / "logs" / "description-backups" / rel
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(full, backup)
                full.write_bytes(new)
            done += 1
        except OSError as e:
            errors += 1
            print(f"FAILED {rel}: {e}", file=sys.stderr)

    if args.json:
        print(json.dumps({"applied": done, "skipped": skipped,
                          "errors": errors, "changes": changes}, indent=2))
    else:
        print(f"done={done} skipped={skipped} errors={errors}"
              + (" (dry-run)" if args.dry_run else ""), file=sys.stderr)


if __name__ == "__main__":
    main()
