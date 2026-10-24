"""
Tests for devoptimizer_cli.core module
"""

import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch, call
import pytest

# Ensure we can import from the package
sys.path.insert(0, str(Path(__file__).parent.parent))

from devoptimizer_cli.core_module import (
    initialize_devoptimizer,
    start_performance_collection,
    stop_performance_collection,
    start_etw_trace,
    stop_etw_trace,
    export_event_logs,
    install_dev_tools,
    get_system_metrics,
    get_system_metrics_dict,
    SystemMetrics,
    DEVOPTIMIZER_ROOT,
    REQUIRED_DIRS,
    DEFAULT_COUNTERS,
    run_command,
)


class TestCoreConstants:
    """Test module constants"""

    def test_devoptimizer_root(self):
        assert DEVOPTIMIZER_ROOT == Path("D:/DevOptimizer")

    def test_required_dirs(self):
        assert isinstance(REQUIRED_DIRS, list)
        assert len(REQUIRED_DIRS) >= 10
        assert "bin" in REQUIRED_DIRS
        assert "ps" in REQUIRED_DIRS
        assert "py" in REQUIRED_DIRS

    def test_default_counters(self):
        assert isinstance(DEFAULT_COUNTERS, list)
        assert len(DEFAULT_COUNTERS) >= 8
        assert r"\\Processor(_Total)\\% Processor Time" in DEFAULT_COUNTERS
        assert r"\\Memory\\Available MBytes" in DEFAULT_COUNTERS


class TestRunCommand:
    """Test run_command helper"""

    @patch("devoptimizer_cli.core_module.subprocess.run")
    def test_run_command_success(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="success",
            stderr=""
        )
        result = run_command(["echo", "test"])
        assert result.returncode == 0
        assert result.stdout == "success"

    @patch("devoptimizer_cli.core_module.subprocess.run")
    def test_run_command_file_not_found(self, mock_run):
        mock_run.side_effect = FileNotFoundError("Command not found")
        result = run_command(["nonexistent"])
        assert result.returncode == 1
        assert "Command not found" in result.stderr

    @patch("devoptimizer_cli.core_module.subprocess.run")
    def test_run_command_exception(self, mock_run):
        mock_run.side_effect = Exception("Some error")
        result = run_command(["cmd"])
        assert result.returncode == 1
        assert "Some error" in result.stderr


class TestInitializeDevOptimizer:
    """Test initialize_devoptimizer function"""

    @patch("devoptimizer_cli.core_module.console.print")
    @patch("devoptimizer_cli.core_module.Path.mkdir")
    @patch("devoptimizer_cli.core_module.Path.exists", return_value=False)
    def test_initialize_creates_dirs(self, mock_exists, mock_mkdir, mock_print):
        result = initialize_devoptimizer()
        assert result is True
        assert mock_mkdir.call_count >= len(REQUIRED_DIRS)

    @patch("devoptimizer_cli.core_module.console.print")
    @patch("devoptimizer_cli.core_module.Path.exists", return_value=True)
    def test_initialize_dirs_exist(self, mock_exists, mock_print):
        result = initialize_devoptimizer()
        assert result is True


