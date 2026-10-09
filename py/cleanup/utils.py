"""Common utilities for DevOptimizer cleanup scripts."""
import os
import sys
import shutil
import subprocess
import platform
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Optional, Callable
import logging

# ─── Color output ────────────────────────────────────────────────
class Colors:
    """ANSI color codes for Windows (with colorama fallback)."""
    RESET = "\033[0m"
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN = "\033[96m"
    GRAY = "\033[90m"
    DARK_GRAY = "\033[90m"
    WHITE = "\033[97m"

    @classmethod
    def enable(cls):
        """Enable ANSI colors on Windows."""
        if platform.system() == "Windows":
            try:
                import colorama
                colorama.init()
            except ImportError:
                # Try to enable via os.system
                os.system("")


def fmt_bytes(bytes_val: int, unit: str = "auto") -> str:
    """Format bytes to human readable string."""
    units = ["B", "KB", "MB", "GB", "TB"]
    if unit != "auto":
        idx = units.index(unit.upper())
        return f"{bytes_val / (1024 ** idx):.1f} {unit}"
    
    for u in units:
        if bytes_val < 1024 or u == "TB":
            return f"{bytes_val:.1f} {u}"
        bytes_val /= 1024
    return f"{bytes_val:.1f} TB"


def mb(bytes_val: int) -> float:
    """Convert bytes to MB (rounded to 1 decimal)."""
    return round(bytes_val / (1024 * 1024), 1)


def gb(bytes_val: int) -> float:
    """Convert bytes to GB (rounded to 2 decimals)."""
    return round(bytes_val / (1024 ** 3), 2)


def get_free_space(path: str) -> int:
    """Get free space in bytes for a drive/path."""
    try:
        usage = shutil.disk_usage(path)
        return usage.free
    except Exception:
        return 0


def get_used_space(path: str) -> int:
    """Get used space in bytes for a drive/path."""
    try:
        usage = shutil.disk_usage(path)
        return usage.used
    except Exception:
        return 0


def get_total_space(path: str) -> int:
    """Get total space in bytes for a drive/path."""
    try:
        usage = shutil.disk_usage(path)
        return usage.total
    except Exception:
        return 0


def dir_size(path: Path) -> int:
    """Calculate total size of files under path (recursive)."""
    if not path.exists():
        return 0
    total = 0
    try:
        for entry in path.rglob("*"):
            if entry.is_file():
                try:
                    total += entry.stat().st_size
                except (OSError, PermissionError):
                    pass
    except (OSError, PermissionError):
        pass
    return total


def prune_files(path: Path, days: int, dry_run: bool = False) -> int:
    """Delete files under path older than days. Returns bytes freed."""
    if not path.exists():
        return 0
    
    cutoff = datetime.now() - timedelta(days=days)
    freed = 0
    
    try:
        for entry in path.rglob("*"):
            if entry.is_file():
                try:
                    mtime = datetime.fromtimestamp(entry.stat().st_mtime)
                    if mtime < cutoff:
                        size = entry.stat().st_size
                        if not dry_run:
                            entry.unlink(missing_ok=True)
                        freed += size
                except (OSError, PermissionError):
                    pass
    except (OSError, PermissionError):
        pass
    
    return freed


def run_command(cmd: List[str], capture: bool = True, timeout: int = 60) -> subprocess.CompletedProcess:
    """Run a command and return CompletedProcess."""
    try:
        return subprocess.run(
            cmd,
            capture_output=capture,
            text=True,
            timeout=timeout,
            shell=False
        )
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(cmd, -1, "", "Timeout")
    except FileNotFoundError:
        return subprocess.CompletedProcess(cmd, -1, "", f"Command not found: {cmd[0]}")
    except Exception as e:
        return subprocess.CompletedProcess(cmd, -1, "", str(e))


def is_process_running(names: List[str]) -> bool:
    """Check if any process with given names is running."""
    try:
        import psutil
        for proc in psutil.process_iter(['name']):
            if proc.info['name'] and proc.info['name'].lower() in [n.lower() for n in names]:
                return True
    except ImportError:
        # Fallback using tasklist
        try:
            result = run_command(["tasklist", "/FI", f"IMAGENAME eq {names[0]}.exe"])
            return names[0].lower() in result.stdout.lower()
        except Exception:
            pass
    return False


def get_chromium_cache_dirs(user_data_root: Path) -> List[Path]:
    """Get Chromium-based browser cache directories."""
    dirs = []
    if not user_data_root.exists():
        return dirs
    
    profiles = ["Default"]
    try:
        for entry in user_data_root.iterdir():
            if entry.is_dir() and entry.name.startswith("Profile "):
                profiles.append(entry.name)
    except (OSError, PermissionError):
        pass
    
    cache_subdirs = [
        "Cache", "Code Cache", "GPUCache",
        "Service Worker/CacheStorage", "Service Worker/ScriptCache"
    ]
    
    for profile in profiles:
        for sub in cache_subdirs:
            p = user_data_root / profile / sub
            if p.exists():
                dirs.append(p)
    
    return dirs


# ─── Output helpers ──────────────────────────────────────────────
def write_header(msg: str):
    print(f"{Colors.MAGENTA}\n=== {msg} ==={Colors.RESET}")


def write_step(msg: str):
    print(f"{Colors.CYAN}> {msg}{Colors.RESET}")


def write_done(msg: str):
    print(f"  {Colors.GREEN}[OK]{Colors.RESET} {msg}")


def write_warn(msg: str):
    print(f"  {Colors.YELLOW}[WARN]{Colors.RESET} {msg}")


def write_info(msg: str):
    print(f"  {Colors.GRAY}[INFO]{Colors.RESET} {msg}")


def write_error(msg: str):
    print(f"  {Colors.RED}[ERROR]{Colors.RESET} {msg}")


# ─── Windows-specific paths ──────────────────────────────────────
def get_env_path(var: str) -> Optional[Path]:
    """Get environment variable as Path."""
    val = os.environ.get(var)
    return Path(val) if val else None


# Common Windows paths
TEMP = get_env_path("TEMP")
LOCALAPPDATA = get_env_path("LOCALAPPDATA")
APPDATA = get_env_path("APPDATA")
USERPROFILE = get_env_path("USERPROFILE")
SYSTEMROOT = get_env_path("SYSTEMROOT") or Path("C:/Windows")


def safe_path(*parts) -> Optional[Path]:
    """Safely join path parts, returning None if any part is None."""
    valid_parts = [p for p in parts if p is not None]
    if not valid_parts:
        return None
    return Path(*valid_parts)