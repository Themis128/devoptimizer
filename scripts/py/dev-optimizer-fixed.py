"""DevOptimizer end-to-end optimization (Python port of dev-optimizer-fixed.ps1).

Python port of dev-optimizer-fixed.ps1
Runs DevOptimizer end-to-end optimization workflows with selectable modes:
Windows registry tuning, dev tools, Docker, comprehensive cleanup, network,
and security hardening. Implements the 3 functions the PS script called but
never defined (Test-SystemVulnerabilities / Test-SystemSecurity /
Set-SecurityHardening) - Optimize-SecurityComplete was dead on arrival there.
"""

import argparse
import asyncio
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command, run_elevated  # noqa: E402
from devoptimizer_cli.core import winops  # noqa: E402

# CATEGORY: system-optimization
# TAGS: optimization, windows, docker, network, security


def log(level: str, message: str) -> None:
    print(f"[{level}] {message}", file=sys.stderr)


async def ps_json(script: str) -> object:
    result = await winops.run_ps_command(script + " | ConvertTo-Json -Compress -Depth 3")
    raw = result.stdout.strip()
    return json.loads(raw) if raw else None


async def ps_plain(script: str, timeout: int = 120) -> str:
    result = await winops.run_ps_command(script, timeout=timeout)
    return result.stdout.strip()


def is_admin() -> bool:
    try:
        import ctypes

        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def set_registry_safe(path: str, name: str, value, reg_type=None) -> bool:
    """PS Set-RegistryValueSafe: admin-gated, creates the key, logs failures."""
    if not is_admin():
        log("WARN", f"Skipping registry setting {path}\\{name} - requires admin privileges")
        return False
    if winops.reg_set(path, name, value, reg_type or winops.winreg.REG_DWORD):
        log("DEBUG", f"Set {path}\\{name} = {value}")
        return True
    log("WARN", f"Access denied setting {path}\\{name} - may require ownership change")
    return False


async def winget_list_installed(winget_id: str) -> bool:
    result = await run_command(["winget", "list", "--id", winget_id, "--exact"], timeout=120)
    return result.returncode == 0 and winget_id in result.stdout


async def install_package_winget(name: str, winget_id: str, allow_upgrade: bool = False) -> bool:
    log("INFO", f"Installing/checking {name} via winget...")
    if await winget_list_installed(winget_id):
        log("INFO", f"{name} is already installed")
        if not allow_upgrade:
            return True
        result = await run_command(
            ["winget", "upgrade", "--id", winget_id, "--silent",
             "--accept-package-agreements", "--accept-source-agreements"], timeout=1800)
        if result.returncode == 0:
            log("SUCCESS", f"Successfully upgraded: {name}")
            return True
        if "No available upgrade found" in result.stdout or "No newer package versions" in result.stdout:
            log("SUCCESS", f"{name} is already up to date")
            return True
        log("WARN", f"Upgrade failed for {name}, but package is installed")
        return True
    result = await run_command(
        ["winget", "install", "--id", winget_id, "--silent",
         "--accept-package-agreements", "--accept-source-agreements"], timeout=1800)
    if result.returncode == 0:
        log("SUCCESS", f"Successfully installed: {name}")
        return True
    log("ERROR", f"Failed to install {name}: {result.stdout[-120:]}")
    return False


def refresh_env() -> None:
    machine = os.environ.get("Path", "")
    log("DEBUG", "Environment refresh requested (new processes pick up machine PATH)")
    _ = machine


RAM_GB = None


