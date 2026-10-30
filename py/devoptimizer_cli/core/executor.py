"""
Async subprocess executor with timeout and tree-kill support.
"""

import asyncio
import contextlib
import json
import os
import signal
import sys
from dataclasses import dataclass
from typing import Any


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
    cwd: str | None = None,
    env: dict[str, str] | None = None,
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
            await asyncio.create_subprocess_exec(
                "taskkill", "/F", "/T", "/PID", str(process.pid),
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
        else:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)

        await process.wait()
        return CommandResult(
            returncode=124,
            stdout="",
            stderr=f"Command timed out after {timeout}s",
            timed_out=True,
        )


def _build_elevation_runner(cmd: list[str], out_path: str) -> str:
    """Build an ASCII-only runner script for run_elevated (PS 5.1 reads UTF-8-no-BOM as ANSI)."""

    def _ps(s: str) -> str:
        return s.replace("'", "''")

    payload = _ps(json.dumps(cmd))
    return "\n".join([
        "$ErrorActionPreference = 'Continue'",
        f"$j = '{payload}'",
        f"$out = '{_ps(out_path)}'",
        "$c = @() + (ConvertFrom-Json $j)",
        "if ($c.Count -gt 1) {",
        "    $args2 = @($c | Select-Object -Skip 1)",
        "    $log = & $c[0] @args2 2>&1",
        "} else {",
        "    $log = & $c[0] 2>&1",
        "}",
        "if ($null -ne $log) { $log | Out-String -Width 400 | Set-Content -Path $out -Encoding UTF8 }",
        "if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE } else { exit 0 }",
    ])


def _is_admin() -> bool:
    """Whether the current process token has the Administrator role."""
    try:
        import ctypes

        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


async def run_elevated(
    cmd: list[str],
    timeout: int = 120,
    cwd: str | None = None,
) -> CommandResult:
    """Run a command with elevation (UAC consent on Windows, sudo on Unix).

    Windows: the command array is embedded in a generated runner script that
    decodes it, executes it, records output, and exits with the child's real
    exit code. When the current process is not elevated the runner is launched
    via Start-Process -Verb RunAs (one UAC consent per call).
    """
    if sys.platform != "win32":
        return await run_command(["sudo", "-n"] + cmd, timeout=timeout, cwd=cwd)

    import tempfile
    from pathlib import Path

    work = Path(tempfile.mkdtemp(prefix="devopt-elev-"))
    runner = work / "runner.ps1"
    out_f = work / "out.txt"

    runner.write_text(_build_elevation_runner(cmd, str(out_f)) if cmd else "", encoding="ascii")
    if _is_admin():
        result = await run_command(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(runner)],
            timeout=timeout,
            cwd=cwd,
        )
    else:
        args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(runner)]
        ps_array = ", ".join("'" + a.replace("'", "''") + "'" for a in args)
        ps_script = (
            "$ErrorActionPreference = 'Stop'; "
            "try { $p = Start-Process powershell -Verb RunAs -WindowStyle Hidden -PassThru -Wait "
            "-ArgumentList " + ps_array + "; exit $p.ExitCode } "
            "catch { Write-Error $_.Exception.Message; exit 1223 }"
        )
        result = await run_command(
            ["powershell", "-NoProfile", "-Command", ps_script],
            timeout=timeout,
            cwd=cwd,
        )

    out = ""
    if out_f.exists():
        out = out_f.read_text(encoding="utf-8-sig", errors="replace")
        with contextlib.suppress(OSError):
            out_f.unlink()
    if out:
        result = CommandResult(
            returncode=result.returncode,
            stdout=(result.stdout + "\n" + out) if result.stdout else out,
            stderr=result.stderr,
        )
    return result


async def run_json_command(
    cmd: list[str],
    timeout: int = 60,
    cwd: str | None = None,
) -> dict[str, Any]:
    """Run a command and parse JSON output."""
    result = await run_command(cmd, timeout=timeout, cwd=cwd)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {result.stderr}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Failed to parse JSON output: {e}") from e
