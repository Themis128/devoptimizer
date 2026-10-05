"""
JSON logging with correlation IDs for DevOptimizer CLI.
"""

import json
import logging
import sys
import uuid
from datetime import datetime
from typing import Any, Optional


class JSONFormatter(logging.Formatter):
    """JSON log formatter with correlation ID support."""
    
    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        
        # Add correlation ID if present
        if hasattr(record, "correlation_id"):
            log_data["correlation_id"] = record.correlation_id
        
        # Add extra fields
        for key, value in record.__dict__.items():
            if key not in {
                "name", "msg", "args", "created", "filename", "funcName",
                "levelname", "levelno", "lineno", "module", "msecs",
                "message", "name", "pathname", "process", "processName",
                "relativeCreated", "thread", "threadName", "exc_info",
                "exc_text", "stack_info", "correlation_id"
            }:
                log_data[key] = value
        
        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        return json.dumps(log_data, ensure_ascii=False)


class ConsoleFormatter(logging.Formatter):
    """Human-readable console formatter."""
    
    def format(self, record: logging.LogRecord) -> str:
        correlation = getattr(record, "correlation_id", None)
        corr_str = f" [{correlation[:8]}]" if correlation else ""
        return f"{record.levelname:<8} {record.name}{corr_str} - {record.getMessage()}"


def setup_logging(
    level: str = "INFO",
    json_output: bool = False,
    log_file: Optional[str] = None,
) -> None:
    """Configure logging for the application."""
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, level.upper()))
    
    # Clear existing handlers
    root_logger.handlers.clear()
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    if json_output:
        console_handler.setFormatter(JSONFormatter())
    else:
        console_handler.setFormatter(ConsoleFormatter())
    root_logger.addHandler(console_handler)
    
    # File handler if specified
    if log_file:
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setFormatter(JSONFormatter())
        root_logger.addHandler(file_handler)


def get_logger(name: str) -> logging.Logger:
    """Get a logger instance."""
    return logging.getLogger(name)


class CorrelationLogger:
    """Logger wrapper that adds correlation ID to all messages."""
    
    def __init__(self, logger: logging.Logger, correlation_id: Optional[str] = None):
        self.logger = logger
        self.correlation_id = correlation_id or str(uuid.uuid4())[:8]
    
    def _log(self, level: int, msg: str, **kwargs: Any) -> None:
        extra = kwargs.pop("extra", {})
        extra["correlation_id"] = self.correlation_id
        self.logger.log(level, msg, extra=extra, **kwargs)
    
    def debug(self, msg: str, **kwargs: Any) -> None:
        self._log(logging.DEBUG, msg, **kwargs)
    
    def info(self, msg: str, **kwargs: Any) -> None:
        self._log(logging.INFO, msg, **kwargs)
    
    def warning(self, msg: str, **kwargs: Any) -> None:
        self._log(logging.WARNING, msg, **kwargs)
    
    def error(self, msg: str, **kwargs: Any) -> None:
        self._log(logging.ERROR, msg, **kwargs)
    
    def critical(self, msg: str, **kwargs: Any) -> None:
        self._log(logging.CRITICAL, msg, **kwargs)
    
    def child(self, name: str) -> "CorrelationLogger":
        """Create a child logger with same correlation ID."""
        child_logger = logging.getLogger(f"{self.logger.name}.{name}")
        return CorrelationLogger(child_logger, self.correlation_id)


def get_correlation_logger(name: str, correlation_id: Optional[str] = None) -> CorrelationLogger:
    """Get a correlation-aware logger."""
    return CorrelationLogger(logging.getLogger(name), correlation_id)