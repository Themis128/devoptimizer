"""Behavioral tests for the converted scripts (scripts/py/*.py)."""

import importlib.util
import sys
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest

REPO = Path(__file__).resolve().parents[2]
SCRIPTS_PY = REPO / "scripts" / "py"


def _load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS_PY / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


wu = _load("wu_cleanup")
dc = _load("dev_cache")


def test_wu_constants():
    assert len(wu.WU_SERVICES) == 4
    assert len(wu.WU_DLLS) == 36
    assert "UseWUServer" in wu.PROBLEMATIC_VALUES


@pytest.mark.asyncio
async def test_wu_reset_dry_run(capsys):
    with patch.object(wu, "service_state", new=AsyncMock(return_value="Running")):
        assert await wu.reset_wu_components(dry_run=True) is True
    assert "Would stop services" in capsys.readouterr().out


@pytest.mark.asyncio
async def test_wu_clear_cache_dry_run(capsys):
    with patch.object(wu, "service_state", new=AsyncMock(return_value="Stopped")):
        await wu.clear_wu_cache(include_history=True, dry_run=True)
    out = capsys.readouterr().out
    assert "Would clear" in out and "DataStore" in out


@pytest.mark.asyncio
async def test_wu_fix_dry_run(capsys):
    assert await wu.fix_wu_errors(dry_run=True) is True
    assert "Would run: sfc" in capsys.readouterr().out


def test_dc_families():
    assert set(dc.FAMILIES) == {"nodejs", "python", "ide"}
    assert len(dc.FAMILIES["nodejs"]) == 7


@pytest.mark.asyncio
async def test_dc_clean_family_dry_run(capsys):
    stats = {"freed_mb": 0.0, "would_free_mb": 0.0, "count": 0, "errors": 0}
    await dc.clean_family("python", True, [], [], stats)
    out = capsys.readouterr().out
    assert "pip cache" in out
    assert stats["count"] == 0


def test_dc_pycache_finder(tmp_path):
    (tmp_path / "a" / "__pycache__").mkdir(parents=True)
    (tmp_path / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "__pycache__").mkdir(parents=True)
    assert len(dc.find_pycache(tmp_path, depth=6)) == 1
    assert len(dc.find_pycache(tmp_path, depth=10)) == 2


def test_dc_exclude():
    assert dc.should_exclude(
        Path(r"C:\x\y"), [Path(r"C:\x")], []
    )
    assert not dc.should_exclude(Path(r"C:\x\y"), [Path(r"C:\z")], [])
