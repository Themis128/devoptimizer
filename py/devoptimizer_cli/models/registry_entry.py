"""
Registry entry models for DevOptimizer CLI.
"""

from dataclasses import dataclass, field
from typing import Any, Optional
from pydantic import BaseModel, Field


@dataclass
class RegistryEntry:
    """Single entry in the script registry (dataclass version)."""
    name: str
    path: str
    category: str
    description: str = ""
    parameters: dict[str, Any] = field(default_factory=dict)
    elevation_required: bool = False
    tags: list[str] = field(default_factory=list)
    
    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "RegistryEntry":
        return cls(
            name=data.get("name", ""),
            path=data.get("path", ""),
            category=data.get("category", "uncategorized"),
            description=data.get("description", ""),
            parameters=data.get("parameters", {}),
            elevation_required=data.get("elevationRequired", False),
            tags=data.get("tags", []),
        )
    
    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "path": self.path,
            "category": self.category,
            "description": self.description,
            "parameters": self.parameters,
            "elevationRequired": self.elevation_required,
            "tags": self.tags,
        }


@dataclass
class Registry:
    """Script registry container (dataclass version)."""
    entries: dict[str, RegistryEntry] = field(default_factory=dict)
    version: int = 1
    generated_at: str = ""
    
    def filter_by_category(self, category: str) -> list[RegistryEntry]:
        return [entry for entry in self.entries.values() if entry.category == category]
    
    def filter_by_tag(self, tag: str) -> list[RegistryEntry]:
        return [entry for entry in self.entries.values() if tag in entry.tags]
    
    def get_elevated_commands(self) -> list[RegistryEntry]:
        return [entry for entry in self.entries.values() if entry.elevation_required]


class RegistryEntryModel(BaseModel):
    """Pydantic model for registry entry with validation."""
    name: str
    path: str
    category: str
    description: str = ""
    parameters: dict[str, Any] = {}
    elevationRequired: bool = Field(default=False, alias="elevation_required")
    tags: list[str] = []
    
    class Config:
        populate_by_name = True


class RegistryModel(BaseModel):
    """Pydantic model for registry with validation."""
    version: int = 1
    generatedAt: str = Field(default="", alias="generated_at")
    entries: dict[str, RegistryEntryModel] = {}
    
    class Config:
        populate_by_name = True