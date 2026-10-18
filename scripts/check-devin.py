#!/usr/bin/env python3
"""
check-devin.py - Python version of check-devin.ps1
Gets the most recent log files in the Devin directory.
"""

import os
import sys
from pathlib import Path
from datetime import datetime

def main():
    """Main function to list recent Devin log files."""
    devin_dir = Path(r'C:\Users\tbaltzakis\AppData\Local\Devin')
    if not devin_dir.exists():
        print(f"Directory not found: {devin_dir}")
        return 1

    # Collect all files recursively that match the criteria
    files = []
    for file_path in devin_dir.rglob('*'):
        if file_path.is_file():
            # Check extension or name containing 'log' (case-insensitive)
            if file_path.suffix.lower() == '.log' or 'log' in file_path.name.lower():
                try:
                    stat = file_path.stat()
                    files.append({
                        'FullName': str(file_path.resolve()),
                        'Length': stat.st_size,
                        'LastWriteTime': datetime.fromtimestamp(stat.st_mtime)
                    })
                except (OSError, PermissionError):
                    # Skip files we can't access
                    continue

    # Sort by LastWriteTime descending
    files.sort(key=lambda x: x['LastWriteTime'], reverse=True)

    # Take the first 10
    top_files = files[:10]

    # Print header
    print(f"{'FullName':<60} {'Length':>10} {'LastWriteTime':<20}")
    print("-" * 100)
    for f in top_files:
        # Format the datetime to match PowerShell's default output
        time_str = f['LastWriteTime'].strftime('%Y-%m-%d %H:%M:%S')
        print(f"{f['FullName']:<60} {f['Length']:>10} {time_str:<20}")

    return 0

if __name__ == '__main__':
    sys.exit(main())