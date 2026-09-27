# Batch File Parentheses Auto-Fixer

## Overview

Two PowerShell scripts have been created to automatically fix common unmatched parentheses issues in batch files:

1. **`fix-batch-parentheses.ps1`** - Basic fixer with pattern matching
2. **`fix-batch-parentheses-smart.ps1`** - Smarter fixer with line-by-line analysis

## Common Issues Fixed

### 1. Empty Parentheses `()` → Opening Parenthesis `(`
**Pattern**: Standalone `()` on a line before a command block
```batch
# Before
()
echo Some text

# After
(
echo Some text
```

### 2. FOR Loop with Immediate Closing
**Pattern**: `for ... do (echo.)` → `for ... do (`
```batch
# Before
for /f %%a in ('command') do (echo.)
    echo Process: %%a
)

# After
for /f %%a in ('command') do (
    echo Process: %%a
)
```

### 3. Empty Parentheses in IF Statements
**Pattern**: `if condition ()` → `if condition (`
```batch
# Before
if %errorlevel% neq 0 ()
    echo Error occurred
)

# After
if %errorlevel% neq 0 (
    echo Error occurred
)
```

## Usage

### Dry Run (Preview Changes)
```powershell
# Fix all files (dry run)
.\fix-batch-parentheses-smart.ps1 -Path "D:\DevOptimizer" -DryRun

# Fix specific files (dry run)
.\fix-batch-parentheses-smart.ps1 -Files @("file1.bat", "file2.bat") -DryRun
```

### Apply Fixes
```powershell
# Fix all files with backup
.\fix-batch-parentheses-smart.ps1 -Path "D:\DevOptimizer" -Backup

# Fix specific files with backup
.\fix-batch-parentheses-smart.ps1 -Files @("file1.bat", "file2.bat") -Backup -Verbose
```

## Parameters

- `-Path` - Root directory to scan (default: `D:\DevOptimizer`)
- `-Files` - Specific files to fix (array of file paths)
- `-DryRun` - Preview changes without modifying files
- `-Backup` - Create backup files before fixing
- `-Verbose` - Show detailed change information

## Safety Features

1. **Backup Creation**: Use `-Backup` to create timestamped backups
2. **Dry Run Mode**: Always test with `-DryRun` first
3. **Verification**: Script verifies fixes improve parentheses balance
4. **Conservative Fixing**: Only applies fixes that improve the situation

## Limitations

- Complex nested structures may require manual fixing
- Files with parentheses in echo text may show false positives
- Some edge cases may need manual intervention

## Examples

### Example 1: Fix a Single File
```powershell
.\fix-batch-parentheses-smart.ps1 -Files @("categories\system-optimization\01-Quick-Optimization.bat") -Backup -Verbose
```

### Example 2: Fix All Files in Directory
```powershell
.\fix-batch-parentheses-smart.ps1 -Path "D:\DevOptimizer\categories" -Backup
```

### Example 3: Preview What Would Be Fixed
```powershell
.\fix-batch-parentheses-smart.ps1 -Path "D:\DevOptimizer" -DryRun -Verbose | Out-File "fix-preview.txt"
```

## Manual Fixes Applied

The following files were manually fixed to establish patterns:

1. ✅ `copy-menu-to-desktop.bat` - Fixed empty parentheses in IF statement
2. ✅ `copy-to-public-desktop-admin.bat` - Fixed two empty parentheses in IF statements
3. ✅ `SYSTEM-BACKUP-MANAGER.bat` - Fixed command block and FOR loop issues
4. ✅ `categories\uncategorized\00-SETUP-GLOBAL-ACCESS.bat` - Fixed FOR loop with (echo.)

## Current Status

- **PowerShell Scripts**: 128/128 valid (100%) ✅
- **Batch Scripts**: 319/440 valid (72.5%) ⚠️
- **Overall**: 447/568 valid (78.7%) ⚠️
- **Remaining Issues**: 121 batch files

## Next Steps

1. Run the fixer on high-priority directories:
   ```powershell
   .\fix-batch-parentheses-smart.ps1 -Path "D:\DevOptimizer\categories" -Backup -DryRun
   ```

2. Review the changes in dry-run mode

3. Apply fixes to specific categories:
   ```powershell
   .\fix-batch-parentheses-smart.ps1 -Path "D:\DevOptimizer\categories\development-tools" -Backup
   ```

4. Re-run validation:
   ```powershell
   .\validate-all-scripts.ps1 -Path "D:\DevOptimizer"
   ```

## Notes

- Always use `-DryRun` first to preview changes
- Use `-Backup` to create safety backups
- Complex files may need manual review
- The script is conservative and won't apply fixes that make things worse
