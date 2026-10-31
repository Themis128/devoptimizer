"""Prerequisites checker and installer (Python port of prerequisites-checker.ps1).

Python port of prerequisites-checker.ps1
Prerequisites Checker and Installer Script: checks and installs required tools and dependencies.
"""

import argparse
import asyncio
import ctypes
import json
import os
import shutil
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command, run_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: prerequisites, check, install

INSTALLERS = {
    "Node.js": {
        "url": "https://nodejs.org/dist/v20.10.0/node-v20.10.0-x64.msi",
        "ext": ".msi",
        "install_args": ["/quiet", "/norestart"],
        "msi": True,
        "verify": "node",
    },
    "Python": {
        "url": "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe",
        "ext": ".exe",
        "install_args": ["/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0"],
        "msi": False,
        "verify": "python",
    },
    "Git": {
        "url": "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe",
        "ext": ".exe",
        "install_args": ["/VERYSILENT", "/NORESTART"],
        "msi": False,
        "verify": "git",
    },
}


def log(level: str, message: str) -> None:
    print(f"[{level}] {message}")


def which(name: str) -> bool:
    return shutil.which(name) is not None


def _exec_args(name: str, extra: list[str]) -> list[str]:
    """Resolve a tool to its full path; wrap .cmd/.bat in cmd /c (CreateProcess
    cannot execute batch files directly)."""
    full = shutil.which(name)
    argv = [full or name] + extra
    if full and full.lower().endswith((".cmd", ".bat")):
        argv = ["cmd.exe", "/c"] + argv
    return argv


async def command_version(name: str) -> str:
    for probe in (["--version"], ["/?"]):
        result = await run_command(_exec_args(name, probe), timeout=20)
        if result.returncode == 0 and result.stdout.strip():
            first = result.stdout.strip().splitlines()[0]
            return first[:80]
    return "unknown"


def record(status: dict, key: str, st: str, version: str, message: str) -> bool:
    status[key] = {"Status": st, "Version": version, "Message": message}
    ok = st == "OK"
    log("SUCCESS" if ok else ("WARNING" if st in ("OPTIONAL", "WARNING") else "ERROR"),
        f"{key}: {version} [{st}]")
    return ok


def check_powershell(status: dict) -> bool:
    log("INFO", "Checking PowerShell version...")
    result = asyncio.run(run_command(
        ["powershell", "-NoProfile", "-Command",
         "$PSVersionTable.PSVersion.ToString()"], timeout=30))
    ver = result.stdout.strip() or "unknown"
    try:
        parts = [int(p) for p in ver.split(".")]
        ok = parts[0] > 5 or (parts[0] == 5 and parts[1] >= 1)
    except ValueError:
        ok = False
    if ok:
        return record(status, "PowerShell", "OK", ver, f"PowerShell {ver} is compatible")
    return record(status, "PowerShell", "ERROR", ver, "PowerShell 5.1 or higher required")


def check_dotnet(status: dict) -> bool:
    log("INFO", "Checking .NET Framework...")
    try:
        import winreg

        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full",
        ) as key:
            release, _ = winreg.QueryValueEx(key, "Release")
        if release >= 394802:
            return record(status, ".NET Framework", "OK", "4.6.2+", ".NET Framework is available")
        return record(status, ".NET Framework", "WARNING", "Unknown", ".NET Framework 4.6.2+ recommended")
    except OSError:
        return record(status, ".NET Framework", "ERROR", "Unknown", ".NET Framework not found")


def check_windows(status: dict) -> bool:
    log("INFO", "Checking Windows version...")
    try:
        ver = sys.getwindowsversion()
        win_version = f"{ver.major}.{ver.minor}"
    except AttributeError:
        win_version = "unknown"
    if win_version >= "10.0":
        return record(status, "Windows", "OK", win_version, f"Windows {win_version} is supported")
    return record(status, "Windows", "WARNING", win_version, "Windows 10+ recommended")


def check_tool(name: str, key: str, required: bool, need_msg: str):
    def _check(status: dict) -> bool:
        log("INFO", f"Checking {key}...")
        if which(name):
            ver = asyncio.run(command_version(name))
            return record(status, key, "OK", ver, f"{key} is installed")
        st = "MISSING" if required else "OPTIONAL"
        return record(status, key, st, "Not installed", need_msg)
    return _check


