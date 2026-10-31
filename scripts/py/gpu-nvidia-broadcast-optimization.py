"""GPU / NVIDIA Broadcast optimization (Python port of gpu-nvidia-broadcast-optimization.ps1).

Python port of gpu-nvidia-broadcast-optimization.ps1
GPU and NVIDIA Broadcast optimization: detection, install, dual-GPU tuning,
communication platform acceleration, Broadcast configuration.
"""

import argparse
import asyncio
import json
import os
import shutil
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command, run_elevated  # noqa: E402
from devoptimizer_cli.core import winops  # noqa: E402

# CATEGORY: ai-ml
# TAGS: gpu, nvidia, broadcast, streaming


def log(level: str, message: str) -> None:
    print(f"[{level}] {message}", file=sys.stderr)


def expand(p: str) -> str:
    return os.path.expandvars(p)


PLATFORM_PATHS = {
    "Discord": [r"%LOCALAPPDATA%\Discord\Update.exe", r"%APPDATA%\Discord\Update.exe"],
    "Teams": [r"%LOCALAPPDATA%\Microsoft\Teams\current\Teams.exe",
              r"%ProgramFiles%\Microsoft\Teams\current\Teams.exe",
              r"%ProgramFiles(x86)%\Microsoft\Teams\current\Teams.exe"],
    "Zoom": [r"%ProgramFiles%\Zoom\bin\Zoom.exe", r"%ProgramFiles(x86)%\Zoom\bin\Zoom.exe",
             r"%APPDATA%\Zoom\bin\Zoom.exe"],
    "Skype": [r"%ProgramFiles%\Microsoft\Skype for Desktop\Skype.exe",
              r"%LOCALAPPDATA%\Microsoft\SkypeApp\Skype.exe"],
    "Slack": [r"%LOCALAPPDATA%\slack\slack.exe", r"%ProgramFiles%\Slack\slack.exe"],
    "WhatsApp": [r"%LOCALAPPDATA%\WhatsApp\WhatsApp.exe", r"%ProgramFiles%\WhatsApp\WhatsApp.exe"],
    "Telegram": [r"%APPDATA%\Telegram Desktop\Telegram.exe",
                 r"%ProgramFiles%\Telegram Desktop\Telegram.exe"],
    "OBS": [r"%ProgramFiles%\obs-studio\bin\64bit\obs64.exe",
            r"%ProgramFiles(x86)%\obs-studio\bin\32bit\obs32.exe"],
    "StreamLabs": [r"%ProgramFiles%\Streamlabs OBS\Streamlabs OBS.exe",
                   r"%LOCALAPPDATA%\Programs\streamlabs-obs\Streamlabs OBS.exe"],
    "XSplit": [r"%ProgramFiles%\SplitmediaLabs\XSplit Broadcaster\XSplit.Core.exe",
               r"%ProgramFiles(x86)%\SplitmediaLabs\XSplit Broadcaster\XSplit.Core.exe"],
    "Chrome": [r"%ProgramFiles%\Google\Chrome\Application\chrome.exe",
               r"%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe",
               r"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"],
    "Edge": [r"%ProgramFiles%\Microsoft\Edge\Application\msedge.exe",
             r"%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"],
    "Firefox": [r"%ProgramFiles%\Mozilla Firefox\firefox.exe",
                r"%ProgramFiles(x86)%\Mozilla Firefox\firefox.exe"],
}


