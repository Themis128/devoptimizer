"""
Path resolution utilities for DevOptimizer CLI.
"""

import os
from pathlib import Path
from typing import Optional


def get_repo_root() -> Path:
    """Get the DevOptimizer repository root."""
    # Check environment variable first
    if root := os.environ.get("DEVOPTIMIZER_ROOT"):
        return Path(root)
    
    # Default to D:\DevOptimizer
    default_root = Path("D:/DevOptimizer")
    if default_root.exists():
        return default_root
    
    # Try to find from current file location
    current = Path(__file__).resolve()
    for parent in current.parents:
        if (parent / "py" / "devoptimizer_cli").exists():
            return parent
    
    return default_root


def get_scripts_dir() -> Path:
    """Get the scripts directory."""
    return get_repo_root() / "scripts"


def get_registry_path() -> Path:
    """Get the script registry path."""
    return get_repo_root() / "registry" / "script-registry.json"


def get_configs_dir() -> Path:
    """Get the configs directory."""
    return get_repo_root() / "configs"


def get_logs_dir() -> Path:
    """Get the logs directory."""
    return get_repo_root() / "logs"


def resolve_script_path(script_name: str) -> Optional[Path]:
    """Resolve a script name to its full path."""
    scripts_dir = get_scripts_dir()
    
    # Check common extensions
    for ext in [".ps1", ".bat", ".cmd", ".py"]:
        path = scripts_dir / f"{script_name}{ext}"
        if path.exists():
            return path
    
    # Check without extension
    path = scripts_dir / script_name
    if path.exists():
        return path
    
    # Search recursively
    for ext in [".ps1", ".bat", ".cmd", ".py"]:
        matches = list(scripts_dir.rglob(f"{script_name}{ext}"))
        if matches:
            return matches[0]
    
    return None