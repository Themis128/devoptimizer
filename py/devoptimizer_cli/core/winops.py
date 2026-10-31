"""
Windows operation helpers for the DevOptimizer CLI.

Subprocess/stdlib-based wrappers (schtasks, wevtutil/eventcreate, winreg) so
converted PowerShell scripts keep their functionality without PowerShell
itself. All process execution goes through core.executor (timeout + tree-kill
+ elevation support).
"""

import winreg
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from devoptimizer_cli.core.executor import run_command, run_elevated

# ---------------------------------------------------------------------------
# Scheduled tasks (schtasks.exe)
# ---------------------------------------------------------------------------

@dataclass
class TaskInfo:
    """One scheduled task's summary fields parsed from schtasks LIST output."""
    name: str
    status: str
    next_run: str
    last_run: str
    last_result: str


def _parse_task_blocks(output: str) -> list[TaskInfo]:
    """Parse `schtasks /Query /FO LIST /V` blocks into TaskInfo records.

    Field labels are locale-dependent; this parses English output, matching
    the key:value approach already used by commands/tasks.py.
    """
    tasks: list[TaskInfo] = []
    current: dict[str, str] = {}

    for line in output.splitlines():
        if line.startswith("TaskName:"):
            if current.get("TaskName"):
                tasks.append(_task_info_from(current))
                current = {}
            current["TaskName"] = line.split(":", 1)[1].strip()
        elif ":" in line and current:
            key, value = line.split(":", 1)
            current.setdefault(key.strip(), value.strip())

    if current.get("TaskName"):
        tasks.append(_task_info_from(current))
    return tasks


def _task_info_from(fields: dict[str, str]) -> TaskInfo:
    return TaskInfo(
        name=fields.get("TaskName", ""),
        status=fields.get("Status", ""),
        next_run=fields.get("Next Run Time", "Never"),
        last_run=fields.get("Last Run Time", "Never"),
        last_result=fields.get("Last Result", ""),
    )


async def query_tasks(prefix: str = "", timeout: int = 60) -> list[TaskInfo]:
    """List scheduled tasks, optionally filtered by name substring."""
    result = await run_command(
        ["schtasks.exe", "/Query", "/FO", "LIST", "/V"], timeout=timeout
    )
    if result.returncode != 0:
        return []
    tasks = _parse_task_blocks(result.stdout)
    if prefix:
        tasks = [t for t in tasks if prefix.lower() in t.name.lower()]
    return tasks


async def query_task(name: str, timeout: int = 30) -> TaskInfo | None:
    """Fetch one scheduled task by exact name (None if not registered)."""
    result = await run_command(
        ["schtasks.exe", "/Query", "/TN", name, "/FO", "LIST", "/V"], timeout=timeout
    )
    if result.returncode != 0:
        return None
    blocks = _parse_task_blocks(result.stdout)
    return blocks[0] if blocks else None


async def run_task(name: str, timeout: int = 30) -> bool:
    """Trigger a scheduled task run (`schtasks /Run`)."""
    result = await run_command(["schtasks.exe", "/Run", "/TN", name], timeout=timeout)
    return result.returncode == 0


async def delete_task(name: str, force: bool = True, timeout: int = 30) -> bool:
    """Delete a scheduled task (`schtasks /Delete`; force skips confirmation)."""
    args = ["schtasks.exe", "/Delete", "/TN", name]
    if force:
        args.append("/F")
    result = await run_command(args, timeout=timeout)
    return result.returncode == 0


async def register_task_from_xml(
    name: str, xml_path: str, timeout: int = 120
) -> tuple[bool, str]:
    """Register a task from an exported XML definition (requires elevation).

    Uses Register-ScheduledTask with the XML content, the same technique as
    commands/tasks.py, but via run_elevated so UAC is handled centrally.
    """
    xml = Path(xml_path).read_text(encoding="utf-8")
    script = (
        "$xml = @\"\n" + xml + "\n\"@\n"
        f'Register-ScheduledTask -Xml $xml -TaskName "{name}" -Force | Out-Null\n'
        "if ($?) { exit 0 } else { exit 1 }"
    )
    result = await run_elevated(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
        timeout=timeout,
    )
    return result.returncode == 0, (result.stdout + result.stderr).strip()