async def get_gpu_information() -> dict:
    log("INFO", "Analyzing GPU configuration and capabilities...")
    info: dict = {"gpus": [], "nvidia_count": 0, "amd_count": 0, "intel_count": 0,
                  "total_vram_gb": 0.0, "rtx_support": False, "broadcast_compatible": False,
                  "nvidia_driver": None}
    ps = await winops.run_ps_command(
        "Get-CimInstance -ClassName Win32_VideoController | "
        "Where-Object { $_.Name -notlike '*Basic*' -and $_.Name -notlike '*Microsoft*' } | "
        "Select-Object Name, VideoProcessor, AdapterRAM, DriverVersion, DriverDate, DeviceID | "
        "ConvertTo-Json -Compress")
    raw = ps.stdout.strip()
    gpus = json.loads(raw) if raw else []
    if isinstance(gpus, dict):
        gpus = [gpus]
    for gpu in gpus:
        name = gpu.get("Name", "") or ""
        mem_gb = round((gpu.get("AdapterRAM") or 0) / 1073741824, 2)
        details = {
            "name": name, "manufacturer": gpu.get("VideoProcessor"), "memory_gb": mem_gb,
            "driver_version": gpu.get("DriverVersion"),
            "is_nvidia": bool(re.search(r"NVIDIA|GeForce|RTX|GTX|Quadro|Tesla", name)),
            "is_amd": bool(re.search(r"AMD|Radeon|RX", name)),
            "is_intel": bool(re.search(r"Intel|UHD|Iris", name)),
            "rtx_capable": bool(re.search(r"RTX", name)),
        }
        info["gpus"].append(details)
        info["total_vram_gb"] += mem_gb
        if details["is_nvidia"]:
            info["nvidia_count"] += 1
            if details["rtx_capable"]:
                info["rtx_support"] = True
                info["broadcast_compatible"] = True
        elif details["is_amd"]:
            info["amd_count"] += 1
        elif details["is_intel"]:
            info["intel_count"] += 1
    driver = winops.reg_get(r"HKLM\SOFTWARE\NVIDIA Corporation\Global\Display Driver", "Version")
    if driver:
        info["nvidia_driver"] = driver
    smi = shutil.which("nvidia-smi")
    if smi:
        result = await run_command(
            [smi, "--query-gpu=name,memory.total,driver_version", "--format=csv,noheader,nounits"],
            timeout=30)
        if result.returncode == 0:
            log("SUCCESS", "NVIDIA SMI detected - detailed GPU info available")
    log("SUCCESS", f"GPU analysis completed: {len(info['gpus'])} GPUs detected")
    return info


import re  # noqa: E402


def get_platforms() -> dict:
    log("INFO", "Detecting installed communication platforms...")
    platforms = {}
    for name, candidates in PLATFORM_PATHS.items():
        found = None
        for candidate in candidates:
            p = Path(expand(candidate))
            if p.exists():
                found = p
                break
        platforms[name] = {"installed": found is not None, "path": str(found) if found else None}
    count = sum(1 for v in platforms.values() if v["installed"])
    log("SUCCESS", f"Communication platforms detected: {count} platforms found")
    return platforms


async def winget_install(package: str, dry_run: bool) -> bool:
    if dry_run:
        log("INFO", f"[DRY RUN] Would winget install {package}")
        return True
    result = await run_command(
        ["winget", "install", package, "--accept-source-agreements", "--accept-package-agreements"],
        timeout=1800)
    return result.returncode == 0


async def install_broadcast(dry_run: bool) -> int:
    log("INFO", "Installing NVIDIA Broadcast and prerequisites...")
    info = await get_gpu_information()
    if not info["broadcast_compatible"]:
        log("ERROR", "NVIDIA Broadcast requires RTX GPU. No compatible GPU found.")
        return 0
    installed = 0
    broadcast_exe = Path(expand(r"%ProgramFiles%\NVIDIA Corporation\NVIDIA Broadcast\NVIDIA Broadcast.exe"))
    if broadcast_exe.exists():
        log("INFO", "NVIDIA Broadcast is already installed")
    elif await winget_install("NVIDIA Broadcast", dry_run):
        log("SUCCESS", "NVIDIA Broadcast installed successfully")
        installed += 1
    else:
        log("WARN", "Failed to install NVIDIA Broadcast via winget. Please download manually from NVIDIA website.")
    for pkg in ("Microsoft.VCRedist.2015+.x64", "Microsoft.VCRedist.2015+.x86",
                "Microsoft.VCRedist.2013.x64", "Microsoft.VCRedist.2013.x86"):
        if await winget_install(pkg, dry_run):
            log("SUCCESS", f"Installed: {pkg}")
            installed += 1
        else:
            log("WARN", f"Could not install: {pkg}")
    log("INFO", "[DRY RUN] Would install DirectX End-User Runtime (dxwebsetup.exe /Q)" if dry_run
        else "DirectX End-User Runtime: use the DirectX web installer manually (silent EULA automation is unreliable)")
    return installed


