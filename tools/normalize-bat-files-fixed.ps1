<#
.SYNOPSIS
    DevOptimizer automation script: normalize-bat-files-fixed.
.DESCRIPTION
    DevOptimizer automation script: normalize-bat-files-fixed.
#>

# Batch File Normalization Script for DevOptimizer
# Fixes encoding, headers, paths, and standardizes all .bat files

param(
    [string]$DevOptimizerPath = "D:\DevOptimizer",
    [string]$BackupPath = "backups\bat-fixes_20251004_103512",
    [switch]$DryRun,
    [switch]$Verbose
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Level.ToUpper()) {
        "ERROR" { Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor Red }
        "WARN" { Write-Host "[$timestamp] WARN: $Message" -ForegroundColor Yellow }
        "INFO" { Write-Host "[$timestamp] INFO: $Message" -ForegroundColor Green }
        "DEBUG" { if ($Verbose) { Write-Host "[$timestamp] DEBUG: $Message" -ForegroundColor Gray } }
        default { Write-Host "[$timestamp] $Message" }
    }
}

function Normalize-BatchFile {
    param(
        [string]$FilePath,
        [string]$BackupPath
    )

    try {
        $fileName = Split-Path -Leaf $FilePath
        Write-Log "Processing: $fileName" -Level "DEBUG"

        # Read file content
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $originalContent = $content

        # Skip if file is too small or empty
        if ($content.Length -lt 10) {
            Write-Log "Skipping $fileName (too small)" -Level "WARN"
            return @{ Success = $false; Reason = "File too small" }
        }

        # Normalize line endings and remove trailing spaces
        $content = $content -replace "`r`n", "`n"  # Normalize to LF first
        $content = $content -replace "`n", "`r`n"  # Convert to CRLF
        $content = $content -replace " +$", "" -replace "`r`n +", "`r`n"  # Remove trailing spaces
        $content = $content.TrimEnd() + "`r`n"  # Ensure single final newline

        # Check if file starts with @echo off
        if (-not ($content -match "^@echo off")) {
            $content = "@echo off`r`n" + $content
        }

        # Add setlocal if not present
        if (-not ($content -match "setlocal EnableExtensions EnableDelayedExpansion")) {
            $content = $content -replace "(@echo off`r`n)", "`$1setlocal EnableExtensions EnableDelayedExpansion`r`n"
        }

        # Add cd /d "%~dp0" if not present (for script-relative paths)
        if (-not ($content -match 'cd /d "%~dp0"')) {
            $content = $content -replace "(setlocal EnableExtensions EnableDelayedExpansion`r`n)", "`$1cd /d `"%~dp0`"`r`n"
        }

        # Replace Unicode characters with ASCII equivalents (simplified)
        $content = $content -replace '█', '='
        $content = $content -replace '╔', '+'
        $content = $content -replace '╗', '+'
        $content = $content -replace '╚', '+'
        $content = $content -replace '╝', '+'
        $content = $content -replace '═', '='
        $content = $content -replace '║', '|'
        $content = $content -replace '🚀', '[LAUNCH]'
        $content = $content -replace '🤖', '[AI]'
        $content = $content -replace '⚡', '[PERF]'
        $content = $content -replace '🔧', '[TOOL]'
        $content = $content -replace '📊', '[STATS]'
        $content = $content -replace '🌐', '[NET]'
        $content = $content -replace '🔒', '[SEC]'
        $content = $content -replace '🎨', '[UI]'
        $content = $content -replace '🧪', '[TEST]'
        $content = $content -replace '⚙️', '[CFG]'
        $content = $content -replace '✅', '[OK]'
        $content = $content -replace '❌', '[ERR]'
        $content = $content -replace '⚠️', '[WARN]'
        $content = $content -replace '💡', '[TIP]'
        $content = $content -replace '🎯', '[TARGET]'
        $content = $content -replace '📋', '[LIST]'
        $content = $content -replace '🔍', '[SEARCH]'
        $content = $content -replace '🛠️', '[BUILD]'
        $content = $content -replace '📁', '[FOLDER]'
        $content = $content -replace '📝', '[NOTE]'
        $content = $content -replace '🔴', '[RED]'
        $content = $content -replace '🟢', '[GREEN]'
        $content = $content -replace '🟡', '[YELLOW]'
        $content = $content -replace '🔵', '[BLUE]'

        # Fix common path issues
        $content = $content -replace 'tools\\', 'tools\'

        # Add standard admin helpers if Admin version
        if ($fileName -match "-Admin\.bat$" -and -not ($content -match ":checkAdmin")) {
            $adminHelpers = @"

REM ================================================================
REM                    ADMIN PRIVILEGE FUNCTIONS
REM ================================================================

:checkAdmin
set "IS_ADMIN=0"
fsutil dirty query %SystemDrive% >nul 2>&1
if not errorlevel 1 (
    set "IS_ADMIN=1"
) else (
    net session >nul 2>&1
    if not errorlevel 1 set "IS_ADMIN=1"
)
exit /b

:requireAdmin
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
    echo.
    echo [ERROR] This operation requires Administrator privileges.
    echo Please run this script as Administrator.
    echo.
    pause
    exit /b 1
)
exit /b
"@
            $content = $content.TrimEnd() + $adminHelpers + "`r`n"
        }

        # Ensure proper exit codes
        if (-not ($content -match "exit /b")) {
            $content = $content.TrimEnd() + "`r`nexit /b %ERRORLEVEL%`r`n"
        }

        # Save the normalized content
        if (-not $DryRun) {
            Set-Content -Path $FilePath -Value $content -Encoding UTF8 -NoNewline
            Write-Log "Normalized: $fileName" -Level "INFO"
        } else {
            Write-Log "DRY RUN: Would normalize $fileName" -Level "INFO"
        }

        return @{ Success = $true; Changes = ($content -ne $originalContent) }
    }
    catch {
        Write-Log "Error processing $fileName`: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; Reason = $_.Exception.Message }
    }
}

