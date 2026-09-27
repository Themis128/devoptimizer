# Simple Dual Version Creator for DevOptimizer
# Creates admin and no-admin versions of batch scripts

param(
    [string]$ScriptPattern = "*.bat",
    [switch]$Force
)

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Green
}

function Create-AdminVersion {
    param([string]$ScriptPath)
    
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $scriptDir = [System.IO.Path]::GetDirectoryName($ScriptPath)
    $adminVersion = Join-Path $scriptDir "$scriptName-Admin.bat"
    
    try {
        $content = Get-Content $ScriptPath -Raw -Encoding UTF8
        
        # Add admin check after title
        $adminCheck = @"

:: Check for admin privileges
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
    echo.
    echo [ERROR] This script requires Administrator privileges.
    echo Please run this script as Administrator.
    echo.
    pause
    exit /b 1
) else (
    echo [INFO] Running with Administrator privileges
)
"@

        # Insert admin check after title
        $lines = $content -split "`n"
        $newLines = @()
        $inserted = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $newLines += $lines[$i]
            
            if (-not $inserted -and $i -gt 3 -and $lines[$i] -match "echo.*===") {
                $newLines += ""
                $newLines += $adminCheck -split "`n"
                $newLines += ""
                $inserted = $true
            }
        }
        
        # Add admin functions
        $adminFunctions = @"

:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
"@

        $newContent = $newLines -join "`n"
        $newContent += "`n" + $adminFunctions
        
        # Update title
        $newContent = $newContent -replace "title ([^-]+)", "title $1 - Admin Mode"
        
        Set-Content -Path $adminVersion -Value $newContent -Encoding UTF8
        Write-Log "Created admin version: $([System.IO.Path]::GetFileName($adminVersion))"
        return $true
    }
    catch {
        Write-Host "Error creating admin version: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Create-NoAdminVersion {
    param([string]$ScriptPath)
    
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $scriptDir = [System.IO.Path]::GetDirectoryName($ScriptPath)
    $noAdminVersion = Join-Path $scriptDir "$scriptName-NoAdmin.bat"
    
    try {
        $content = Get-Content $ScriptPath -Raw -Encoding UTF8
        
        # Add no-admin notice
        $noAdminNotice = @"

:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited
"@

        # Insert notice after title
        $lines = $content -split "`n"
        $newLines = @()
        $inserted = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $newLines += $lines[$i]
            
            if (-not $inserted -and $i -gt 3 -and $lines[$i] -match "echo.*===") {
                $newLines += ""
                $newLines += $noAdminNotice -split "`n"
                $newLines += ""
                $inserted = $true
            }
        }
        
        $newContent = $newLines -join "`n"
        
        # Update title
        $newContent = $newContent -replace "title ([^-]+)", "title $1 - Standard Mode"
        
        Set-Content -Path $noAdminVersion -Value $newContent -Encoding UTF8
        Write-Log "Created no-admin version: $([System.IO.Path]::GetFileName($noAdminVersion))"
        return $true
    }
    catch {
        Write-Host "Error creating no-admin version: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host "🚀 Simple Dual Version Creator" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Find scripts to process
$scripts = Get-ChildItem -Filter $ScriptPattern | Where-Object { -not $_.PSIsContainer }

# Filter out scripts that already have dual versions
$scriptsToProcess = $scripts | Where-Object {
    $name = $_.BaseName
    -not ($name -match "-Admin$" -or $name -match "-NoAdmin$" -or $name -match "CREATE-DUAL-VERSIONS" -or $name -match "TEST-DUAL-VERSIONS")
}

Write-Host "📋 Found $($scriptsToProcess.Count) scripts to process" -ForegroundColor Green
Write-Host ""

$processed = 0
$failed = 0

foreach ($script in $scriptsToProcess) {
    $scriptName = $script.Name
    Write-Host "Processing: $scriptName" -ForegroundColor Yellow
    
    $scriptBaseName = $script.BaseName
    $adminVersion = Join-Path $script.DirectoryName "$scriptBaseName-Admin.bat"
    $noAdminVersion = Join-Path $script.DirectoryName "$scriptBaseName-NoAdmin.bat"
    
    # Check if versions already exist
    if ((Test-Path $adminVersion) -or (Test-Path $noAdminVersion)) {
        if (-not $Force) {
            Write-Host "  Skipping - dual versions already exist (use -Force to overwrite)" -ForegroundColor Gray
            continue
        } else {
            Write-Host "  Overwriting existing versions" -ForegroundColor Yellow
        }
    }
    
    # Create both versions
    $adminSuccess = Create-AdminVersion -ScriptPath $script.FullName
    $noAdminSuccess = Create-NoAdminVersion -ScriptPath $script.FullName
    
    if ($adminSuccess -and $noAdminSuccess) {
        Write-Host "  ✅ Successfully created dual versions" -ForegroundColor Green
        $processed++
    } else {
        Write-Host "  ❌ Failed to create dual versions" -ForegroundColor Red
        $failed++
    }
    
    Write-Host ""
}

# Summary
Write-Host "📊 SUMMARY" -ForegroundColor Cyan
Write-Host "==========" -ForegroundColor Cyan
Write-Host "Processed: $processed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host ""

if ($processed -gt 0) {
    Write-Host "✅ Dual version creation completed!" -ForegroundColor Green
    Write-Host "Each script now has both Admin and NoAdmin versions." -ForegroundColor Green
}

if ($failed -gt 0) {
    Write-Host "⚠️ Some scripts failed to process." -ForegroundColor Yellow
    exit 1
}

exit 0
