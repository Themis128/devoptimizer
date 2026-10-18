#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys

def main():
    parser = argparse.ArgumentParser(description='Check syntax of all PowerShell scripts.')
    parser.add_argument('RootPath', nargs='?', default=os.getcwd(), help='Root directory to scan for .ps1 files. Defaults to current directory.')
    args = parser.parse_args()

    root_path = args.RootPath
    # Normalize the root path to avoid issues with trailing slashes
    root_path = os.path.normpath(root_path)

    # Directories to exclude (as strings to check in the path)
    excluded_dirs = ['\\backups\\', '\\backup-', '\\logs\\', '\\node_modules\\', '\\.zcode\\']

    # Walk the directory tree
    ps1_files = []
    for dirpath, dirnames, filenames in os.walk(root_path):
        # Check if we should skip this directory based on excluded_dirs
        skip = False
        for excl in excluded_dirs:
            if excl in dirpath:
                skip = True
                break
        if skip:
            # Don't descend into this directory
            dirnames[:] = []
            continue

        for filename in filenames:
            if filename.lower().endswith('.ps1'):
                full_path = os.path.join(dirpath, filename)
                ps1_files.append(full_path)

    if not ps1_files:
        print("No .ps1 files found to check.")
        return

    bad_files = []
    for ps1_file in ps1_files:
        # Build the PowerShell command to check syntax and output errors
        # We'll escape any single quotes in the file path for PowerShell
        # We'll use double quotes for the PowerShell command and escape double quotes inside.
        # Alternatively, we can use single quotes in PowerShell and then escape single quotes.
        # Let's use single quotes in PowerShell and escape any single quotes in the path by doubling them.
        escaped_path = ps1_file.replace("'", "''")
        # PowerShell command: 
        #   try { [System.Management.Automation.Language.Parser]::ParseFile('$path', [ref]$null, [ref]$errs) } catch {}
        #   if ($errs) { $errs | ForEach-Object { "L$($_.Extent.StartLineNumber): $($_.Message)" } }
        ps_command = f"& {{ try {{ [System.Management.Automation.Language.Parser]::ParseFile('{escaped_path}', [ref]$null, [ref]$errs) }} catch {{}} ; if ($errs) {{ $errs | ForEach-Object {{ 'L$($_.Extent.StartLineNumber): $($_.Message)' }} }} }}"
        # Run the command
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", ps_command],
            capture_output=True,
            text=True
        )
        # Check if there was an error in running the command itself
        if result.returncode != 0:
            # This is an error in running PowerShell, not a syntax error in the script.
            # We'll treat it as a syntax error? Or we can skip? Let's treat it as an error and record it.
            bad_files.append((ps1_file, [f"PowerShell error: {result.stderr}"]))
            continue

        # Split the output into lines
        output_lines = result.stdout.strip().splitlines()
        if output_lines and output_lines[0]:  # Non-empty output means there were syntax errors
            bad_files.append((ps1_file, output_lines))

    # Output the results
    print(f"Scanned {len(ps1_files)} .ps1 files")
    if not bad_files:
        print("ALL SYNTAX OK")
    else:
        print(f"{len(bad_files)} files with syntax errors:")
        for file_path, errors in bad_files:
            # Make the path relative to the root_path for display
            try:
                rel_path = os.path.relpath(file_path, root_path)
            except ValueError:
                rel_path = file_path
            print(f"[{rel_path}]")
            for err in errors:
                print(f"  {err}")
            print()  # Empty line for separation
        # Exit with error code if any syntax errors were found
        sys.exit(1)

if __name__ == '__main__':
    main()