"""Display / screen settings management (Python port of screen-settings-management.ps1).

Python port of screen-settings-management.ps1
Display settings management: enumeration, resolution, orientation, brightness,
multi-monitor modes, and display profiles. Uses ctypes user32/dxva2 interop.
"""

import argparse
import asyncio
import ctypes
import json
import os
import sys
from ctypes import wintypes
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: display, screen, resolution, monitor

user32 = ctypes.windll.user32

ENUM_CURRENT_SETTINGS = -1
CDS_UPDATEREGISTRY = 0x01
CDS_TEST = 0x02
DISP_CHANGE_SUCCESSFUL = 0
DISP_CHANGE_RESTART = 1
DM_PELSWIDTH = 0x80000
DM_PELSHEIGHT = 0x100000
DM_BITSPERPEL = 0x40000
DM_DISPLAYFREQUENCY = 0x400000
DM_ORIENTATION = 0x10

ORIENTATION_MAP = {"Landscape": 0, "Portrait": 1, "LandscapeFlipped": 2, "PortraitFlipped": 3}

COMMON_RESOLUTIONS = [
    (1920, 1080, "Full HD (1920x1080)"), (2560, 1440, "2K QHD (2560x1440)"),
    (3840, 2160, "4K UHD (3840x2160)"), (1366, 768, "HD (1366x768)"),
    (1680, 1050, "WSXGA+ (1680x1050)"), (1600, 900, "HD+ (1600x900)"),
    (1440, 900, "WXGA+ (1440x900)"), (1280, 1024, "SXGA (1280x1024)"),
    (1280, 720, "HD (1280x720)"), (1024, 768, "XGA (1024x768)"),
]
COMMON_REFRESH_RATES = [60, 75, 120, 144, 165, 240]

PROFILE_DIR = Path(os.path.expandvars(r"%USERPROFILE%\Desktop\DevOptimizer\display-profiles"))


class DEVMODE(ctypes.Structure):
    _fields_ = [
        ("dmDeviceName", wintypes.WCHAR * 32),
        ("dmSpecVersion", wintypes.WORD), ("dmDriverVersion", wintypes.WORD),
        ("dmSize", wintypes.WORD), ("dmDriverExtra", wintypes.WORD),
        ("dmFields", wintypes.DWORD),
        ("dmPositionX", ctypes.c_long), ("dmPositionY", ctypes.c_long),
        ("dmDisplayOrientation", wintypes.DWORD), ("dmDisplayFixedOutput", wintypes.DWORD),
        ("dmColor", wintypes.SHORT), ("dmDuplex", wintypes.SHORT),
        ("dmYResolution", wintypes.SHORT), ("dmTTOption", wintypes.SHORT),
        ("dmCollate", wintypes.SHORT),
        ("dmFormName", wintypes.WCHAR * 32),
        ("dmLogPixels", wintypes.WORD),
        ("dmBitsPerPel", wintypes.DWORD), ("dmPelsWidth", wintypes.DWORD),
        ("dmPelsHeight", wintypes.DWORD), ("dmDisplayFlags", wintypes.DWORD),
        ("dmDisplayFrequency", wintypes.DWORD),
        ("dmICMMethod", wintypes.DWORD), ("dmICMIntent", wintypes.DWORD),
        ("dmMediaType", wintypes.DWORD), ("dmDitherType", wintypes.DWORD),
        ("dmReserved1", wintypes.DWORD), ("dmReserved2", wintypes.DWORD),
        ("dmPanningWidth", wintypes.DWORD), ("dmPanningHeight", wintypes.DWORD),
    ]


class DISPLAY_DEVICE(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("DeviceName", wintypes.WCHAR * 32),
        ("DeviceString", wintypes.WCHAR * 128),
        ("StateFlags", wintypes.DWORD),
        ("DeviceID", wintypes.WCHAR * 128),
        ("DeviceKey", wintypes.WCHAR * 128),
    ]


def log(level: str, message: str) -> None:
    print(f"[{level}] {message}", file=sys.stderr)


