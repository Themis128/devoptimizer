"""
Command models for DevOptimizer CLI.
"""

from dataclasses import dataclass, field
from typing import Any, Optional


@dataclass
class CommandParams:
    """Base class for command parameters."""
    pass


@dataclass
class CommandResult:
    """Result of a command execution."""
    exit_code: int
    stdout: str = ""
    stderr: str = ""
    data: dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "exit_code": self.exit_code,
            "stdout": self.stdout,
            "stderr": self.stderr,
            "data": self.data,
        }
    
    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "CommandResult":
        """Create from dictionary."""
        return cls(
            exit_code=data.get("exit_code", 0),
            stdout=data.get("stdout", ""),
            stderr=data.get("stderr", ""),
            data=data.get("data", {}),
        )