async def optimize_dual_gpu(dry_run: bool) -> int:
    log("INFO", "Optimizing GPU configuration...")
    info = await get_gpu_information()
    if len(info["gpus"]) < 2:
        log("INFO", "Single GPU detected. Applying single GPU optimizations instead.")
        return await optimize_single_gpu(dry_run)
    n = 0
    if dry_run:
        log("INFO", "[DRY RUN] Would enable Hardware Accelerated GPU Scheduling (HwSchMode=2)")
        log("INFO", "[DRY RUN] Would apply NVIDIA PowerMizer + Coolbits registry settings")
        log("INFO", "[DRY RUN] Would set High Performance power plan + PCIe ASPM off")
        log("INFO", "[DRY RUN] Would set LargeSystemCache=1 and disable GameDVR")
        return 4
    if winops.reg_set(r"HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", "HwSchMode", 2, winops.winreg.REG_DWORD):
        log("SUCCESS", "Enabled Hardware Accelerated GPU Scheduling")
        n += 1
    else:
        log("WARN", "Could not enable Hardware Accelerated GPU Scheduling (elevation required)")
    if info["nvidia_count"] > 0:
        log("INFO", "Optimizing NVIDIA Control Panel settings...")
        for reg_path, values in (
            (r"HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000",
             {"PowerMizerEnable": 1, "PowerMizerLevel": 1, "PowerMizerLevelAC": 1}),
            (r"HKLM\SOFTWARE\NVIDIA Corporation\Global\NVTweak", {"Coolbits": 31}),
        ):
            for name, value in values.items():
                if winops.reg_set(reg_path, name, value, winops.winreg.REG_DWORD):
                    log("SUCCESS", f"Set NVIDIA setting: {name} = {value}")
                    n += 1
                else:
                    log("WARN", f"Could not apply NVIDIA registry setting {name} (elevation required)")
    for cmd in (["powercfg", "/setactive", "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"],
                ["powercfg", "/change", "usb-selective-suspend-setting", "0"],
                ["powercfg", "/setacvalueindex", "scheme_current", "sub_pciexpress", "aspm", "0"],
                ["powercfg", "/setdcvalueindex", "scheme_current", "sub_pciexpress", "aspm", "0"]):
        result = await run_elevated(cmd, timeout=60)
        if result.returncode != 0:
            log("WARN", f"powercfg failed: {' '.join(cmd[1:3])}")
    log("SUCCESS", "Power management optimized for GPU workloads")
    n += 1
    for path, name, value in (
        (r"HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", "LargeSystemCache", 1),
        (r"HKCU\System\GameConfigStore", "GameDVR_Enabled", 0),
        (r"HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR", "AllowGameDVR", 0),
    ):
        if winops.reg_set(path, name, value, winops.winreg.REG_DWORD):
            n += 1
    log("SUCCESS", f"GPU optimization completed: {n} optimizations applied")
    return n


async def optimize_single_gpu(dry_run: bool) -> int:
    """Reduced set for single-GPU machines (the PS referenced this but never defined it)."""
    log("INFO", "Applying single-GPU optimizations...")
    if dry_run:
        log("INFO", "[DRY RUN] Would disable GameDVR and set balanced power plan")
        return 2
    n = 0
    if winops.reg_set(r"HKCU\System\GameConfigStore", "GameDVR_Enabled", 0, winops.winreg.REG_DWORD):
        n += 1
    result = await run_elevated(["powercfg", "/change", "usb-selective-suspend-setting", "0"], timeout=60)
    if result.returncode == 0:
        n += 1
    log("SUCCESS", f"Single-GPU optimization completed: {n} optimizations applied")
    return n


