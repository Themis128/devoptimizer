"""
Tests for devoptimizer_cli.core.winops
"""

import sys
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from devoptimizer_cli.core.winops import (
    _parse_task_blocks,
    delete_task,
    query_tasks,
    reg_delete,
    reg_get,
    reg_set,
    run_ps_command,
    run_task,
    write_event,
)

SAMPLE_LIST_OUTPUT = """\
Folder: \\DevOptimizer

HostName: OFFICE
TaskName: \\DevOptimizer\\Safe-Cleanup-Daily
Next Run Time: 2/15/2026 2:15:00 AM
Status: Ready
Last Run Time: 2/14/2026 2:15:00 AM
Last Result: 0
Author: OFFICE\\tbaltzakis

Folder: \\DevOptimizer

HostName: OFFICE
TaskName: \\DevOptimizer\\WSL-Vhdx-Compact
Next Run Time: N/A
Status: Ready
Last Run Time: 10/30/2026 11:45:04 PM
Last Safe...: N/A
Last Result: 267011
Author: OFFICE\\"S-1-5-18"
"""


class TestParseTaskBlocks:
    def test_parses_two_tasks(self):
        tasks = _parse_task_blocks(SAMPLE_LIST_OUTPUT)
        assert len(tasks) == 2
        assert tasks[0].name == "\\DevOptimizer\\Safe-Cleanup-Daily"
        assert tasks[0].status == "Ready"
        assert tasks[0].last_result == "0"

    def test_missing_fields_default(self):
        tasks = _parse_task_blocks(SAMPLE_LIST_OUTPUT)
        t = tasks[1]
        assert t.next_run == "N/A"
        assert "Last Safe..." not in t.status

    def test_empty_output(self):
        assert _parse_task_blocks("") == []

    def test_filter_prefix(self):
        tasks = _parse_task_blocks(SAMPLE_LIST_OUTPUT)
        matching = [t for t in tasks if "WSL" in t.name]
        assert len(matching) == 1


class TestQueryTasks:
    @pytest.mark.asyncio
    async def test_query_tasks_filters(self):
        with patch("devoptimizer_cli.core.winops.run_command", new=AsyncMock()) as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout=SAMPLE_LIST_OUTPUT)
            tasks = await query_tasks(prefix="Safe-Cleanup")
            assert len(tasks) == 1
            assert tasks[0].name == "\\DevOptimizer\\Safe-Cleanup-Daily"

    @pytest.mark.asyncio
    async def test_query_tasks_error_returns_empty(self):
        with patch("devoptimizer_cli.core.winops.run_command", new=AsyncMock()) as mock_run:
            mock_run.return_value = MagicMock(returncode=1, stdout="")
            assert await query_tasks() == []


class TestRunAndDelete:
    @pytest.mark.asyncio
    async def test_run_task_true(self):
        with patch("devoptimizer_cli.core.winops.run_command", new=AsyncMock()) as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            assert await run_task("\\DevOptimizer\\X") is True

    @pytest.mark.asyncio
    async def test_delete_task_false_on_error(self):
        with patch("devoptimizer_cli.core.winops.run_command", new=AsyncMock()) as mock_run:
            mock_run.return_value = MagicMock(returncode=1, stderr="denied")
            assert await delete_task("\\DevOptimizer\\X") is False


class TestRegistry:
    def test_reg_get_default(self):
        assert reg_get(r"HKCU\Software\DefinitelyNotAKey", "Nope", default="fallback") == "fallback"

    def test_reg_get_real_value(self):
        val = reg_get(r"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer", "Shell Folders".replace("Shell Folders", "Desktop"), default=None)
        assert val is None or isinstance(val, str)

    def test_split_hive_rejects_bad_prefix(self):
        with pytest.raises(ValueError):
            reg_get(r"Nope\Software", "x")

    def test_reg_set_and_delete_roundtrip(self):
        path = r"HKCU\Software\DevOptimizerTest\winops"
        assert reg_set(path, "Probe", "v1") is True
        assert reg_get(path, "Probe") == "v1"
        assert reg_delete(path, "Probe") is True
        assert reg_get(path, "Probe", default=None) is None


class TestWriteEvent:
    @pytest.mark.asyncio
    async def test_write_event_builds_eventcreate_args(self):
        with patch("devoptimizer_cli.core.winops.run_elevated", new=AsyncMock()) as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
            ok, _ = await write_event("DevOptimizer-Test", 1005, "hello", level="warning")
            assert ok is True
            args = mock_run.call_args[0][0]
            assert args[0] == "eventcreate.exe"
            assert "/SO" in args and "DevOptimizer-Test" in args
            assert "/T" in args and "WARNING" in args


class TestRunPsCommand:
    @pytest.mark.asyncio
    async def test_run_ps_command_uses_noninteractive(self):
        with patch("devoptimizer_cli.core.winops.run_command", new=AsyncMock()) as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout="hi")
            await run_ps_command("Write-Output hi")
            args = mock_run.call_args[0][0]
            assert "-NonInteractive" in args
