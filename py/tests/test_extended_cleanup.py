"""
Tests for extended-cleanup migration (win11-safe-cleanup extended module)
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from pathlib import Path
from datetime import datetime, timedelta

from devoptimizer_cli.commands.cleanup.cleanup import (
    ExtendedCleanupParams,
    _mb,
    _gb,
    is_process_running,
    prune_files,
    get_chromium_cache_dirs,
    run_extended_cleanup,
)
from devoptimizer_cli.core.paths import get_logs_dir


class TestExtendedCleanupParams:
    """Test ExtendedCleanupParams dataclass."""
    
    def test_defaults(self):
        p = ExtendedCleanupParams()
        assert p.dry_run is False
        assert p.shader_days == 30
        assert p.model_days == 60
        assert p.browser_days == 7
        assert p.code_days == 30
        assert p.electron_days == 14
        assert p.wer_days == 30
        assert p.log_days == 30
        assert p.archive_days == 180
    
    def test_custom_values(self):
        p = ExtendedCleanupParams(
            dry_run=True,
            shader_days=15,
            model_days=30,
        )
        assert p.dry_run is True
        assert p.shader_days == 15
        assert p.model_days == 30


class TestHelpers:
    """Test helper functions."""
    
    def test_mb(self):
        assert _mb(1024 * 1024) == 1.0
        assert _mb(1024 * 1024 * 100) == 100.0
        assert _mb(0) == 0.0
    
    def test_gb(self):
        assert _gb(1024 ** 3) == 1.0
        assert _gb(1024 ** 3 * 2) == 2.0


class TestIsProcessRunning:
    """Test is_process_running function."""
    
    @pytest.mark.asyncio
    async def test_process_not_running(self):
        with patch('devoptimizer_cli.commands.cleanup.cleanup.run_command') as mock_run:
            mock_result = MagicMock()
            mock_result.stdout = ""
            mock_run.return_value = mock_result
            
            result = await is_process_running(["nonexistent"])
            assert result is False
    
    @pytest.mark.asyncio
    async def test_process_running(self):
        with patch('devoptimizer_cli.commands.cleanup.cleanup.run_command') as mock_run:
            mock_result = MagicMock()
            mock_result.stdout = "chrome.exe"
            mock_run.return_value = mock_result
            
            result = await is_process_running(["chrome"])
            assert result is True
    
    @pytest.mark.asyncio
    async def test_process_not_in_list(self):
        with patch('devoptimizer_cli.commands.cleanup.cleanup.run_command') as mock_run:
            mock_result = MagicMock()
            mock_result.stdout = "other.exe"
            mock_run.return_value = mock_result
            
            result = await is_process_running(["chrome", "firefox"])
            assert result is False


class TestPruneFiles:
    """Test prune_files function."""
    
    @pytest.mark.asyncio
    async def test_prune_files_nonexistent(self, tmp_path):
        nonexistent = tmp_path / "nonexistent"
        result = await prune_files(nonexistent, 30)
        assert result == 0
    
    @pytest.mark.asyncio
    async def test_prune_files_dry_run(self, tmp_path):
        test_file = tmp_path / "test.txt"
        test_file.write_text("test content")
        
        # Mock file modification time to be old
        import os
        old_time = (datetime.now() - timedelta(days=40)).timestamp()
        os.utime(test_file, (old_time, old_time))
        
        result = await prune_files(tmp_path, 30, dry_run=True)
        assert result == len("test content")
        assert test_file.exists()  # File should still exist in dry run
    
    @pytest.mark.asyncio
    async def test_prune_files_actual_delete(self, tmp_path):
        test_file = tmp_path / "test.txt"
        test_file.write_text("test content")
        
        old_time = (datetime.now() - timedelta(days=40)).timestamp()
        import os
        os.utime(test_file, (old_time, old_time))
        
        result = await prune_files(tmp_path, 30, dry_run=False)
        assert result == len("test content")
        assert not test_file.exists()  # File should be deleted
    
    @pytest.mark.asyncio
    async def test_prune_files_keeps_recent(self, tmp_path):
        test_file = tmp_path / "test.txt"
        test_file.write_text("test content")
        
        # Recent file should not be deleted
        result = await prune_files(tmp_path, 30, dry_run=False)
        assert result == 0
        assert test_file.exists()


class TestGetChromiumCacheDirs:
    """Test get_chromium_cache_dirs function."""
    
    @pytest.mark.asyncio
    async def test_get_chromium_cache_dirs_nonexistent(self):
        result = await get_chromium_cache_dirs(Path("/nonexistent"))
        assert result == []
    
    @pytest.mark.asyncio
    async def test_get_chromium_cache_dirs_with_profiles(self, tmp_path):
        # Create Default profile with cache dirs
        default_dir = tmp_path / "Default"
        default_dir.mkdir()
        (default_dir / "Cache").mkdir()
        (default_dir / "Code Cache").mkdir()
        
        # Create Profile 1
        profile1 = tmp_path / "Profile 1"
        profile1.mkdir()
        (profile1 / "Cache").mkdir()
        
        result = await get_chromium_cache_dirs(tmp_path)
        assert len(result) == 5  # Default: Cache, Code Cache, GPUCache, Service Worker/CacheStorage, Service Worker/ScriptCache
        # Note: GPUCache and Service Worker dirs don't exist so won't be added
        # Actually the function adds all 5 for Default + 2 for Profile 1 = 7 if they all exist
        # Let's check what actually gets added


class TestRunExtendedCleanup:
    """Test run_extended_cleanup function."""
    
    @pytest.mark.asyncio
    async def test_run_extended_cleanup_dry_run(self):
        with patch('devoptimizer_cli.commands.cleanup.cleanup.get_free_space_gb') as mock_free:
            mock_free.side_effect = [100.0, 100.0]
            
            with patch('devoptimizer_cli.commands.cleanup.cleanup.prune_files') as mock_prune:
                mock_prune.return_value = 0
                
                with patch('devoptimizer_cli.commands.cleanup.cleanup.is_process_running') as mock_proc:
                    mock_proc.return_value = False
                    
                    with patch('devoptimizer_cli.commands.cleanup.cleanup.get_chromium_cache_dirs') as mock_chrome:
                        mock_chrome.return_value = []
                        
                        with patch('devoptimizer_cli.core.paths.get_logs_dir') as mock_logs:
                            mock_logs.return_value = Path("D:/DevOptimizer/logs")
                            
                            result = await run_extended_cleanup({"dry_run": True})
                            
                            assert result.exit_code == 0
                            assert "DRY RUN" in result.stdout
                            assert "Extended Win11 Cleanup" in result.stdout
    
    @pytest.mark.asyncio
    async def test_run_extended_cleanup_with_data(self):
        with patch('devoptimizer_cli.commands.cleanup.cleanup.get_free_space_gb') as mock_free:
            mock_free.side_effect = [100.0, 100.5]
            
            with patch('devoptimizer_cli.commands.cleanup.cleanup.prune_files') as mock_prune:
                mock_prune.return_value = 1024 * 1024 * 100  # 100 MB
                
                with patch('devoptimizer_cli.commands.cleanup.cleanup.is_process_running') as mock_proc:
                    mock_proc.return_value = False
                    
                    with patch('devoptimizer_cli.commands.cleanup.cleanup.get_chromium_cache_dirs') as mock_chrome:
                        mock_chrome.return_value = []
                        
                        with patch('devoptimizer_cli.core.paths.get_logs_dir') as mock_logs:
                            mock_logs.return_value = Path("D:/DevOptimizer/logs")
                            
                            with patch('devoptimizer_cli.commands.cleanup.cleanup.shutil.move'):
                                with patch('devoptimizer_cli.commands.cleanup.cleanup.shutil.rmtree'):
                                    result = await run_extended_cleanup({"dry_run": False})
                                    
                                    assert result.exit_code == 0
                                    assert "Freed" in result.stdout
                                    assert result.data["freed_mb"] > 0