def get_display_information() -> list[dict]:
    log("INFO", "Analyzing display configuration...")
    displays = []
    index = 0
    while True:
        device = DISPLAY_DEVICE()
        device.cb = ctypes.sizeof(DISPLAY_DEVICE)
        if not user32.EnumDisplayDevicesW(None, index, ctypes.byref(device), 0):
            break
        devmode = DEVMODE()
        devmode.dmSize = ctypes.sizeof(DEVMODE)
        if user32.EnumDisplaySettingsW(device.DeviceName, ENUM_CURRENT_SETTINGS, ctypes.byref(devmode)):
            modes = []
            mode_index = 0
            while True:
                mode_dm = DEVMODE()
                mode_dm.dmSize = ctypes.sizeof(DEVMODE)
                if not user32.EnumDisplaySettingsW(device.DeviceName, mode_index, ctypes.byref(mode_dm)):
                    break
                key = f"{mode_dm.dmPelsWidth}x{mode_dm.dmPelsHeight}@{mode_dm.dmDisplayFrequency}Hz"
                if key not in {f"{m['Width']}x{m['Height']}@{m['RefreshRate']}Hz" for m in modes}:
                    modes.append({
                        "Width": mode_dm.dmPelsWidth, "Height": mode_dm.dmPelsHeight,
                        "RefreshRate": mode_dm.dmDisplayFrequency, "BitsPerPixel": mode_dm.dmBitsPerPel,
                    })
                mode_index += 1
            modes.sort(key=lambda m: (m["Width"], m["Height"], m["RefreshRate"]))
            displays.append({
                "Index": index, "DeviceName": device.DeviceName,
                "DeviceString": device.DeviceString, "DeviceID": device.DeviceID,
                "IsPrimary": bool(device.StateFlags & 0x4), "IsActive": bool(device.StateFlags & 0x1),
                "Width": devmode.dmPelsWidth, "Height": devmode.dmPelsHeight,
                "RefreshRate": devmode.dmDisplayFrequency, "BitsPerPixel": devmode.dmBitsPerPel,
                "Orientation": devmode.dmDisplayOrientation,
                "PositionX": devmode.dmPositionX, "PositionY": devmode.dmPositionY,
                "AvailableModes": modes,
            })
        index += 1
    log("SUCCESS", f"Display analysis completed: {len(displays)} displays detected")
    return displays


def _current_devmode(device_name: str) -> DEVMODE | None:
    devmode = DEVMODE()
    devmode.dmSize = ctypes.sizeof(DEVMODE)
    if not user32.EnumDisplaySettingsW(device_name, ENUM_CURRENT_SETTINGS, ctypes.byref(devmode)):
        return None
    return devmode


def set_display_resolution(device_name: str, width: int, height: int,
                           refresh_rate: int = 0, bits_per_pel: int = 32) -> bool:
    log("INFO", f"Setting display resolution: {width}x{height}@{refresh_rate}Hz on {device_name}")
    devmode = _current_devmode(device_name)
    if devmode is None:
        log("ERROR", f"Could not get current display settings for {device_name}")
        return False
    devmode.dmPelsWidth = width
    devmode.dmPelsHeight = height
    devmode.dmBitsPerPel = bits_per_pel
    devmode.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_BITSPERPEL
    if refresh_rate > 0:
        devmode.dmDisplayFrequency = refresh_rate
        devmode.dmFields |= DM_DISPLAYFREQUENCY
    if user32.ChangeDisplaySettingsW(ctypes.byref(devmode), CDS_TEST) != DISP_CHANGE_SUCCESSFUL:
        log("ERROR", f"Display mode test failed for {width}x{height}@{refresh_rate}Hz")
        return False
    result = user32.ChangeDisplaySettingsW(ctypes.byref(devmode), CDS_UPDATEREGISTRY)
    if result == DISP_CHANGE_SUCCESSFUL:
        log("SUCCESS", f"Display resolution changed successfully to {width}x{height}@{refresh_rate}Hz")
        return True
    if result == DISP_CHANGE_RESTART:
        log("WARN", "Display resolution changed, restart required")
        return True
    log("ERROR", f"Failed to change display resolution (result {result})")
    return False


def set_display_orientation(device_name: str, orientation: str) -> bool:
    log("INFO", f"Setting display orientation to {orientation} on {device_name}")
    devmode = _current_devmode(device_name)
    if devmode is None:
        log("ERROR", f"Could not get current display settings for {device_name}")
        return False
    devmode.dmDisplayOrientation = ORIENTATION_MAP[orientation]
    devmode.dmFields |= DM_ORIENTATION
    if user32.ChangeDisplaySettingsW(ctypes.byref(devmode), CDS_TEST) != DISP_CHANGE_SUCCESSFUL:
        log("ERROR", f"Orientation test failed for {orientation}")
        return False
    result = user32.ChangeDisplaySettingsW(ctypes.byref(devmode), CDS_UPDATEREGISTRY)
    if result in (DISP_CHANGE_SUCCESSFUL, DISP_CHANGE_RESTART):
        log("SUCCESS", f"Display orientation changed to {orientation}")
        return True
    log("ERROR", f"Failed to change orientation (result {result})")
    return False


async def set_display_brightness(brightness: int, monitor_index: int = 0) -> bool:
    log("INFO", f"Setting display brightness to {brightness}% on monitor {monitor_index}")
    ps_script = (
        "$m = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods; "
        "if ($m) { $m[" + str(monitor_index) + "].WmiSetBrightness(1, "
        + str(brightness) + "); 'OK' }"
    )
    ps = await winops_run_ps(ps_script)
    if ps.stdout.strip() == "OK":
        log("SUCCESS", f"Display brightness set to {brightness}% via WMI")
        return True
    log("WARN", "Brightness control may not be supported on this system or monitor")
    return False


