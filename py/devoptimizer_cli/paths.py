"""
Path validation for CLI result/report writes.

Every CLI file write goes through safe_open_write, which resolves the target
path, rejects any '..' traversal component, and enforces containment inside the
DevOptimizer repository root before opening it. Defense-in-depth against path
traversal (CWE-22): report paths are either computed constants inside the repo
or operator-supplied --output values, and both are now constrained to the repo
tree.
"""

import os
from pathlib import Path
from typing import IO, Union

REPO_ROOT = Path(__file__).resolve().parents[2]


def validate_output_path(path: Union[str, Path]) -> Path:
    """Resolve *path*, reject '..' traversal components, and require the result
    to stay inside the repository root."""
    resolved = Path(path).resolve()

    # Explicit traversal invariant: resolve() collapses '..' chains, but any
    # surviving '..' component is rejected outright.
    if any(part == '..' for part in resolved.parts):
        raise ValueError(f"path contains a '..' traversal component: '{resolved}'")

    # Containment invariant: the resolved path must be the repo root itself or
    # a descendant of it.
    if resolved != REPO_ROOT and REPO_ROOT not in resolved.parents:
        raise ValueError(
            f"output path '{resolved}' is outside the DevOptimizer repository root '{REPO_ROOT}'"
        )
    return resolved


def safe_open_write(path: Union[str, Path]) -> IO:
    """Validate *path* (see validate_output_path), create its parent directory,
    and return a write-mode file handle. Use as a context manager."""
    resolved = validate_output_path(path)
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved.open('w', encoding='utf-8')