async def optimize_platforms(dry_run: bool) -> int:
    log("INFO", "Optimizing communication platforms for GPU acceleration...")
    platforms = get_platforms()
    n = 0
    discord_settings = Path(expand(r"%APPDATA%\discord\settings.json"))
    if platforms["Discord"]["installed"] and discord_settings.exists():
        if dry_run:
            log("INFO", "[DRY RUN] Would enable Discord hardware acceleration")
            n += 1
        else:
            try:
                data = json.loads(discord_settings.read_text(encoding="utf-8-sig"))
                data["HARDWARE_ACCELERATION"] = True
                data["OPEN_ON_STARTUP"] = False
                data["START_MINIMIZED"] = True
                discord_settings.write_text(json.dumps(data, indent=2), encoding="utf-8")
                log("SUCCESS", "Discord settings optimized")
                n += 1
            except (OSError, ValueError) as e:
                log("WARN", f"Could not optimize Discord settings: {e}")
    for browser in ("Chrome", "Edge"):
        if platforms[browser]["installed"]:
            log("INFO", f"[DRY RUN] Would configure {browser} GPU preference" if dry_run
                else f"{browser} present; graphics preference is set via Windows Settings > Display > Graphics")
            n += 1
    obs_config = Path(expand(r"%APPDATA%\obs-studio\global.ini"))
    if platforms["OBS"]["installed"] and obs_config.exists():
        if dry_run:
            log("INFO", "[DRY RUN] Would append NVENC Direct3D 11 renderer config to OBS global.ini")
            n += 1
        else:
            text = obs_config.read_text(encoding="utf-8", errors="replace")
            if "Renderer=Direct3D 11" not in text:
                text += "\n[Video]\nRenderer=Direct3D 11\nAdapter=0\n[Output]\nMode=Advanced"
                obs_config.write_text(text, encoding="utf-8")
                log("SUCCESS", "OBS Studio optimized for GPU acceleration")
                n += 1
    teams_key = r"HKCU\SOFTWARE\Microsoft\Teams"
    if platforms["Teams"]["installed"]:
        if dry_run:
            log("INFO", "[DRY RUN] Would enable Teams GPU acceleration (GPU_Acceleration=1)")
            n += 1
        elif winops.reg_set(teams_key, "GPU_Acceleration", 1, winops.winreg.REG_DWORD):
            log("SUCCESS", "Microsoft Teams GPU acceleration enabled")
            n += 1
    zoom_conf = Path(expand(r"%APPDATA%\Zoom\data\zoomus.conf"))
    if platforms["Zoom"]["installed"] and zoom_conf.exists():
        if dry_run:
            log("INFO", "[DRY RUN] Would append Zoom hardware acceleration flags")
            n += 1
        else:
            text = zoom_conf.read_text(encoding="utf-8", errors="replace")
            if "enableHardwareAcceleration" not in text:
                text += "\nenableHardwareAcceleration=true\nuseGPUForVideoProcessing=true"
                zoom_conf.write_text(text, encoding="utf-8")
                log("SUCCESS", "Zoom hardware acceleration enabled")
                n += 1
    log("SUCCESS", f"Communication platforms optimization completed: {n} optimizations")
    return n


