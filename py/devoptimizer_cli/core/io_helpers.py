"""
Safe I/O helpers for DevOptimizer CLI.
"""

from pathlib import Path
from typing import TextIO, Union
from contextlib import contextmanager


@contextmanager
def safe_open_write(filepath: Union[str, Path], mode: str = 'w', encoding: str = 'utf-8') -> TextIO:
    """
    Safely open a file for writing with directory creation.
    
    Args:
        filepath: Path to the file to write
        mode: File open mode (default 'w')
        encoding: Text encoding (default 'utf-8')
        
    Yields:
        Open file handle
    """
    path = Path(filepath)
    path.parent.mkdir(parents=True, exist_ok=True)
    
    # Use 'x' mode for exclusive creation to avoid overwriting
    # Fall back to 'w' if file exists
    actual_mode = mode
    if 'x' in mode and path.exists():
        actual_mode = mode.replace('x', 'w')
    
    with path.open(actual_mode, encoding=encoding) as f:
        yield f


@contextmanager
def safe_open_read(filepath: Union[str, Path], mode: str = 'r', encoding: str = 'utf-8') -> TextIO:
    """
    Safely open a file for reading.
    
    Args:
        filepath: Path to the file to read
        mode: File open mode (default 'r')
        encoding: Text encoding (default 'utf-8')
        
    Yields:
        Open file handle
    """
    path = Path(filepath)
    with path.open(mode, encoding=encoding) as f:
        yield f


def safe_write_json(filepath: Union[str, Path], data: dict, indent: int = 2) -> None:
    """
    Safely write JSON data to a file.
    
    Args:
        filepath: Path to the file to write
        data: Dictionary to serialize
        indent: JSON indentation (default 2)
    """
    with safe_open_write(filepath) as f:
        import json
        json.dump(data, f, indent=indent)


def safe_read_json(filepath: Union[str, Path]) -> dict:
    """
    Safely read JSON data from a file.
    
    Args:
        filepath: Path to the file to read
        
    Returns:
        Parsed JSON dictionary
    """
    with safe_open_read(filepath) as f:
        import json
        return json.load(f)