"""
Tests for win11-safe-cleanup command.
"""

import pytest
import asyncio
from unittest.mock import patch, AsyncMock, MagicMock
from pathlib import Path

from devoptimizer_cli.commands.cleanup.cleanup import (
    run,
    clean_directory,
    run_dev_cache_clean,
    clean_recycle_bin,
    run_docker_clean,
    CleanupParams,
)


class TestWin11SafeCleanup:
    """Test win11-safe-cleanup command."""
    
    @pytest.mark.asyncio
    async def test_clean_directory_nonexistent(self):
        """Test cleaning a non-existent directory."""
        result = await clean_directory(Path("/nonexistent"), "Test")
        assert result == 0
    
    @pytest.mark.asyncio
    async def test_run_dev_cache_clean_success(self):
        """Test successful dev cache clean."""
        with patch("devoptimizer_cli.commands.cleanup.cleanup.run_command") as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
            success, msg = await run_dev_cache_clean("pip", ["pip", "cache", "purge"])
            assert success is True
            assert msg == "cleaned"
    
    @pytest.mark.asyncio
    async def test_run_dev_cache_clean_failure(self):
        """Test failed dev cache clean."""
        with patch("devoptimizer_cli.commands.cleanup.cleanup.run_command") as mock_run:
            mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="error")
            success, msg = await run_dev_cache_clean("pip", ["pip", "cache", "purge"])
            assert success is False
            assert "exit 1" in msg
    
    @pytest.mark.asyncio
    async def test_run_dev_cache_clean_not_installed(self):
        """Test dev cache clean when tool not installed."""
        with patch("devoptimizer_cli.commands.cleanup.cleanup.run_command") as mock_run:
            mock_run.side_effect = FileNotFoundError("not found")
            success, msg = await run_dev_cache_clean("pip", ["pip", "cache", "purge"])
            assert success is False
            assert msg == "not installed"
    
    @pytest.mark.asyncio
    async def test_clean_recycle_bin_success(self):
        """Test successful recycle bin clean."""
        with patch("devoptimizer_cli.commands.cleanup.cleanup.run_command") as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
            success, msg = await clean_recycle_bin()
            assert success is True
            assert msg == "emptied"
    
    @pytest.mark.asyncio
    async def test_clean_recycle_bin_failure(self):
        """Test failed recycle bin clean."""
        with patch("devoptimizer_cli.commands.cleanup.cleanup.run_command") as mock_run:
            mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="access denied")
            success, msg = await clean_recycle_bin()
            assert success is False
            assert "exit 1" in msg
    
    @pytest.mark.asyncio
    async def test_run_docker_clean(self):
        """Test Docker clean commands."""
        with patch("devoptimizer_cli.commands.cleanup.cleanup.run_command") as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
            results = await run_docker_clean()
            assert len(results) == 2
            assert results[0][0] == "Build cache"
            assert results[0][1] == "cleaned"
            assert results[1][0] == "Dangling img"
            assert results[1][1] == "cleaned"
    
    @pytest.mark.asyncio
    async def test_run_dry_run(self):
        """Test dry run mode."""
        result = await run({
            "dry_run": True,
            "skip_docker": True,
            "skip_recycle_bin": True,
        })
        assert result.exit_code == 0
        assert "[DRY RUN]" in result.stdout
        assert "would free" in result.stdout
    
    @pytest.mark.asyncio
    async def test_run_with_skip_options(self):
        """Test run with skip options."""
        with patch("devoptimizer_cli.commands.cleanup.cleanup.run_dev_cache_clean") as mock_dev:
            with patch("devoptimizer_cli.commands.cleanup.cleanup.run_docker_clean") as mock_docker:
                with patch("devoptimizer_cli.commands.cleanup.cleanup.clean_recycle_bin") as mock_bin:
                    with patch("devoptimizer_cli.commands.cleanup.cleanup.clean_directory") as mock_clean:
                        with patch("devoptimizer_cli.commands.cleanup.cleanup.get_free_space_gb") as mock_space:
                            mock_dev.return_value = (True, "cleaned")
                            mock_docker.return_value = [("Build cache", "cleaned")]
                            mock_bin.return_value = (True, "emptied")
                            mock_clean.return_value = 1024 * 1024  # 1 MB
                            mock_space.side_effect = [100.0, 101.0]  # before, after
                            
                            result = await run({
                                "dry_run": False,
                                "skip_docker": True,
                                "skip_recycle_bin": True,
                            })
                            
                            assert result.exit_code == 0
                            assert "skipped (--skip-docker)" in result.stdout
                            assert "skipped (--skip-recycle-bin)" in result.stdout
                            assert "Freed on C:" in result.stdout


class TestCleanupParams:
    """Test CleanupParams dataclass."""
    
    def test_default_params(self):
        """Test default parameter values."""
        params = CleanupParams()
        assert params.dry_run is False
        assert params.skip_docker is False
        assert params.skip_recycle_bin is False
    
    def test_custom_params(self):
        """Test custom parameter values."""
        params = CleanupParams(dry_run=True, skip_docker=True, skip_recycle_bin=True)
        assert params.dry_run is True
        assert params.skip_docker is True
        assert params.skip_recycle_bin is True


if __name__ == "__main__":
    pytest.main([__file__, "-v"])