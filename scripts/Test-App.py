#!/usr/bin/env python3
"""
Test-App.py - Python version of the Test-App PowerShell script
Runner for the DevOptimizer application test suite.
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path
import re

def ensure_pester():
    """Ensure Pester 5+ is installed, install if missing."""
    try:
        # Check if Pester is available
        result = subprocess.run(
            ['powershell', '-Command', 'Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1'],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0 and result.stdout.strip():
            # Extract version info
            lines = result.stdout.strip().split('\n')
            if lines and len(lines[0].split()) >= 2:
                version_str = lines[0].split()[-1]
                print(f"Pester {version_str} found")
                return True
    except Exception:
        pass
    
    print("Pester 5+ not found - installing to CurrentUser (no elevation)...")
    try:
        # Install NuGet provider if needed
        subprocess.run(
            ['powershell', '-Command', '$null = Get-PackageProvider -Name NuGet -ErrorAction Stop'],
            capture_output=True, timeout=30
        )
        
        # Install Pester
        result = subprocess.run(
            ['powershell', '-Command',
             'Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber'],
            capture_output=True, text=True, timeout=60
        )
        if result.returncode == 0:
            print("Pester installed successfully")
            return True
        else:
            print(f"Failed to install Pester: {result.stderr}")
            return False
    except Exception as e:
        print(f"Error installing Pester: {e}")
        return False

def strip_ansi(text):
    """Remove ANSI escape sequences from text."""
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub('', text)

def run_tests(test_dir, ci_mode=False, tag=None):
    """Run the Pester tests."""
    # Set up environment
    script_path = Path(__file__).resolve()
    root = script_path.parent.parent  # Go up two levels from scripts/ to DevOptimizer root
    env_devopt_root = str(root)
    
    # Prepare environment for subprocess
    env = os.environ.copy()
    env['DEVOPT_ROOT'] = env_devopt_root
    
    # Build the PowerShell command safely with execution policy bypass
    # We'll pass the tag as a parameter to avoid injection
    if tag:
        # Validate tag contains only safe characters (alphanumeric, underscore, hyphen)
        if not re.match(r'^[a-zA-Z0-9_\-]+$', tag):
            print(f"Error: Tag contains invalid characters: {tag}")
            return False, 0, 0, 0, 0
        
        # Use script block with parameter
        ps_command = f'''
        Import-Module Pester -MinimumVersion 5.0 -Force;
        $result = Invoke-Pester -Path "{test_dir}" -Tag $using:tag -Output Normal -PassThru;
        $result
        '''
        
        try:
            print(f"Running tests from: {test_dir}")
            print(f"Filtering by tag: {tag}")
            if ci_mode:
                print("Running in CI mode")
                
            result = subprocess.run(
                ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ps_command],
                capture_output=True, text=True, timeout=120,
                env=env
            )
        except Exception as e:
            print(f"Error running tests: {e}")
            return False, 0, 0, 0, 0
    else:
        # No tag filtering
        ps_command = f'''
        Import-Module Pester -MinimumVersion 5.0 -Force;
        $result = Invoke-Pester -Path "{test_dir}" -Output Normal -PassThru;
        $result
        '''
        
        try:
            print(f"Running tests from: {test_dir}")
            if ci_mode:
                print("Running in CI mode")
                
            result = subprocess.run(
                ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ps_command],
                capture_output=True, text=True, timeout=120,
                env=env
            )
        except Exception as e:
            print(f"Error running tests: {e}")
            return False, 0, 0, 0, 0
    
    # Parse output to get test results
    output = result.stdout
    error_output = result.stderr
    
    # Strip ANSI escape codes for easier parsing
    clean_output = strip_ansi(output)
    clean_error = strip_ansi(error_output)
    
    # Debug: print first few lines of cleaned output
    # print("DEBUG: First 10 lines of cleaned output:")
    # for i, line in enumerate(clean_output.split('\n')[:10]):
    #     print(f"  {i}: {line}")
    
    # Look for test summary in output
    failed_count = 0
    passed_count = 0
    skipped_count = 0
    total_count = 0
    
    # Try to find the summary line - look for the pattern from Pester output
    for line in clean_output.split('\n'):
        # Look for lines like: "Tests Passed: 37, Failed: 0, Skipped: 0, NotRun: 0"
        if 'Tests Passed:' in line and 'Failed:' in line:
            # Match: Tests Passed: 37, Failed: 0, Skipped: 0, NotRun: 0
            match = re.search(r'Tests\s+Passed:\s+(\d+),\s+Failed:\s+(\d+),\s+Skipped:\s+(\d+),\s+NotRun:\s+(\d+)', line)
            if match:
                passed_count = int(match.group(1))
                failed_count = int(match.group(2))
                skipped_count = int(match.group(3))
                # NotRun count is not always present, but we can calculate total
                not_run_count = int(match.group(4)) if match.lastindex >= 4 else 0
                total_count = passed_count + failed_count + skipped_count + not_run_count
                # print(f"DEBUG: Found match in line: {line}")
                break
        # Also look for the older format: "X tests: Y total, Z passed, A failed, B skipped"
        elif 'tests:' in line.lower() and 'passed' in line.lower() and 'failed' in line.lower():
            match = re.search(r'(\d+)\s+total,\s+(\d+)\s+passed,\s+(\d+)\s+failed,\s+(\d+)\s+skipped', line, re.IGNORECASE)
            if match:
                total_count = int(match.group(1))
                passed_count = int(match.group(2))
                failed_count = int(match.group(3))
                skipped_count = int(match.group(4))
                # print(f"DEBUG: Found match in line: {line}")
                break
    
    # If we still didn't find counts, try to look for the summary at the end
    if total_count == 0:
        # Look for the summary section that Pester prints at the end
        lines = clean_output.split('\n')
        for i, line in enumerate(lines):
            if 'Tests completed' in line and i + 1 < len(lines):
                # Next line might have the summary
                summary_line = lines[i + 1]
                if 'Tests Passed:' in summary_line and 'Failed:' in summary_line:
                    match = re.search(r'Tests\s+Passed:\s+(\d+),\s+Failed:\s+(\d+),\s+Skipped:\s+(\d+),\s+NotRun:\s+(\d+)', summary_line)
                    if match:
                        passed_count = int(match.group(1))
                        failed_count = int(match.group(2))
                        skipped_count = int(match.group(3))
                        not_run_count = int(match.group(4)) if match.lastindex >= 4 else 0
                        total_count = passed_count + failed_count + skipped_count + not_run_count
                        # print(f"DEBUG: Found match in summary line: {summary_line}")
                        break
    
    # Fallback: if we still have no counts, try to extract from the Result section
    if total_count == 0:
        for line in clean_output.split('\n'):
            if 'PassedCount' in line and 'FailedCount' in line:
                # Look for lines like: PassedCount           : 37
                passed_match = re.search(r'PassedCount\s*:(\s*)(\d+)', line)
                failed_match = re.search(r'FailedCount\s*:(\s*)(\d+)', line)
                skipped_match = re.search(r'SkippedCount\s*:(\s*)(\d+)', line)
                if passed_match and failed_match:
                    passed_count = int(passed_match.group(2))
                    failed_count = int(failed_match.group(2))
                    skipped_count = int(skipped_match.group(2)) if skipped_match else 0
                    total_count = passed_count + failed_count + skipped_count
                    # print(f"DEBUG: Found counts from Result section")
                    break
    
    # Print output
    if output:
        print(output)
    if error_output and not ci_mode:
        print("Errors/Warnings:", file=sys.stderr)
        print(error_output, file=sys.stderr)
    
    # Print summary
    print(f"\nApp tests: {total_count} total, {passed_count} passed, {failed_count} failed, {skipped_count} skipped")
    
    return failed_count == 0, total_count, passed_count, failed_count, skipped_count

def main():
    """Main function to parse arguments and run tests."""
    parser = argparse.ArgumentParser(description='Runner for the DevOptimizer application test suite')
    parser.add_argument('-CI', action='store_true', help='CI mode: minimal output, exit code only')
    parser.add_argument('-Tag', type=str, help='optional Pester -Tag filter')
    
    args = parser.parse_args()
    
    # Ensure Pester is available
    if not ensure_pester():
        print('Pester 5+ could not be installed or found.')
        return 1
    
    # Find the Pester version (for display)
    try:
        result = subprocess.run(
            ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', 'Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1 | Select-Object -ExpandProperty Version'],
            capture_output=True, text=True, timeout=10
        )
        pester_version = result.stdout.strip() if result.returncode == 0 else "unknown"
    except Exception:
        pester_version = "unknown"
    
    ps_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    print(f"DevOptimizer app tests - Pester {pester_version} on Python {ps_version}")
    
    # Import and run Pester (simulated by calling PowerShell)
    success, total, passed, failed, skipped = run_tests(str(Path(__file__).parent.parent / 'tests' / 'app'), args.CI, args.Tag)
    
    if failed > 0:
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())