async def configure_broadcast(dry_run: bool) -> int:
    log("INFO", "Configuring NVIDIA Broadcast for optimal performance...")
    broadcast_exe = Path(expand(r"%ProgramFiles%\NVIDIA Corporation\NVIDIA Broadcast\NVIDIA Broadcast.exe"))
    if not broadcast_exe.exists():
        log("ERROR", "NVIDIA Broadcast not found. Please install it first.")
        return 0
    config_dir = Path(expand(r"%APPDATA%\NVIDIA Corporation\NVIDIA Broadcast"))
    if dry_run:
        log("INFO", f"[DRY RUN] Would write {config_dir / 'config.json'} + per-app profiles")
        return 2
    config_dir.mkdir(parents=True, exist_ok=True)
    config = {
        "audio": {"noiseRemoval": {"enabled": True, "strength": 0.8},
                  "roomEcho": {"enabled": True, "strength": 0.7}},
        "video": {"backgroundBlur": {"enabled": True, "strength": 0.8},
                  "backgroundReplacement": {"enabled": False},
                  "eyeContact": {"enabled": True}},
        "performance": {"gpuUsage": "auto", "quality": "high", "maxFPS": 60},
    }
    (config_dir / "config.json").write_text(json.dumps(config, indent=2), encoding="utf-8")
    log("SUCCESS", "NVIDIA Broadcast configuration created")
    platforms = get_platforms()
    profiles_dir = config_dir / "profiles"
    profiles_dir.mkdir(parents=True, exist_ok=True)
    created = 0
    for name, state in platforms.items():
        if state["installed"]:
            profile = {"name": name, "audioInput": "NVIDIA Broadcast", "audioOutput": "default",
                       "videoInput": "NVIDIA Broadcast", "autoStart": True}
            (profiles_dir / f"{name}.json").write_text(json.dumps(profile, indent=2), encoding="utf-8")
            created += 1
    log("SUCCESS", f"Created {created} application profiles for NVIDIA Broadcast")
    log("SUCCESS", "NVIDIA Broadcast configuration completed")
    return 1 + created


async def complete(dry_run: bool) -> bool:
    log("INFO", "Running complete GPU and NVIDIA Broadcast optimization...")
    total = 0
    info = await get_gpu_information()
    if info["broadcast_compatible"]:
        total += await install_broadcast(dry_run)
    else:
        log("WARN", "NVIDIA Broadcast requires RTX GPU - skipping installation")
    total += await optimize_dual_gpu(dry_run)
    if info["broadcast_compatible"]:
        total += await configure_broadcast(dry_run)
    total += await optimize_platforms(dry_run)
    if total > 0:
        log("SUCCESS", "Complete GPU optimization finished successfully!")
        log("INFO", f"Total optimizations applied: {total}")
        log("WARN", "RECOMMENDATION: Restart your computer to apply all changes")
        return True
    log("WARN", "GPU optimization completed with limited changes")
    return False


async def main_async() -> int:
    parser = argparse.ArgumentParser(description="GPU / NVIDIA Broadcast optimization")
    parser.add_argument("action", choices=["gpu-info", "platforms", "install", "dual-gpu",
                                           "platforms-optimize", "configure", "complete"],
                        nargs="?", default="gpu-info",
                        help="gpu-info (read-only) is the default; mutations are explicit")
    parser.add_argument("--dry-run", action="store_true", help="Preview without changing")
    parser.add_argument("--json", action="store_true", help="JSON output (gpu-info/platforms)")
    args = parser.parse_args()

    if args.action == "gpu-info":
        info = await get_gpu_information()
        print(json.dumps(info, indent=2) if args.json else json.dumps(info))
        return 0
    if args.action == "platforms":
        data = get_platforms()
        print(json.dumps(data, indent=2) if args.json else json.dumps(data))
        return 0
    if args.action == "install":
        return 0 if await install_broadcast(args.dry_run) > 0 else 1
    if args.action == "dual-gpu":
        return 0 if await optimize_dual_gpu(args.dry_run) > 0 else 1
    if args.action == "platforms-optimize":
        return 0 if await optimize_platforms(args.dry_run) > 0 else 1
    if args.action == "configure":
        return 0 if await configure_broadcast(args.dry_run) > 0 else 1
    return 0 if await complete(args.dry_run) else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main_async()))