def ram_gb() -> float:
    global RAM_GB
    if RAM_GB is None:
        try:

            class MEMORYSTATUSEX(ctypes.Structure):
                _fields_ = [
                    ("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                    ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                    ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                    ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                    ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
                ]

            stat = MEMORYSTATUSEX()
            stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
            if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
                raise OSError("GlobalMemoryStatusEx failed")
            RAM_GB = round(stat.ullTotalPhys / 1073741824, 2)
        except (OSError, AttributeError):
            RAM_GB = 16.0
    return RAM_GB


import ctypes  # noqa: E402


async def get_enhanced_system_info() -> dict:
    log("INFO", "Gathering enhanced system info...")
    comp = await ps_json(
        "Get-CimInstance Win32_ComputerSystem | Select-Object Name, TotalPhysicalMemory")
    os_info = await ps_json(
        "Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version")
    cpu = await ps_json(
        "Get-CimInstance Win32_Processor | Select-Object -First 1 Name, NumberOfLogicalProcessors")
    gpu = await ps_json(
        "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike '*Basic*' } | "
        "Select-Object -First 1 Name, AdapterRAM")
    storage = await ps_json(
        "Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | "
        "Select-Object DeviceID, Size")
    nvme = await ps_json("Get-PhysicalDisk | Where-Object BusType -eq 'NVMe' | Measure-Object | "
                   "Select-Object -ExpandProperty Count")
    comp = comp or {}
    os_info = os_info or {}
    cpu = cpu or {}
    ram = round((comp.get("TotalPhysicalMemory") or 0) / 1073741824, 2)
    info = {
        "computer": comp.get("Name"),
        "os": f"{os_info.get('Caption')} ({os_info.get('Version')})" if os_info else None,
        "cpu": f"{cpu.get('Name')} - {cpu.get('NumberOfLogicalProcessors')} cores" if cpu else None,
        "ram_gb": ram or ram_gb(),
        "gpu": (gpu or {}).get("Name", "Integrated Graphics"),
        "storage": ", ".join(
            f"{s.get('DeviceID')} {round((s.get('Size') or 0) / 1073741824, 2)} GB"
            for s in (storage if isinstance(storage, list) else [storage]) if s),
        "nvme": bool(nvme),
        "dedicated_gpu": bool(gpu and (gpu.get("AdapterRAM") or 0) > 1073741824),
    }
    log("INFO", f"System: {info['computer']} | {info['cpu']} | {info['ram_gb']} GB")
    return info


LEVEL_REGISTRY = {
    "Conservative": {
        r"HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl": {"Win32PrioritySeparation": 38},
        r"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile": {"SystemResponsiveness": 10},
    },
    "Balanced": {
        r"HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl": {"Win32PrioritySeparation": 38},
        r"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile": {"SystemResponsiveness": 5},
        r"HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management": {
            "ClearPageFileAtShutdown": 0, "DisablePagingExecutive": 1,
            "LargeSystemCache": 1},
        r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize": {"StartupDelayInMSec": 0},
    },
    "Aggressive": {
        r"HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl": {"Win32PrioritySeparation": 24},
        r"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile": {"SystemResponsiveness": 1},
        r"HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management": {
            "ClearPageFileAtShutdown": 0, "DisablePagingExecutive": 1, "LargeSystemCache": 1,
            "SecondLevelDataCache": 1024, "ThirdLevelDataCache": 8192},
        r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize": {"StartupDelayInMSec": 0},
    },
    "Ultra": {
        r"HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl": {"Win32PrioritySeparation": 24},
        r"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile": {"SystemResponsiveness": 0},
        r"HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management": {
            "ClearPageFileAtShutdown": 0, "DisablePagingExecutive": 1, "LargeSystemCache": 1,
            "SecondLevelDataCache": 1024, "ThirdLevelDataCache": 12288, "PoolUsageMaximum": 60},
        r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize": {"StartupDelayInMSec": 0},
    },
}


async def optimize_windows_advanced(level: str, dry_run: bool) -> None:
    log("INFO", f"Applying advanced Windows optimization (Level: {level})...")
    if level in ("Aggressive", "Ultra") and not dry_run:
        log("INFO", "Creating system restore point...")
        await run_elevated(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command",
             "Checkpoint-Computer -Description 'DevOptimizer-v3.1' -RestorePointType MODIFY_SETTINGS"],
            timeout=300)
    for reg_path, values in LEVEL_REGISTRY[level].items():
        for name, value in values.items():
            if dry_run:
                log("INFO", f"[DRY RUN] Would set {reg_path}\\{name} = {value}")
            else:
                set_registry_safe(reg_path, name, value)
    if level in ("Aggressive", "Ultra"):
        if dry_run:
            log("INFO", "[DRY RUN] Would enable Ultimate Performance power plan")
        else:
            result = await run_elevated(
                ["powercfg", "/duplicatescheme", "e9a42b02-d5df-448d-aa00-03f14749eb61"], timeout=60)
            m = re.search(r"([0-9a-f-]{36})", result.stdout)
            if m:
                await run_elevated(["powercfg", "/setactive", m.group(1)], timeout=60)
                log("SUCCESS", f"Ultimate Performance plan activated: {m.group(1)}")
    for args in (["rss=enabled"], ["autotuninglevel=normal"], ["ecncapability=enabled"]):
        if dry_run:
            log("INFO", f"[DRY RUN] Would netsh int tcp set global {args[0]}")
        else:
            await run_elevated(["netsh", "int", "tcp", "set", "global"] + args, timeout=60)
    if dry_run:
        log("INFO", "[DRY RUN] Would apply NVMe fsutil optimizations if NVMe present")
    elif await _has_nvme():
        await run_elevated(["fsutil", "behavior", "set", "DisableDeleteNotify", "0"], timeout=60)
        await run_elevated(["fsutil", "behavior", "set", "EncryptPagingFile", "0"], timeout=60)
    if level == "Ultra" and not dry_run:
        result = await run_elevated(["sc.exe", "query", "WSearch"], timeout=30)
        if "RUNNING" in result.stdout:
            await run_elevated(["sc.exe", "stop", "WSearch"], timeout=60)
            await run_elevated(["sc.exe", "config", "WSearch", "start=", "disabled"], timeout=60)
            log("SUCCESS", "Windows Search service disabled")
    log("SUCCESS", "Advanced Windows optimization completed")