def check_dev_tools(status: dict) -> bool:
    log("INFO", "Checking development tools...")
    ok_all = True
    pf = os.environ.get("ProgramFiles", r"C:\Program Files")
    lad = os.environ.get("LOCALAPPDATA", "")
    for key, path, msg in (
        ("VS Code", Path(pf) / "Microsoft VS Code" / "Code.exe", "VS Code is optional"),
        ("Cursor", Path(lad) / "Programs" / "Cursor" / "Cursor.exe", "Cursor is optional"),
    ):
        if path.exists():
            ok_all &= record(status, key, "OK", "Installed", f"{key} is installed")
        else:
            ok_all &= record(status, key, "OPTIONAL", "Not installed", msg)
    return ok_all


def check_system(status: dict) -> bool:
    log("INFO", "Checking system requirements...")
    ok_all = True
    total, _used, free = shutil.disk_usage("C:\\")
    free_gb = round(free / 1073741824, 2)
    total_gb = round(total / 1073741824, 2)
    if free_gb >= 5:
        ok_all &= record(status, "Disk Space", "OK", f"{free_gb}GB free / {total_gb}GB total", "Sufficient disk space available")
    else:
        ok_all &= record(status, "Disk Space", "WARNING", f"{free_gb}GB free / {total_gb}GB total", "Low disk space - 5GB+ recommended")

    class MEMORYSTATUSEX(ctypes.Structure):
        _fields_ = [
            ("dwLength", ctypes.c_ulong),
            ("dwMemoryLoad", ctypes.c_ulong),
            ("ullTotalPhys", ctypes.c_ulonglong),
            ("ullAvailPhys", ctypes.c_ulonglong),
            ("ullTotalPageFile", ctypes.c_ulonglong),
            ("ullAvailPageFile", ctypes.c_ulonglong),
            ("ullTotalVirtual", ctypes.c_ulonglong),
            ("ullAvailVirtual", ctypes.c_ulonglong),
            ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
        ]

    stat = MEMORYSTATUSEX()
    stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat))
    ram_gb = round(stat.ullTotalPhys / 1073741824, 2)
    if ram_gb >= 4:
        ok_all &= record(status, "RAM", "OK", f"{ram_gb}GB", "Sufficient RAM available")
    else:
        ok_all &= record(status, "RAM", "WARNING", f"{ram_gb}GB", "Low RAM - 4GB+ recommended")
    return ok_all


CHECKS = {
    "PowerShell": check_powershell,
    ".NET Framework": check_dotnet,
    "Windows": check_windows,
    "Node.js": check_tool("node", "Node.js", True, "Node.js is required for npm/yarn operations"),
    "Python": check_tool("python", "Python", True, "Python is required for pip/conda operations"),
    "Git": check_tool("git", "Git", True, "Git is required for repository operations"),
    "Docker": check_tool("docker", "Docker", False, "Docker is optional for container cache cleaning"),
    "package managers": lambda status: _check_managers(status),
    "development tools": check_dev_tools,
    "system requirements": check_system,
}


def _check_managers(status: dict) -> bool:
    log("INFO", "Checking package managers...")
    ok_all = True
    ok_all &= check_tool("npm", "npm", True, "npm comes with Node.js")(status)
    ok_all &= check_tool("pnpm", "pnpm", False, "pnpm is optional")(status)
    ok_all &= check_tool("yarn", "yarn", False, "yarn is optional")(status)
    ok_all &= check_tool("pip", "pip", True, "pip comes with Python")(status)
    ok_all &= check_tool("conda", "conda", False, "conda is optional")(status)
    return ok_all


def install_tool(name: str, results: dict, counts: dict) -> bool:
    spec = INSTALLERS[name]
    log("INFO", f"Installing {name}...")
    installer = Path(tempfile.gettempdir()) / f"{name.lower().replace('.', '')}-installer{spec['ext']}"
    try:
        log("INFO", f"Downloading {name} installer...")
        urllib.request.urlretrieve(spec["url"], installer)
        log("INFO", f"Installing {name}...")
        if spec["msi"]:
            asyncio.run(run_elevated(["msiexec.exe", "/i", str(installer)] + spec["install_args"], timeout=1800))
        else:
            asyncio.run(run_elevated([str(installer)] + spec["install_args"], timeout=1800))
        refresh_path()
        if which(spec["verify"]):
            ver = asyncio.run(command_version(spec["verify"]))
            results[name] = {"Status": "SUCCESS", "Version": ver, "Message": f"{name} installed successfully"}
            log("SUCCESS", f"{name} installed successfully: {ver}")
            counts["success"] += 1
            return True
        raise RuntimeError(f"{name} installation verification failed")
    except Exception as e:
        results[name] = {"Status": "FAILED", "Version": "Unknown", "Message": f"{name} installation failed: {e}"}
        log("ERROR", f"{name} installation failed: {e}")
        counts["failed"] += 1
        return False
    finally:
        try:
            if installer.exists():
                installer.unlink()
        except OSError:
            pass


