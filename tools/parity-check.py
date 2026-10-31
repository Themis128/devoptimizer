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


PREREQ_TEST_MAP = {
    "Test-PowerShellVersion": "PowerShell",
    "Test-DotNetFramework": ".NET Framework",
    "Test-WindowsVersion": "Windows",
    "Test-NodeJS": "Node.js",
    "Test-Python": "Python",
    "Test-Git": "Git",
    "Test-Docker": "Docker",
    "Test-PackageManagers": "package managers",
    "Test-DevelopmentTools": "development tools",
    "Test-SystemRequirements": "system requirements",
}

NUXT_FN_MAP = {
    "Get-Nuxt3Environment": "env",
    "Optimize-Nuxt3Windows": "windows",
    "Install-Nuxt3Prerequisites": "prereqs",
    "Optimize-Nuxt3WSL": "wsl",
    "Test-Nuxt3Performance": "performance",
}

CURSOR_FN_MAP = {
    "Get-CursorAIInfo": "info",
    "Optimize-CursorAISettings": "settings",
    "Install-CursorAIExtensions": "extensions",
    "Clear-CursorAICache": "cache",
    "Update-CursorAI": "update",
    "Optimize-CursorAIComplete": "complete",
}

GPU_FN_MAP = {
    "Get-GPUInformation": "gpu-info",
    "Get-CommunicationPlatforms": "platforms",
    "Install-NVIDIABroadcast": "install",
    "Optimize-DualGPU": "dual-gpu",
    "Optimize-CommunicationPlatforms": "platforms-optimize",
    "Configure-NVIDIABroadcast": "configure",
    "Optimize-GPUComplete": "complete",
}

SCREEN_FN_MAP = {
    "Get-DisplayInformation": "info",
    "Set-DisplayResolution": "set-resolution",
    "Set-DisplayOrientation": "set-orientation",
    "Set-DisplayBrightness": "set-brightness",
    "Set-MultiMonitorConfiguration": "multimonitor",
    "Get-CommonResolutions": "resolutions",
    "Get-CommonRefreshRates": "resolutions",
    "Save-DisplayProfile": "save-profile",
    "Load-DisplayProfile": "load-profile",
    "Show-DisplayMenu": "menu",
}

DEVOPT_FN_MAP = {
    "Set-RegistryValueSafe": "optimize",
    "Install-PackageWithWinget": "devtools",
    "RefreshEnv": "devtools",
    "Get-EnhancedSystemInfo": "info",
    "Optimize-WindowsAdvanced": "optimize",
    "Install-DevelopmentToolsAdvanced": "devtools",
    "Optimize-Docker": "docker",
    "Get-DockerSystemInfo": "info",
    "Optimize-Quick": "optimize",
    "Optimize-Ultra": "optimize",
    "Install-DevTools": "devtools",
    "Clear-AllCaches": "cleanup",
    "Optimize-DockerComplete": "docker",
    "Optimize-NetworkComplete": "network-optimize",
    "Optimize-SecurityComplete": "security",
    "Clear-SystemComprehensive": "cleanup",
    "Test-NetworkPerformance": "network-test",
    "Optimize-NetworkSettings": "network-optimize",
    "Test-NetworkConnectivity": "network-test",
    "Show-OptimizationMenu": "menu",
}


def ps_prereq_checks(ps_text: str) -> list[str]:
    """Test-* function inventory from prerequisites-checker.ps1."""
    return sorted(set(re.findall(r"^function (Test-[A-Za-z]+)", ps_text, re.M)))