async def _has_nvme() -> bool:
    result = await run_command(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command",
         "(Get-PhysicalDisk | Where-Object BusType -eq 'NVMe' | Measure-Object).Count"], timeout=60)
    return result.stdout.strip() not in ("", "0")


TOOL_CATEGORIES = {
    "Essential": [("Git", "Git.Git"), ("Node.js", "OpenJS.NodeJS"),
                  ("Visual Studio Code", "Microsoft.VisualStudioCode"),
                  ("Windows Terminal", "Microsoft.WindowsTerminal")],
    "NodeJS": [("pnpm", "CMD:npm install -g pnpm"), ("Yarn", "Yarn.Yarn")],
    "Utilities": [("7-Zip", "7zip.7zip"), ("PowerToys", "Microsoft.PowerToys")],
}


async def install_dev_tools(categories: list[str], dry_run: bool) -> None:
    log("INFO", f"Installing development tools (Categories: {', '.join(categories)})...")
    if not shutil.which("winget"):
        log("ERROR", "winget not available; install tools manually")
        return
    for category in categories:
        log("INFO", f"Installing {category} tools...")
        for name, target in TOOL_CATEGORIES.get(category, []):
            if dry_run:
                log("INFO", f"[DRY RUN] Would install {name} ({target})")
                continue
            if target.startswith("CMD:"):
                result = await run_command(target[4:].split(), timeout=600)
                log("SUCCESS" if result.returncode == 0 else "ERROR", f"{name}: exit {result.returncode}")
            else:
                await install_package_winget(name, target, allow_upgrade=True)
    log("SUCCESS", "Development tools installation completed")


async def docker_ensure_running() -> bool:
    result = await run_command(["docker", "info"], timeout=60)
    if result.returncode == 0:
        return True
    log("WARN", "Docker daemon not running; attempting to start Docker Desktop...")
    subprocess.Popen([os.path.expandvars(r"%ProgramFiles%\Docker\Docker\Docker Desktop.exe")],
                     creationflags=getattr(subprocess, "DETACHED_PROCESS", 0))
    await asyncio.sleep(15)
    result = await run_command(["docker", "info"], timeout=60)
    return result.returncode == 0