# ---------------------------------------------------------------------------
# Event log (eventcreate.exe)
# ---------------------------------------------------------------------------

_LEVEL_MAP = {
    "information": "INFORMATION",
    "informational": "INFORMATION",
    "warning": "WARNING",
    "warn": "WARNING",
    "error": "ERROR",
    "critical": "ERROR",
}


async def write_event(
    source: str,
    event_id: int,
    message: str,
    level: str = "information",
    timeout: int = 30,
) -> tuple[bool, str]:
    """Write an Application-log event (requires elevation on first use of a
    new source). `level` accepts information/warning/error (case-insensitive).

    Mirrors the `Write-Host`-style event codes used by the hub scripts
    (e.g. event 1005 on failure).
    """
    etype = _LEVEL_MAP.get(level.strip().lower(), "INFORMATION")
    result = await run_elevated(
        [
            "eventcreate.exe",
            "/L", "APPLICATION",
            "/SO", source,
            "/ID", str(event_id),
            "/T", etype,
            "/D", message[:1024],
        ],
        timeout=timeout,
    )
    return result.returncode == 0, (result.stdout + result.stderr).strip()


# ---------------------------------------------------------------------------
# Registry (winreg)
# ---------------------------------------------------------------------------

_HIVES = {
    "HKLM": winreg.HKEY_LOCAL_MACHINE,
    "HKCU": winreg.HKEY_CURRENT_USER,
    "HKCR": winreg.HKEY_CLASSES_ROOT,
    "HKU": winreg.HKEY_USERS,
}


def _split_hive(path: str) -> tuple[int, str]:
    hive_name, _, rest = path.partition("\\")
    hive = _HIVES.get(hive_name.upper())
    if hive is None:
        raise ValueError(f"Unsupported hive prefix: {hive_name!r} (use HKLM/HKCU/HKCR/HKU)")
    return hive, rest


def reg_get(path: str, value_name: str, default: Any | None = None) -> Any | None:
    """Read a registry value. `path` must start with HKLM\\, HKCU\\, etc."""
    hive, subkey = _split_hive(path)
    try:
        with winreg.OpenKey(hive, subkey, 0, winreg.KEY_READ) as key:
            data, _ = winreg.QueryValueEx(key, value_name)
            return data
    except FileNotFoundError:
        return default
    except PermissionError:
        return default


def reg_set(path: str, value_name: str, data: Any, reg_type: int = winreg.REG_SZ) -> bool:
    """Write a registry value (returns False on permission errors)."""
    hive, subkey = _split_hive(path)
    try:
        with winreg.CreateKey(hive, subkey) as key:
            winreg.SetValueEx(key, value_name, 0, reg_type, data)
            return True
    except PermissionError:
        return False


def reg_delete(path: str, value_name: str) -> bool:
    """Delete a registry value (returns False if missing or denied)."""
    hive, subkey = _split_hive(path)
    try:
        with winreg.OpenKey(hive, subkey, 0, winreg.KEY_SET_VALUE) as key:
            winreg.DeleteValue(key, value_name)
            return True
    except FileNotFoundError:
        return False
    except PermissionError:
        return False


# ---------------------------------------------------------------------------
# PowerShell shims for PS-retained operations
# ---------------------------------------------------------------------------

async def run_ps_command(script: str, timeout: int = 120) -> "object":
    """Run a short PowerShell snippet non-elevated (for CIM/WMI reads and
    PS-module one-liners that Phase-3 tranche-B ports keep as shims)."""
    return await run_command(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
        timeout=timeout,
    )


async def run_ps_command_elevated(script: str, timeout: int = 300) -> "object":
    """Elevated variant of run_ps_command (UAC handled by executor.run_elevated)."""
    return await run_elevated(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
        timeout=timeout,
    )