def install_optional(results: dict, counts: dict) -> None:
    log("INFO", "Installing optional tools...")
    for tool in ("pnpm", "yarn"):
        if which(tool):
            continue
        try:
            log("INFO", f"Installing {tool}...")
            result = asyncio.run(run_command(_exec_args("npm", ["install", "-g", tool]), timeout=600))
            if result.returncode == 0 and which(tool):
                ver = asyncio.run(command_version(tool))
                results[tool] = {"Status": "SUCCESS", "Version": ver, "Message": f"{tool} installed successfully"}
                log("SUCCESS", f"{tool} installed successfully: {ver}")
                counts["success"] += 1
        except Exception as e:
            log("WARNING", f"{tool} installation failed: {e}")


def refresh_path() -> None:
    try:
        import winreg

        def read(hive, subkey):
            with winreg.OpenKey(hive, subkey) as k:
                val, _ = winreg.QueryValueEx(k, "Path")
                return val

        machine = read(winreg.HKEY_LOCAL_MACHINE,
                       r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment")
        user = read(winreg.HKEY_CURRENT_USER, "Environment")
        os.environ["Path"] = machine + ";" + user
    except OSError:
        pass


def write_summary(status: dict, results: dict, counts: dict, started: float) -> int:
    log("INFO", "====================")
    log("INFO", "PREREQUISITES SUMMARY")
    log("INFO", f"Duration: {round(time.time() - started)}s")
    log("INFO", "PREREQUISITES STATUS:")
    for key, val in status.items():
        print(f"  {key}: {val['Status']} ({val['Version']}) - {val['Message']}")
    if results:
        log("INFO", "INSTALLATION RESULTS:")
        for key, val in results.items():
            print(f"  {key}: {val['Status']} ({val['Version']}) - {val['Message']}")
    log("SUCCESS", f"Successful Installations: {counts['success']}")
    log("ERROR", f"Failed Installations: {counts['failed']}")
    critical_missing = [k for k, v in status.items() if v["Status"] == "MISSING"]
    if not critical_missing:
        log("SUCCESS", "System is ready for cache cleaning operations!")
        return 0
    log("WARNING", f"Some critical prerequisites are missing: {', '.join(critical_missing)}. Run with --install-all to install them.")
    return 1


def main() -> None:
    parser = argparse.ArgumentParser(description="Prerequisites Checker and Installer")
    parser.add_argument("--check-only", action="store_true", help="Only check, never install (default)")
    parser.add_argument("--install-all", action="store_true", help="Install missing required tools (elevated)")
    parser.add_argument("--fix-issues", action="store_true", help="Alias of --install-all")
    parser.add_argument("--json", action="store_true", help="Emit JSON status")
    parser.add_argument("--dry-run", action="store_true", help="List what --install-all would install")
    args = parser.parse_args()

    started = time.time()
    log("INFO", "Starting Prerequisites Checker and Installer...")
    status: dict = {}
    for check in CHECKS.values():
        check(status)

    results: dict = {}
    counts = {"success": 0, "failed": 0}
    if args.install_all or args.fix_issues:
        if args.dry_run:
            for name, spec in INSTALLERS.items():
                if not which(spec["verify"]):
                    log("INFO", f"[DRY RUN] Would download and install {name} from {spec['url']}")
            log("INFO", "[DRY RUN] Would npm install -g pnpm/yarn if missing")
        else:
            log("INFO", "Installing missing prerequisites...")
            for name, spec in INSTALLERS.items():
                if not which(spec["verify"]):
                    install_tool(name, results, counts)
            install_optional(results, counts)
            log("INFO", "Re-checking prerequisites after installation...")
            for key in ("Node.js", "Python", "Git"):
                if key in CHECKS:
                    CHECKS[key](status)
            _check_managers(status)

    if args.json:
        print(json.dumps({"status": status, "installations": results}, indent=2))

    log("SUCCESS", "Prerequisites checker completed!")
    sys.exit(write_summary(status, results, counts, started))


if __name__ == "__main__":
    main()