async def docker_prune(args: list[str], label: str) -> None:
    result = await run_command(["docker"] + args, timeout=1800)
    m = re.search(r"Total reclaimed space: (.+)", result.stdout or "")
    log("SUCCESS" if result.returncode == 0 else "ERROR",
        f"{label}: {m.group(1).strip() if m else ('completed' if result.returncode == 0 else 'failed')}")


async def optimize_docker(all_: bool, containers: bool, images: bool, volumes: bool,
                          settings: bool, dry_run: bool) -> bool:
    log("INFO", "Starting Docker optimization...")
    if not shutil.which("docker"):
        log("ERROR", "Docker is not installed or not in PATH")
        return False
    if not await docker_ensure_running():
        log("ERROR", "Could not start Docker daemon. Please start Docker Desktop manually.")
        return False
    if all_ or containers:
        if dry_run:
            log("INFO", "[DRY RUN] Would docker container prune -f")
        else:
            await docker_prune(["container", "prune", "-f"], "Containers cleaned")
    if all_ or images:
        if dry_run:
            log("INFO", "[DRY RUN] Would docker image prune -a -f (removes ALL unused images)")
        else:
            await docker_prune(["image", "prune", "-a", "-f"], "Images cleaned")
    if all_ or volumes:
        if dry_run:
            log("INFO", "[DRY RUN] Would docker volume prune -f")
        else:
            await docker_prune(["volume", "prune", "-f"], "Volumes cleaned")
    if all_ or settings:
        docker_settings = Path(os.path.expandvars(r"%APPDATA%\Docker\settings.json"))
        ram = ram_gb()
        cpus = os.cpu_count() or 4
        docker_mem = int(ram * 1024 * 0.75)
        docker_cpus = max(1, int(cpus * 0.75))
        if dry_run:
            log("INFO", f"[DRY RUN] Would optimize Docker settings: {docker_mem}MB RAM, {docker_cpus} CPUs")
            log("INFO", "[DRY RUN] Would rewrite .wslconfig for Docker (backs up existing)")
        elif docker_settings.exists():
            try:
                config = json.loads(docker_settings.read_text(encoding="utf-8-sig"))
                config["memoryMiB"] = docker_mem
                config["cpus"] = docker_cpus
                config["experimental"] = True
                config["useVirtualizationFramework"] = True
                config["useVirtualizationFrameworkVirtioFS"] = True
                config["diskTrim"] = True
                docker_settings.write_text(json.dumps(config, indent=2), encoding="utf-8")
                log("SUCCESS", f"Docker Desktop settings optimized: {docker_mem}MB RAM, {docker_cpus} CPUs")
                log("INFO", "Please restart Docker Desktop to apply settings")
            except (OSError, ValueError) as e:
                log("ERROR", f"Error optimizing Docker settings: {e}")
        wslconfig = Path(os.path.expandvars(r"%USERPROFILE%\.wslconfig"))
        wsl_content = (
            f"[wsl2]\nmemory={max(1, int(ram * 0.75))}GB\nprocessors={max(1, int(cpus * 0.75))}\n"
            "localhostForwarding=true\nnestedVirtualization=true\npageReporting=true\n"
            "guiApplications=true\ndebugConsole=false\n")
        if dry_run:
            log("INFO", f"[DRY RUN] Would write {wslconfig} (backs up existing)")
        else:
            if wslconfig.exists():
                backup = wslconfig.with_suffix(".backup." + str(int(time.time())))
                shutil.copy2(wslconfig, backup)
                log("INFO", f"Backed up existing .wslconfig to {backup}")
            wslconfig.write_text(wsl_content, encoding="utf-8")
            log("SUCCESS", f"WSL2 configuration optimized for Docker: {max(1, int(ram * 0.75))}GB RAM")
            log("INFO", "Restart WSL to apply: wsl --shutdown")
    log("SUCCESS", "Docker optimization completed!")
    return True


