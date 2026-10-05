"""
Health check result models for DevOptimizer CLI.
"""

from dataclasses import dataclass, field
from typing import Any, Optional
from pydantic import BaseModel


@dataclass
class HealthCheckResult:
    """Individual health check result."""
    name: str
    status: str  # "pass", "fail", "warn", "skip"
    message: str = ""
    details: dict[str, Any] = field(default_factory=dict)


@dataclass
class HealthResult:
    """Overall health check result."""
    overall_status: str  # "healthy", "degraded", "unhealthy"
    checks: list[HealthCheckResult] = field(default_factory=list)
    timestamp: str = ""
    duration_ms: float = 0.0
    
    def to_dict(self) -> dict[str, Any]:
        return {
            "overall_status": self.overall_status,
            "checks": [
                {
                    "name": c.name,
                    "status": c.status,
                    "message": c.message,
                    "details": c.details,
                }
                for c in self.checks
            ],
            "timestamp": self.timestamp,
            "duration_ms": self.duration_ms,
        }


class HealthCheckResultModel(BaseModel):
    """Pydantic model for health check result."""
    name: str
    status: str
    message: str = ""
    details: dict[str, Any] = {}


class HealthResultModel(BaseModel):
    """Pydantic model for overall health result."""
    overall_status: str
    checks: list[HealthCheckResultModel] = []
    timestamp: str = ""
    duration_ms: float = 0.0