async def winops_run_ps(script: str):
    from devoptimizer_cli.core.winops import run_ps_command

    return await run_ps_command(script)


def set_multi_monitor(mode: str) -> bool:
    log("INFO", f"Setting multi-monitor configuration to {mode}")
    displays = get_display_information()
    if len(displays) < 2:
        log("WARN", "Multi-monitor configuration requires at least 2 displays")
        return False
    switch_args = {"Extend": "/extend", "Duplicate": "/clone",
                   "Primary": "/internal", "Secondary": "/external"}
    result = asyncio.run(run_elevated(["DisplaySwitch.exe", switch_args[mode]], timeout=60))
    if result.returncode == 0:
        log("SUCCESS", f"{mode} display mode activated")
        return True
    log("WARN", f"DisplaySwitch exited {result.returncode}")
    return False


def save_display_profile(profile_name: str) -> bool:
    log("INFO", f"Saving display profile: {profile_name}")
    displays = get_display_information()
    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    profile = {
        "Name": profile_name,
        "Displays": [{"DeviceName": d["DeviceName"], "Width": d["Width"],
                      "Height": d["Height"], "RefreshRate": d["RefreshRate"],
                      "BitsPerPixel": d["BitsPerPixel"]} for d in displays],
    }
    path = PROFILE_DIR / f"{profile_name}.json"
    path.write_text(json.dumps(profile, indent=2), encoding="utf-8")
    log("SUCCESS", f"Display profile saved: {path}")
    return True


def load_display_profile(profile_name: str) -> bool:
    log("INFO", f"Loading display profile: {profile_name}")
    path = PROFILE_DIR / f"{profile_name}.json"
    if not path.exists():
        log("ERROR", f"Display profile not found: {path}")
        return False
    profile = json.loads(path.read_text(encoding="utf-8-sig"))
    success = True
    for display in profile["Displays"]:
        if not set_display_resolution(display["DeviceName"], display["Width"],
                                      display["Height"], display.get("RefreshRate", 0)):
            success = False
            log("WARN", f"Failed to apply settings for {display['DeviceName']}")
    log("SUCCESS" if success else "WARN",
        f"Display profile {'loaded successfully' if success else 'loaded with some failures'}: {profile_name}")
    return success


def main() -> int:
    parser = argparse.ArgumentParser(description="Display / screen settings management")
    parser.add_argument("action", choices=["info", "set-resolution", "set-orientation",
                                           "set-brightness", "multimonitor",
                                           "save-profile", "load-profile", "resolutions"],
                        nargs="?", default="info", help="info (read-only) is the default")
    parser.add_argument("--device", default=None, help="Display DeviceName (see info)")
    parser.add_argument("--width", type=int)
    parser.add_argument("--height", type=int)
    parser.add_argument("--refresh", type=int, default=0)
    parser.add_argument("--orientation", choices=sorted(ORIENTATION_MAP))
    parser.add_argument("--brightness", type=int, default=50)
    parser.add_argument("--monitor-index", type=int, default=0)
    parser.add_argument("--mode", choices=["Extend", "Duplicate", "Primary", "Secondary"], default="Extend")
    parser.add_argument("--profile-name", default=None)
    parser.add_argument("--json", action="store_true", help="JSON output (info)")
    args = parser.parse_args()

    if args.action == "info":
        data = get_display_information()
        print(json.dumps(data, indent=2) if args.json else json.dumps(data))
        return 0
    if args.action == "resolutions":
        for w, h, name in COMMON_RESOLUTIONS:
            print(f"{name}  rates: {COMMON_REFRESH_RATES}")
        return 0
    if args.action == "set-resolution":
        if not (args.device and args.width and args.height):
            log("ERROR", "set-resolution requires --device, --width, --height")
            return 1
        return 0 if set_display_resolution(args.device, args.width, args.height, args.refresh) else 1
    if args.action == "set-orientation":
        if not (args.device and args.orientation):
            log("ERROR", "set-orientation requires --device and --orientation")
            return 1
        return 0 if set_display_orientation(args.device, args.orientation) else 1
    if args.action == "set-brightness":
        return 0 if asyncio.run(set_display_brightness(args.brightness, args.monitor_index)) else 1
    if args.action == "multimonitor":
        return 0 if set_multi_monitor(args.mode) else 1
    if args.action == "save-profile":
        if not args.profile_name:
            log("ERROR", "save-profile requires --profile-name")
            return 1
        return 0 if save_display_profile(args.profile_name) else 1
    if args.action == "load-profile":
        if not args.profile_name:
            log("ERROR", "load-profile requires --profile-name")
            return 1
        return 0 if load_display_profile(args.profile_name) else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
