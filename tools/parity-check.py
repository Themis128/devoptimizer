"""Parity gate: compare converted Python ports' action data against their PowerShell originals.

Parses the PS source for its hardcoded tables (services, DLLs, cache paths)
and compares them to the constants in the Python port. Exit 0 = parity.
"""

import importlib.util
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def _load(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, REPO / "scripts" / "py" / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


wu_cleanup = _load("wu_cleanup", "wu-cleanup.py")
dev_cache = _load("dev_cache", "dev-cache.py")


def ps_services_values_dlls(ps_text: str) -> tuple[list[str], list[str], list[str]]:
    """Extract services, problematic values, and DLL list from windows-update-cleanup.ps1."""
    svc_block = re.search(r"\$services\s*=\s*@\((.*?)\)", ps_text, re.S)
    services = re.findall(r'"([a-zA-Z]+)"', svc_block.group(1)) if svc_block else []
    values_block = re.search(r"\$problematicValues\s*=\s*@\((.*?)\)", ps_text, re.S)
    values = re.findall(r'"([^"]+)"', values_block.group(1)) if values_block else []
    dll_block = re.search(r"\$dlls\s*=\s*@\((.*?)\)", ps_text, re.S)
    dlls = re.findall(r'"([^"]+\.dll)"', dll_block.group(1)) if dll_block else []
    return services, values, dlls


def ps_cache_paths(ps_text: str) -> dict[str, list[str]]:
    """Extract per-family cache path tables from dev-cache-cleaner.ps1."""
    families: dict[str, list[str]] = {"nodejs": [], "python": [], "ide": []}
    for func_name, key in (
        ("Clear-NodeJSCache", "nodejs"),
        ("Clear-PythonCache", "python"),
        ("Clear-IDECache", "ide"),
   ):
        m = re.search(
            rf"function {func_name}\s*\{{.*?\$paths\s*=\s*@\((.*?)\n\s*\)", ps_text, re.S
        )
        if m:
            families[key] = re.findall(r'Path = "([^"]+)"', m.group(1))
    return families


def normalize_ps_env(p: str) -> str:
    """Map PS env syntax to the %VAR% form used in the Python tables."""
    return (
        p.replace("$env:APPDATA", "%APPDATA%")
        .replace("$env:LOCALAPPDATA", "%LOCALAPPDATA%")
        .replace("$env:USERPROFILE", "%USERPROFILE%")
    )


def main() -> int:
    failures = 0

    ps1_wu_path = REPO / "scripts" / "windows-update-cleanup.ps1"
    ps1_dc_path = REPO / "scripts" / "dev-cache-cleaner.ps1"

    if ps1_wu_path.exists():
        ps1_wu = ps1_wu_path.read_text(encoding="utf-8-sig", errors="replace")
        services, values, dlls = ps_services_values_dlls(ps1_wu)
        if sorted(services) != sorted(wu_cleanup.WU_SERVICES):
            print(f"FAIL wu services: PS={sorted(services)} PY={sorted(wu_cleanup.WU_SERVICES)}")
            failures += 1
        if sorted(values) != sorted(wu_cleanup.PROBLEMATIC_VALUES):
            print(f"FAIL wu reg values: PS={sorted(values)} PY={sorted(wu_cleanup.PROBLEMATIC_VALUES)}")
            failures += 1
        if sorted(dlls) != sorted(wu_cleanup.WU_DLLS):
            print(f"FAIL wu dlls: PS count={len(dlls)} PY count={len(wu_cleanup.WU_DLLS)}")
            failures += 1
    else:
        print("SKIP wu-cleanup: PS original already converted (absent)")

    if ps1_dc_path.exists():
        ps1_dc = ps1_dc_path.read_text(encoding="utf-8-sig", errors="replace")
        ps_families = ps_cache_paths(ps1_dc)
        for family in ("nodejs", "python", "ide"):
            py_templates = sorted(
                t.replace("/", "\\").lower() for _n, t in dev_cache.FAMILIES[family]
            )
            ps_norm = sorted({normalize_ps_env(p).lower() for p in ps_families[family]})
            if py_templates != ps_norm:
                print(f"FAIL dev_cache {family}: PS={ps_norm} PY={py_templates}")
                failures += 1
    else:
        print("SKIP dev-cache: PS original already converted (absent)")

    if failures:
        print(f"PARITY FAIL: {failures} mismatch(es)")
        return 1
    print("PARITY OK: all present source pairs match")
    return 0


def expand(template: str) -> str:
    import os

    return os.path.expandvars(template.replace("/", "\\"))


if __name__ == "__main__":
    sys.exit(main())