def check_prerequisites(ps_text: str) -> int:
    """Structural parity: each PS Test-* maps to exactly one Python check."""
    failures = 0
    found = ps_prereq_checks(ps_text)
    mapped = sorted(PREREQ_TEST_MAP[t] for t in found if t in PREREQ_TEST_MAP)
    # Test-Command is the existence-probe helper (PS Get-Command / PY shutil.which),
    # not a check group.
    unmapped = [t for t in found if t not in PREREQ_TEST_MAP and t != "Test-Command"]

    sys.path.insert(0, str(REPO / "scripts" / "py"))
    import importlib

    spec = importlib.util.spec_from_file_location(
        "prereq_check", REPO / "scripts" / "py" / "prerequisites-checker.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    py_checks = sorted(mod.CHECKS.keys())

    if unmapped:
        print(f"FAIL prerequisites: PS checks missing from map: {unmapped}")
        failures += 1
    if mapped != py_checks:
        print(f"FAIL prerequisites: PS-mapped={mapped} PY={py_checks}")
        failures += 1
    return failures


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

    ps1_devopt_path = REPO / "scripts" / "dev-optimizer-fixed.ps1"
    if ps1_devopt_path.exists():
        ps1_devopt = ps1_devopt_path.read_text(encoding="utf-8-sig", errors="replace")
        failures += check_devopt(ps1_devopt)
    else:
        print("SKIP devopt: PS original already converted (absent)")

    ps1_screen_path = REPO / "scripts" / "screen-settings-management.ps1"
    if ps1_screen_path.exists():
        ps1_screen = ps1_screen_path.read_text(encoding="utf-8-sig", errors="replace")
        failures += check_screen(ps1_screen)
    else:
        print("SKIP screen: PS original already converted (absent)")

    ps1_gpu_path = REPO / "scripts" / "gpu-nvidia-broadcast-optimization.ps1"
    if ps1_gpu_path.exists():
        ps1_gpu = ps1_gpu_path.read_text(encoding="utf-8-sig", errors="replace")
        failures += check_gpu(ps1_gpu)
    else:
        print("SKIP gpu: PS original already converted (absent)")

    ps1_cursor_path = REPO / "scripts" / "cursor-ai-optimization.ps1"
    if ps1_cursor_path.exists():
        ps1_cursor = ps1_cursor_path.read_text(encoding="utf-8-sig", errors="replace")
        failures += check_cursor(ps1_cursor)
    else:
        print("SKIP cursor: PS original already converted (absent)")

    ps1_nuxt_path = REPO / "scripts" / "nuxt3-optimization.ps1"
    if ps1_nuxt_path.exists():
        ps1_nuxt = ps1_nuxt_path.read_text(encoding="utf-8-sig", errors="replace")
        failures += check_nuxt3(ps1_nuxt)
    else:
        print("SKIP nuxt3: PS original already converted (absent)")

    ps1_prereq_path = REPO / "scripts" / "prerequisites-checker.ps1"
    if ps1_prereq_path.exists():
        ps1_prereq = ps1_prereq_path.read_text(encoding="utf-8-sig", errors="replace")
        failures += check_prerequisites(ps1_prereq)
    else:
        print("SKIP prerequisites: PS original already converted (absent)")

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


def check_nuxt3(ps_text: str) -> int:
    """Structural parity: each PS function maps to one nuxt3 CLI action."""
    return _check_fn_map(ps_text, NUXT_FN_MAP, "nuxt3", "env")


def check_cursor(ps_text: str) -> int:
    """Structural parity: each PS function maps to one cursor CLI action."""
    return _check_fn_map(ps_text, CURSOR_FN_MAP, "cursor", "info")


def check_gpu(ps_text: str) -> int:
    """Structural parity: each PS function maps to one GPU CLI action."""
    return _check_fn_map(ps_text, GPU_FN_MAP, "gpu", "gpu-info")


def check_screen(ps_text: str) -> int:
    """Structural parity: each PS function maps to one screen CLI action."""
    return _check_fn_map(ps_text, SCREEN_FN_MAP, "screen", "info")


def check_devopt(ps_text: str) -> int:
    """Structural parity: each PS function maps to one devopt CLI action."""
    return _check_fn_map(ps_text, DEVOPT_FN_MAP, "devopt", "info", helpers={"Write-Log"})


def _check_fn_map(ps_text: str, fn_map: dict, label: str, default_action: str,
                  helpers: set[str] | None = None) -> int:
    failures = 0
    helpers = helpers or set()
    found = sorted(set(re.findall(r"^function ([A-Za-z0-9\-]+)", ps_text, re.M)))
    mapped = sorted(set(fn_map[f] for f in found if f in fn_map))
    unmapped = [f for f in found if f not in fn_map and f not in helpers]
    if unmapped:
        print(f"FAIL {label}: PS functions missing from map: {unmapped}")
        failures += 1
    actions = set(fn_map.values()) | {default_action}
    if mapped != sorted(actions):
        print(f"FAIL {label}: PS-mapped={mapped} PY-actions={sorted(actions)}")
        failures += 1
    return failures


def expand(template: str) -> str:
    import os

    return os.path.expandvars(template.replace("/", "\\"))


if __name__ == "__main__":
    sys.exit(main())