class TestPerformanceCollection:
    """Test performance counter collection"""

    @patch("devoptimizer_cli.core_module.run_command")
    @patch("devoptimizer_cli.core_module.Path.mkdir")
    @patch("devoptimizer_cli.core_module.Path.write_text")
    def test_start_performance_collection_default(self, mock_write_text, mock_mkdir, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        
        result = start_performance_collection()
        
        assert result["status"] == "Running"
        assert "session_name" in result
        assert "output_path" in result

    @patch("devoptimizer_cli.core_module.run_command")
    @patch("devoptimizer_cli.core_module.Path.mkdir")
    @patch("devoptimizer_cli.core_module.Path.write_text")
    def test_start_performance_collection_with_duration(self, mock_write_text, mock_mkdir, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        
        result = start_performance_collection(duration=60)
        
        assert result["status"] == "Running"

    @patch("devoptimizer_cli.core_module.run_command")
    def test_stop_performance_collection(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        
        result = stop_performance_collection()
        
        assert result is True


class TestETWTrace:
    """Test ETW tracing functions"""

    @patch("devoptimizer_cli.core_module.run_command")
    def test_start_etw_trace_valid_profile(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        
        result = start_etw_trace(profile="CPU", duration=0)
        
        assert result["status"] == "Running"
        assert result["profile"] == "CPU"

    @patch("devoptimizer_cli.core_module.run_command")
    def test_start_etw_trace_invalid_profile(self, mock_run):
        result = start_etw_trace(profile="InvalidProfile")
        
        assert result["status"] == "Failed"
        assert "Invalid profile" in result["error"]

    @patch("devoptimizer_cli.core_module.run_command")
    def test_stop_etw_trace(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        
        result = stop_etw_trace()
        
        assert result is not None
        assert "trace_" in result
        assert ".etl" in result


class TestExportEventLogs:
    """Test event log export"""

    @patch("devoptimizer_cli.core_module.run_command")
    @patch("devoptimizer_cli.core_module.Path.mkdir")
    def test_export_event_logs_default(self, mock_mkdir, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        
        result = export_event_logs()
        
        assert isinstance(result, list)
        assert len(result) >= 3  # System, Application, Diagnostics


class TestInstallDevTools:
    """Test development tools installation"""

    @patch("devoptimizer_cli.core_module.Path.exists", return_value=True)
    @patch("builtins.open", new_callable=MagicMock)
    @patch("devoptimizer_cli.core_module.run_command")
    def test_install_dev_tools(self, mock_run, mock_open, mock_exists):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        
        # Mock the JSON file content
        mock_file = MagicMock()
        mock_file.__enter__.return_value = mock_file
        mock_file.read.return_value = json.dumps({
            "packages": [
                {"name": "TestPackage", "id": "TestPackage.Test", "category": "test"}
            ]
        })
        mock_open.return_value = mock_file
        
        result = install_dev_tools()
        
        assert result["status"] == "Completed"
        assert "packages" in result


class TestSystemMetrics:
    """Test system metrics collection"""

    @patch("devoptimizer_cli.core_module.run_command")
    def test_get_system_metrics_dict(self, mock_run):
        # Mock all the powershell calls
        mock_results = {
            "cpu": MagicMock(returncode=0, stdout="25.5"),
            "proc": MagicMock(returncode=0, stdout="150"),
            "mem_total": MagicMock(returncode=0, stdout="32.0"),
            "mem_avail": MagicMock(returncode=0, stdout="16.5"),
            "mem_commit": MagicMock(returncode=0, stdout="20.0"),
            "disk_read": MagicMock(returncode=0, stdout="1024000"),
            "disk_write": MagicMock(returncode=0, stdout="512000"),
            "net": MagicMock(returncode=0, stdout="Ethernet=1000\nWiFi=500"),
        }
        
        call_count = [0]
        
        def mock_run_side_effect(cmd, *args, **kwargs):
            call_count[0] += 1
            if call_count[0] == 1:
                return mock_results["cpu"]
            elif call_count[0] == 2:
                return mock_results["proc"]
            elif call_count[0] == 3:
                return mock_results["mem_total"]
            elif call_count[0] == 4:
                return mock_results["mem_avail"]
            elif call_count[0] == 5:
                return mock_results["mem_commit"]
            elif call_count[0] == 6:
                return mock_results["disk_read"]
            elif call_count[0] == 7:
                return mock_results["disk_write"]
            elif call_count[0] == 8:
                return mock_results["net"]
            return MagicMock(returncode=1, stdout="", stderr="error")
        
        mock_run.side_effect = mock_run_side_effect
        
        result = get_system_metrics_dict()
        
        assert "timestamp" in result
        assert "cpu_usage" in result
        assert "cpu_processes" in result
        assert "memory_total_gb" in result
        assert "memory_available_gb" in result
        assert "memory_committed_gb" in result
        assert "disk_read_bytes_per_sec" in result
        assert "disk_write_bytes_per_sec" in result
        assert "network_interfaces" in result
        assert result["cpu_usage"] == 25.5
        assert result["cpu_processes"] == 150
        assert result["memory_total_gb"] == 32.0
        assert "Ethernet" in result["network_interfaces"]
        assert "WiFi" in result["network_interfaces"]

    @patch("devoptimizer_cli.core_module.run_command")
    def test_get_system_metrics_failure(self, mock_run):
        # When all calls fail, it should return dict with zeros
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="error")
        
        result = get_system_metrics_dict()
        
        # On failure, it returns dict with zero values
        assert isinstance(result, dict)
        assert "cpu_usage" in result
        assert result["cpu_usage"] == 0.0


class TestSystemMetricsDataclass:
    """Test SystemMetrics dataclass"""

    def test_system_metrics_creation(self):
        metrics = SystemMetrics(
            timestamp=Path("test"),
            cpu_usage=50.0,
            cpu_processes=100,
            memory_total_gb=32.0,
            memory_available_gb=16.0,
            memory_committed_gb=20.0,
            disk_read_bytes_per_sec=1000000,
            disk_write_bytes_per_sec=500000,
            network_interfaces={"Ethernet": 1000.0}
        )
        
        assert metrics.cpu_usage == 50.0
        assert metrics.cpu_processes == 100
        assert metrics.memory_total_gb == 32.0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])