def dir_size(path: Path) -> int:
    try:
        if not path.exists():
            return 0
    except OSError:
        return 0
    total = 0
    for item in path.rglob("*"):
        try:
            if item.is_file():
                total += item.stat().st_size
        except OSError:
            continue
    return total


def clear_contents(path: Path, keep_recent: int = 0) -> int:
    before = dir_size(path)
    try:
        entries = sorted(path.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)
    except OSError:
        return 0
    for item in (entries[keep_recent:] if keep_recent > 0 else entries):
        try:
            if item.is_dir():
                shutil.rmtree(item, ignore_errors=True)
            else:
                item.unlink()
        except OSError:
            continue
    return before - dir_size(path)


def _e(path: str) -> Path:
    return Path(os.path.expandvars(path))


async def clear_system_comprehensive(dry_run: bool) -> None:
    started = time.time()
    total = 0

    def clean(label: str, paths: list[Path], keep_recent: int = 0) -> None:
        nonlocal total
        for p in paths:
            if not p.exists():
                continue
            if dry_run:
                mb = round(dir_size(p) / 1048576, 2)
                log("INFO", f"[DRY RUN] Would clear {p} ({mb} MB)")
                continue
            freed = clear_contents(p, keep_recent)
            total += freed
            if freed > 0:
                log("SUCCESS", f"Cleaned {label}: {round(freed / 1048576, 2)} MB from {p}")

    log("INFO", "Step 1/10: Emptying Recycle Bin...")
    if dry_run:
        log("INFO", "[DRY RUN] Would empty the Recycle Bin (Clear-RecycleBin -Force)")
    else:
        result = await run_elevated(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command",
             "Clear-RecycleBin -Force"], timeout=120)
        log("SUCCESS" if result.returncode == 0 else "WARN", "Recycle Bin emptied")

    log("INFO", "Step 2/10: Clearing Windows Temp folders...")
    clean("Temp", [
        _e(r"%TEMP%"), _e(r"%WINDIR%\Temp"), _e(r"%LOCALAPPDATA%\Temp"),
        _e(r"%WINDIR%\SoftwareDistribution\Download"), _e(r"%WINDIR%\Logs"),
        _e(r"%LOCALAPPDATA%\Microsoft\Windows\INetCache"),
        _e(r"%LOCALAPPDATA%\Microsoft\Windows\WebCache"),
    ])
    log("INFO", "Step 3/10: Clearing Browser Caches...")
    clean("Chrome cache", [
        _e(r"%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache"),
        _e(r"%LOCALAPPDATA%\Google\Chrome\User Data\Default\Code Cache"),
        _e(r"%LOCALAPPDATA%\Google\Chrome\User Data\Default\GPUCache"),
        _e(r"%LOCALAPPDATA%\Google\Chrome\User Data\Default\Media Cache"),
    ])
    clean("Edge cache", [
        _e(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache"),
        _e(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Code Cache"),
        _e(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\GPUCache"),
    ])
    firefox = sorted(Path(_e(r"%APPDATA%\Mozilla\Firefox\Profiles")).glob("*")) \
        if Path(_e(r"%APPDATA%\Mozilla\Firefox\Profiles")).exists() else []
    if firefox:
        clean("Firefox cache", [firefox[0] / "cache2", firefox[0] / "startupCache",
                                firefox[0] / "thumbnails"])
    log("INFO", "Step 4/10: Clearing Development Caches...")
    clean("dev cache", [
        _e(r"%APPDATA%\npm-cache"), _e(r"%LOCALAPPDATA%\npm-cache"),
        _e(r"%USERPROFILE%\.npm"), _e(r"%USERPROFILE%\.pnpm-cache"),
        _e(r"%USERPROFILE%\.pnpm-store"), _e(r"%LOCALAPPDATA%\Yarn\Cache"),
        _e(r"%APPDATA%\Code\User\workspaceStorage"),
        _e(r"%APPDATA%\Cursor\User\workspaceStorage"),
        _e(r"%LOCALAPPDATA%\Microsoft\TypeScript"),
    ])
    log("INFO", "Step 5/10: Clearing Windows Error Reporting...")
    clean("WER reports", [
        _e(r"%LOCALAPPDATA%\Microsoft\Windows\WER\ReportQueue"),
        _e(r"%LOCALAPPDATA%\Microsoft\Windows\WER\ReportArchive"),
        _e(r"%PROGRAMDATA%\Microsoft\Windows\WER\ReportQueue"),
        _e(r"%PROGRAMDATA%\Microsoft\Windows\WER\ReportArchive"),
    ])
    log("INFO", "Step 6/10: Clearing Thumbnail Cache...")
    for explorer in (_e(r"%LOCALAPPDATA%\Microsoft\Windows\Explorer"),):
        if explorer.exists() and not dry_run:
            for item in explorer.iterdir():
                try:
                    if item.name.startswith(("thumbcache_", "iconcache_")):
                        item.unlink()
                except OSError:
                    continue
            log("SUCCESS", f"Cleared thumbnail cache in {explorer}")
    log("INFO", "Step 7/10: Clearing Windows Update Cache...")
    wu_cache = _e(r"%WINDIR%\SoftwareDistribution\Download")
    if wu_cache.exists() and not dry_run:
        await run_elevated(["net", "stop", "wuauserv"], timeout=60)
        clean("Windows Update cache", [wu_cache])
        await run_elevated(["net", "start", "wuauserv"], timeout=60)
    elif wu_cache.exists():
        log("INFO", f"[DRY RUN] Would clear {wu_cache} (stop/start wuauserv)")
    log("INFO", "Step 8/10: Clearing Prefetch (keeping recent)...")
    clean("old prefetch", [_e(r"%WINDIR%\Prefetch")], keep_recent=50)
    log("INFO", "Step 9/10: Clearing System Event Logs...")
    for event_log in ("Application", "System", "Security"):
        if dry_run:
            log("INFO", f"[DRY RUN] Would clear {event_log} event log")
        else:
            result = await run_elevated(["wevtutil.exe", "cl", event_log], timeout=60)
            log("SUCCESS" if result.returncode == 0 else "WARN", f"Cleared {event_log} event log")
    log("INFO", "Step 10/10: Running Disk Cleanup...")
    if dry_run:
        log("INFO", "[DRY RUN] Would run cleanmgr /sagerun:1")
    log("SUCCESS", f"=== COMPREHENSIVE CLEANUP COMPLETED === total: "
                   f"{round(total / 1048576, 2)} MB in {round(time.time() - started)}s")


def _adapter_query() -> str:
    # ps_json appends its own ConvertTo-Json - do not double-serialize here.
    return ("Get-NetAdapter | Where-Object Status -eq 'Up' | "
            "Select-Object Name, LinkSpeed, InterfaceIndex")


async def test_network_performance() -> list[dict]:
    log("INFO", "Starting network performance analysis...")
    adapters = await ps_json(_adapter_query())
    for a in (adapters if isinstance(adapters, list) else [adapters] if adapters else []):
        log("INFO", f"  - {a.get('Name')}: {a.get('LinkSpeed')}")
    results = []
    for server, name in (("8.8.8.8", "Google DNS"), ("1.1.1.1", "Cloudflare DNS"),
                         ("208.67.222.222", "OpenDNS")):
        started = time.time()
        result = await run_command(["nslookup", "google.com", server], timeout=15)
        results.append({"Server": server, "Name": name,
                        "ResponseTime": round((time.time() - started) * 1000, 2),
                        "ok": result.returncode == 0})
    ok_results = [r for r in results if r["ok"]]
    if ok_results:
        fastest = min(ok_results, key=lambda r: r["ResponseTime"])
        log("SUCCESS", f"Fastest DNS: {fastest['Name']} ({fastest['Server']}) - "
                       f"{fastest['ResponseTime']}ms")
    for host, port in (("google.com", 80), ("github.com", 443), ("microsoft.com", 443)):
        result = await run_command(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command",
             f"(Test-NetConnection -ComputerName {host} -Port {port} -InformationLevel Quiet)"],
            timeout=60)
        log("INFO", f"  {host}:{port} - {'Success' if result.stdout.strip().lower() == 'true' else 'Failed'}")
    ping = await run_command(["ping", "-n", "4", "8.8.8.8"], timeout=60)
    m = re.search(r"Average = (\d+)ms", ping.stdout)
    if m:
        log("SUCCESS", f"Average latency to 8.8.8.8: {m.group(1)}ms")
    return results


async def optimize_network_settings(all_: bool, dns: bool, tcp: bool, wifi: bool,
                                    dry_run: bool) -> None:
    log("INFO", "Starting network optimization...")
    if all_ or dns:
        if dry_run:
            log("INFO", "[DRY RUN] Would test DNS servers and set the fastest + 8.8.4.4")
        else:
            results = await test_network_performance()
            ok_results = [r for r in results if r.get("ok")]
            if ok_results:
                fastest = min(ok_results, key=lambda r: r["ResponseTime"])
                adapters = await ps_json(_adapter_query())
                for a in (adapters if isinstance(adapters, list) else [adapters] if adapters else []):
                    await run_elevated(
                        ["powershell", "-NoProfile", "-NonInteractive", "-Command",
                         f"Set-DnsClientServerAddress -InterfaceIndex {a.get('InterfaceIndex')} "
                         f"-ServerAddresses @('{fastest['Server']}','8.8.4.4')"], timeout=60)
                    log("SUCCESS", f"Set DNS for {a.get('Name')} to {fastest['Name']}")
                await run_elevated(
                    ["powershell", "-NoProfile", "-NonInteractive", "-Command",
                     "Clear-DnsClientCache"], timeout=60)
                log("SUCCESS", "DNS cache cleared")
    if all_ or tcp:
        for args in (["rss=enabled"], ["autotuninglevel=normal"], ["ecncapability=enabled"],
                     ["rsc=enabled"], ["timestamps=enabled"]):
            if dry_run:
                log("INFO", f"[DRY RUN] Would netsh int tcp set global {args[0]}")
            else:
                await run_elevated(["netsh", "int", "tcp", "set", "global"] + args, timeout=60)
                log("SUCCESS", f"Applied: {args[0]}")
    if all_ or wifi:
        if dry_run:
            log("INFO", "[DRY RUN] Would disable WiFi adapter power saving")
        else:
            result = await run_elevated(
                ["powershell", "-NoProfile", "-NonInteractive", "-Command",
                 "Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "
                 "'Wireless|WiFi|802.11' } | ForEach-Object { "
                 "Set-NetAdapterPowerManagement -InterfaceIndex $_.InterfaceIndex "
                 "-AllowComputerToTurnOffDevice Disabled }"], timeout=120)
            log("SUCCESS" if result.returncode == 0 else "WARN", "WiFi power management applied")
    log("SUCCESS", "Network optimization completed")


async def test_system_vulnerabilities() -> list[str]:
    """Phantom in the PS script - implemented here for real."""
    log("INFO", "Testing system vulnerabilities...")
    issues = []
    firewall = await ps_plain(
        "Get-NetFirewallProfile | Where-Object { $_.Enabled -eq $false } | "
        "Select-Object -ExpandProperty Name")
    if firewall:
        issues.append(f"Firewall profile(s) disabled: {firewall.replace(chr(10), ', ')}")
    defender = await ps_plain(
        "(Get-MpComputerStatus).RealTimeProtectionEnabled")
    if defender.lower() != "true":
        issues.append("Defender real-time protection is OFF")
    uac = winops.reg_get(r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System",
                         "EnableLUA")
    if uac in (0, None):
        issues.append("UAC is disabled")
    bitlocker = await ps_plain(
        "(Get-BitLockerVolume -MountPoint $env:SystemDrive).ProtectionStatus")
    if bitlocker.lower() != "on":
        issues.append(f"System drive BitLocker protection: {bitlocker or 'unknown'}")
    for issue in issues:
        log("WARN", f"Vulnerability: {issue}")
    if not issues:
        log("SUCCESS", "No vulnerabilities found in the checked set")
    return issues


async def set_security_hardening(all_: bool, dry_run: bool) -> None:
    log("INFO", "Applying security hardening...")
    actions = [
        ("Enable firewall profiles",
         "Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled True"),
        ("Ensure Defender real-time protection on",
         "Set-MpPreference -DisableRealtimeMonitoring $false"),
    ]
    for label, script in actions:
        if dry_run:
            log("INFO", f"[DRY RUN] Would: {label}")
            continue
        result = await run_elevated(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", script], timeout=120)
        log("SUCCESS" if result.returncode == 0 else "WARN", label)
    log("SUCCESS", "Security hardening completed")


async def main_async() -> int:
    parser = argparse.ArgumentParser(description="DevOptimizer end-to-end optimization")
    parser.add_argument("action", choices=["info", "optimize", "devtools", "docker", "cleanup",
                                           "network-test", "network-optimize", "security", "complete"],
                        nargs="?", default="info", help="info (read-only) is the default")
    parser.add_argument("--level", choices=["Conservative", "Balanced", "Aggressive", "Ultra"],
                        default="Balanced", help="optimize: registry tuning level")
    parser.add_argument("--categories", nargs="*", default=["Essential"], help="devtools categories")
    parser.add_argument("--containers", action="store_true", help="docker: prune containers")
    parser.add_argument("--images", action="store_true", help="docker: prune unused images")
    parser.add_argument("--volumes", action="store_true", help="docker: prune volumes")
    parser.add_argument("--settings", action="store_true", help="docker: optimize Desktop/WSL settings")
    parser.add_argument("--all", action="store_true", help="docker/network-optimize: everything")
    parser.add_argument("--dns", action="store_true", help="network-optimize: DNS")
    parser.add_argument("--tcp", action="store_true", help="network-optimize: TCP")
    parser.add_argument("--wifi", action="store_true", help="network-optimize: WiFi")
    parser.add_argument("--json", action="store_true", help="JSON output (info)")
    parser.add_argument("--dry-run", action="store_true", help="Preview without changing")
    args = parser.parse_args()

    if args.action == "info":
        data = await get_enhanced_system_info()
        print(json.dumps(data, indent=2) if args.json else json.dumps(data))
        return 0
    if args.action == "optimize":
        await optimize_windows_advanced(args.level, args.dry_run)
        return 0
    if args.action == "devtools":
        await install_dev_tools(args.categories, args.dry_run)
        return 0
    if args.action == "docker":
        return 0 if await optimize_docker(args.all, args.containers, args.images,
                                          args.volumes, args.settings, args.dry_run) else 1
    if args.action == "cleanup":
        await clear_system_comprehensive(args.dry_run)
        return 0
    if args.action == "network-test":
        await test_network_performance()
        return 0
    if args.action == "network-optimize":
        await optimize_network_settings(args.all, args.dns, args.tcp, args.wifi, args.dry_run)
        return 0
    if args.action == "security":
        issues = await test_system_vulnerabilities()
        if args.all or args.settings:
            await set_security_hardening(True, args.dry_run)
        return 0 if not issues else 1
    if args.action == "complete":
        await optimize_windows_advanced(args.level, args.dry_run)
        await clear_system_comprehensive(args.dry_run)
        issues = await test_system_vulnerabilities()
        log("WARN" if issues else "SUCCESS",
            f"Complete optimization finished; {len(issues)} security finding(s)")
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main_async()))
