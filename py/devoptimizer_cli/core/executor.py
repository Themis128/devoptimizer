"""
Async subprocess executor with timeout and tree-kill support.
"""

import asyncio
import json
import os
import signal
import sys
from dataclasses import dataclass
from typing import Any, Optional


@dataclass
class CommandResult:
    """Result of a command execution."""
    returncode: int
    stdout: str
    stderr: str
    timed_out: bool = False


async def run_command(
    cmd: list[str],
    timeout: int = 60,
    cwd: Optional[str] = None,
    env: Optional[dict[str, str]] = None,
    capture_output: bool = True,
) -> CommandResult:
    """Run a command with timeout and tree-kill on Windows."""
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    
    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE if capture_output else None,
        stderr=asyncio.subprocess.PIPE if capture_output else None,
        cwd=cwd,
        env=merged_env,
    )
    
    try:
        stdout, stderr = await asyncio.wait_for(
            process.communicate(),
            timeout=timeout
        )
        return CommandResult(
            returncode=process.returncode or 0,
            stdout=stdout.decode("utf-8", errors="replace") if stdout else "",
            stderr=stderr.decode("utf-8", errors="replace") if stderr else "",
        )
    except asyncio.TimeoutError:
        # Tree kill on timeout
        if sys.platform == "win32":
            # Use taskkill to kill process tree
            await asyncio.create_subprocess_exec(
                "taskkill", "/F", "/T", "/PID", str(process.pid),
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
        else:
            # On Unix, kill process group
            try:
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
            except ProcessLookupError:
                pass
        
        await process.wait()
        return CommandResult(
            returncode=124,
            stdout="",
            stderr=f"Command timed out after {timeout}s",
            timed_out=True,
        )


async def run_elevated(
    cmd: list[str],
    timeout: int = 120,
    cwd: Optional[str] = None,
) -> CommandResult:
    """Run a command with elevation (UAC on Windows, sudo on Unix)."""
    if sys.platform == "win32":
        # Use PowerShell Start-Process with -Verb RunAs for UAC elevation
        # We use -EncodedCommand with JSON to avoid hashtable binding issues
        import base64
        cmd_json = json.dumps(cmd)
        encoded = base64.b64encode(cmd_json.encode("utf-16le")).decode("ascii")
        ps_cmd = [
            "powershell", "-NoProfile", "-EncodedCommand", encoded
        ]
        return await run_command(ps_cmd, timeout=timeout, cwd=cwd)
    else:
        # Use sudo on Unix
        return await run_command(["sudo", "-n"] + cmd, timeout=timeout, cwd=cwd)


async def run_json_command(
    cmd: list[str],
    timeout: int = 60,
    cwd: Optional[str] = None,
) -> dict[str, Any]:
    """Run a command and parse JSON output."""
    result = await run_command(cmd, timeout=timeout, cwd=cwd)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {result.stderr}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Failed to parse JSON output: {e}")