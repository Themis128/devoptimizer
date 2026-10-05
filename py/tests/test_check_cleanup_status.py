"""
Tests for check-cleanup-status and compact-vhdx migration
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from pathlib import Path

from devoptimizer_cli.commands.cleanup.cleanup import (
    _fmt_bytes,
    _ds,
    _chromium_cache_size,
    _vs_code_cache_size,
    _electron_cache_size,
    run_check_cleanup_status,
    run_compact_vhdx,
)


class TestFormatBytes:
    """Test _fmt_bytes helper function."""
    
    def test_gb(self):
        val, unit = _fmt_bytes(1024**3 * 2)
        assert val == "2.00"
        assert unit == "GB"
    
    def test_mb(self):
        val, unit = _fmt_bytes(1024**2 * 500)
        assert val == "500"
        assert unit == "MB"
    
    def test_zero(self):
        val, unit = _fmt_bytes(0)
        assert val == "0"
        assert unit == "MB"


class TestDS:
    """Test _ds function."""
    
    @pytest.mark.asyncio
    async def test_ds_nonexistent(self):
        result = await _ds(Path("/nonexistent"))
        assert result == 0
    
    @pytest.mark.asyncio
    async def test_ds_with_files(self, tmp_path):
        test_file = tmp_path / "test.txt"
        test_file.write_text("test content")
        
        result = await _ds(tmp_path)
        assert result == len("test content")


class TestChromiumCacheSize:
    """Test _chromium_cache_size function."""
    
    @pytest.mark.asyncio
    async def test_chromium_cache_nonexistent(self):
        result = await _chromium_cache_size(Path("/nonexistent"))
        assert result == 0
    
    @pytest.mark.asyncio
    async def test_chromium_cache_with_profiles(self, tmp_path):
        # Default profile
        default_dir = tmp_path / "Default"
        default_dir.mkdir()
        (default_dir / "Cache").mkdir()
        (default_dir / "Cache" / "file1").write_text("x" * 100)
        (default_dir / "Code Cache").mkdir()
        (default_dir / "Code Cache" / "file2").write_text("y" * 200)
        (default_dir / "GPUCache").mkdir()
        
        # Profile 1
        profile1 = tmp_path / "Profile 1"
        profile1.mkdir()
        (profile1 / "Cache").mkdir()
        (profile1 / "Cache" / "file3").write_text("z" * 300)
        
        result = await _chromium_cache_size(tmp_path)
        assert result == 600  # 100 + 200 + 300


class TestVscodeCacheSize:
    """Test _vs_code_cache_size function."""
    
    @pytest.mark.asyncio
    async def test_vscode_cache(self, tmp_path):
        for sub in ["Cache", "CachedData", "Code Cache"]:
            (tmp_path / sub).mkdir()
            (tmp_path / sub / "file").write_text("x" * 100)
        
        result = await _vs_code_cache_size(tmp_path)
        assert result == 300


class TestElectronCacheSize:
    """Test _electron_cache_size function."""
    
    @pytest.mark.asyncio
    async def test_electron_cache(self, tmp_path):
        for sub in ["Cache", "Code Cache"]:
            (tmp_path / sub).mkdir()
            (tmp_path / sub / "file").write_text("x" * 100)
        
        result = await _electron_cache_size(tmp_path, include_storage=True)
        assert result == 200


class TestRunCheckCleanupStatus:
    """Test run_check_cleanup_status function."""
    
    @pytest.mark.asyncio
    async def test_check_cleanup_status(self):
        with patch('devoptimizer_cli.commands.cleanup.cleanup._ds') as mock_ds:
            mock_ds.return_value = 1024 * 1024 * 100  # 100 MB
            
            with patch('devoptimizer_cli.commands.cleanup.cleanup._chromium_cache_size') as mock_chrome:
                mock_chrome.return_value = 1024 * 1024 * 50  # 50 MB
                
                with patch('devoptimizer_cli.commands.cleanup.cleanup._vs_code_cache_size') as mock_vscode:
                    mock_vscode.return_value = 1024 * 1024 * 20  # 20 MB
                    
                    with patch('devoptimizer_cli.commands.cleanup.cleanup._electron_cache_size') as mock_electron:
                        mock_electron.return_value = 1024 * 1024 * 10  # 10 MB
                        
                        with patch('devoptimizer_cli.commands.cleanup.cleanup.run_command') as mock_run:
                            mock_result = MagicMock()
                            mock_result.returncode = 1  # Docker not running
                            mock_run.return_value = mock_result
                            
                            with patch('psutil.disk_usage') as mock_disk:
                                mock_usage = MagicMock()
                                mock_usage.free = 1024**3 * 100
                                mock_usage.used = 1024**3 * 200
                                mock_usage.total = 1024**3 * 300
                                mock_disk.return_value = mock_usage
                                
                                result = await run_check_cleanup_status({})
                                
                                assert result.exit_code == 0
                                assert "Win11 Cleanup Assessment" in result.stdout
                                assert "Verdict" in result.stdout
                                assert result.data["cleanable_bytes"] > 0


class TestRunCompactVhdx:
    """Test run_compact_vhdx function."""
    
    @pytest.mark.asyncio
    async def test_compact_vhdx_not_found(self):
        result = await run_compact_vhdx({"vhdx_path": "/nonexistent.vhdx"})
        assert result.exit_code == 1
        assert "VHDX not found" in result.stderr
    
    @pytest.mark.asyncio
    async def test_compact_vhdx_not_admin(self, tmp_path):
        vhdx = tmp_path / "test.vhdx"
        vhdx.write_text("x" * (1024**3 * 10))  # 10 GB file
        
        with patch('ctypes.windll.shell32.IsUserAnAdmin') as mock_admin:
            mock_admin.return_value = False
            
            result = await run_compact_vhdx({"vhdx_path": str(vhdx)})
            assert result.exit_code == 1
            assert "Must run as Administrator" in result.stdout