function Main {
    Write-Host "Batch File Normalization for DevOptimizer" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($DryRun) {
        Write-Host "DRY RUN MODE: No files will be modified" -ForegroundColor Yellow
        Write-Host ""
    }

    # Get all .bat files
    $batFiles = Get-ChildItem -Path $DevOptimizerPath -Filter "*.bat" | Where-Object { -not $_.PSIsContainer }

    Write-Log "Found $($batFiles.Count) .bat files to process" -Level "INFO"
    Write-Host ""

    $stats = @{
        Total = $batFiles.Count
        Processed = 0
        Success = 0
        Failed = 0
        Changed = 0
    }

    foreach ($file in $batFiles) {
        $result = Normalize-BatchFile -FilePath $file.FullName -BackupPath $BackupPath

        $stats.Processed++

        if ($result.Success) {
            $stats.Success++
            if ($result.Changes) {
                $stats.Changed++
            }
        } else {
            $stats.Failed++
            Write-Log "Failed to process: $($file.Name) - $($result.Reason)" -Level "WARN"
        }
    }

    # Summary
    Write-Host ""
    Write-Host "Normalization Summary" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host "Total Files: $($stats.Total)" -ForegroundColor White
    Write-Host "Processed: $($stats.Processed)" -ForegroundColor Green
    Write-Host "Successful: $($stats.Success)" -ForegroundColor Green
    Write-Host "Failed: $($stats.Failed)" -ForegroundColor Red
    Write-Host "Changed: $($stats.Changed)" -ForegroundColor Yellow
    Write-Host ""

    if ($DryRun) {
        Write-Host "This was a DRY RUN. Use -DryRun:`$false to apply changes." -ForegroundColor Yellow
    } else {
        Write-Host "Normalization completed!" -ForegroundColor Green
        Write-Host "Backups are available in: $BackupPath" -ForegroundColor Cyan
    }

    if ($stats.Failed -gt 0) {
        Write-Host ""
        Write-Host "Some files failed to process. Check the logs above." -ForegroundColor Red
        exit 1
    }

    exit 0
}

# Run the main function
Main
