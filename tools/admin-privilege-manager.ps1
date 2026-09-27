# Admin Privilege Manager for DevOptimizer
# Provides functions to handle admin privileges and create dual-version scripts

param(
    [string]$LogLevel = "INFO"
)

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level.ToUpper()) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
    Tests if the current process is running with administrator privileges
    #>
    
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Log "Error checking admin privileges: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-AdminCheckCode {
    <#
    .SYNOPSIS
    Returns the standard admin privilege check code for batch files
    #>
    
    return @"
:: Check for admin privileges
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
    echo.
    echo [WARNING] This script requires Administrator privileges for full functionality.
    echo Some features may be limited without admin access.
    echo.
    echo To run with full privileges:
    echo 1. Right-click this script and select "Run as administrator"
    echo 2. Or use the admin version: %~n0-Admin.bat
    echo.
    set /p continue="Continue with limited privileges? (Y/N): "
    if /i not "!continue!"=="Y" exit /b 0
    echo.
    echo Running with limited privileges...
) else (
    echo [INFO] Running with Administrator privileges - Full functionality available
)
"@
}

function Get-NoAdminCheckCode {
    <#
    .SYNOPSIS
    Returns the standard non-admin check code for batch files
    #>
    
    return @"
:: Check admin privileges (for informational purposes only)
call :checkAdmin
if "%IS_ADMIN%"=="1" (
    echo [INFO] Administrator privileges detected - Some features may be enhanced
) else (
    echo [INFO] Running without Administrator privileges - Normal operation
)
"@
}

function Get-StandardAdminFunctions {
    <#
    .SYNOPSIS
    Returns the standard admin checking functions for batch files
    #>
    
    return @"

:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
fsutil dirty query %SystemDrive% >nul 2>&1
if errorlevel 1 (
    net session >nul 2>&1
    if not errorlevel 1 set "IS_ADMIN=1"
) else (
    set "IS_ADMIN=1"
)
exit /b

:requireAdmin
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
    echo.
    echo [ERROR] This operation requires Administrator privileges.
    echo Please run this script as Administrator or use the admin version.
    echo.
    pause
    exit /b 1
)
exit /b

:log
echo [%date% %time%] %~1 >> "%LOG_FILE%" 2>nul
exit /b
"@
}

function Get-LimitedFunctionalityNotice {
    <#
    .SYNOPSIS
    Returns a notice about limited functionality without admin privileges
    #>
    
    return @"

echo ================================================================
echo                    LIMITED FUNCTIONALITY NOTICE
echo ================================================================
echo.
echo Running without Administrator privileges. Some features are limited:
echo.
echo AVAILABLE FEATURES:
echo - User-level optimizations
echo - Application-specific settings
echo - File and folder operations (user scope)
echo - Registry operations (user scope)
echo - Service queries and information
echo - Performance monitoring
echo - AI analysis and recommendations
echo.
echo LIMITED FEATURES:
echo - System-wide registry changes
echo - Service start/stop operations
echo - System file modifications
echo - Network adapter configuration
echo - System security settings
echo - Hardware configuration changes
echo.
echo For full functionality, use the admin version or run as Administrator.
echo.
"@
}

function Convert-ToAdminVersion {
    param(
        [string]$ScriptPath,
        [string]$OutputPath
    )
    
    <#
    .SYNOPSIS
    Converts a script to require admin privileges
    #>
    
    try {
        $content = Get-Content $ScriptPath -Raw -Encoding UTF8
        
        # Add admin check after the initial setup
        $adminCheck = Get-AdminCheckCode
        $adminFunctions = Get-StandardAdminFunctions
        
        # Insert admin check after the first few lines
        $lines = $content -split "`n"
        $newLines = @()
        $inserted = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $newLines += $lines[$i]
            
            # Insert admin check after the title/header section
            if (-not $inserted -and $i -gt 5 -and $lines[$i] -match "echo.*===|echo.*---|echo.*---|set.*=") {
                $newLines += ""
                $newLines += $adminCheck -split "`n"
                $newLines += ""
                $inserted = $true
            }
        }
        
        # Add admin functions at the end
        $newContent = $newLines -join "`n"
        $newContent += "`n" + $adminFunctions
        
        # Update title to indicate admin version
        $newContent = $newContent -replace "title ([^-]+)", "title $1 - Admin Mode"
        $newContent = $newContent -replace "echo.*===.*===", "echo ================================================================"
        $newContent = $newContent -replace "echo.*([^-]+).*===", "echo           $1 - ADMIN MODE"
        
        # Save the admin version
        Set-Content -Path $OutputPath -Value $newContent -Encoding UTF8
        
        Write-Log "Created admin version: $OutputPath" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Error creating admin version: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Convert-ToNoAdminVersion {
    param(
        [string]$ScriptPath,
        [string]$OutputPath
    )
    
    <#
    .SYNOPSIS
    Converts a script to work without admin privileges
    #>
    
    try {
        $content = Get-Content $ScriptPath -Raw -Encoding UTF8
        
        # Add no-admin check and limited functionality notice
        $noAdminCheck = Get-NoAdminCheckCode
        $limitedNotice = Get-LimitedFunctionalityNotice
        $adminFunctions = Get-StandardAdminFunctions
        
        # Insert no-admin check after the initial setup
        $lines = $content -split "`n"
        $newLines = @()
        $inserted = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $newLines += $lines[$i]
            
            # Insert no-admin check after the title/header section
            if (-not $inserted -and $i -gt 5 -and $lines[$i] -match "echo.*===|echo.*---|echo.*---|set.*=") {
                $newLines += ""
                $newLines += $noAdminCheck -split "`n"
                $newLines += ""
                $newLines += $limitedNotice -split "`n"
                $inserted = $true
            }
        }
        
        # Add admin functions at the end (for checking purposes)
        $newContent = $newLines -join "`n"
        $newContent += "`n" + $adminFunctions
        
        # Update title to indicate no-admin version
        $newContent = $newContent -replace "title ([^-]+)", "title $1 - Standard Mode"
        $newContent = $newContent -replace "echo.*===.*===", "echo ================================================================"
        $newContent = $newContent -replace "echo.*([^-]+).*===", "echo           $1 - STANDARD MODE"
        
        # Replace admin-required operations with user-level alternatives
        $newContent = $newContent -replace 'reg add "HKLM\\', 'reg add "HKCU\'
        $newContent = $newContent -replace "sc config", "sc query"
        $newContent = $newContent -replace "sc start", "sc query"
        $newContent = $newContent -replace "sc stop", "sc query"
        
        # Save the no-admin version
        Set-Content -Path $OutputPath -Value $newContent -Encoding UTF8
        
        Write-Log "Created no-admin version: $OutputPath" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Error creating no-admin version: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Create-DualVersions {
    param(
        [string]$ScriptPath
    )
    
    <#
    .SYNOPSIS
    Creates both admin and no-admin versions of a script
    #>
    
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $scriptDir = [System.IO.Path]::GetDirectoryName($ScriptPath)
    
    $adminVersion = Join-Path $scriptDir "$scriptName-Admin.bat"
    $noAdminVersion = Join-Path $scriptDir "$scriptName-NoAdmin.bat"
    
    Write-Log "Creating dual versions for: $scriptName" -Level "INFO"
    
    $adminSuccess = Convert-ToAdminVersion -ScriptPath $ScriptPath -OutputPath $adminVersion
    $noAdminSuccess = Convert-ToNoAdminVersion -ScriptPath $ScriptPath -OutputPath $noAdminVersion
    
    if ($adminSuccess -and $noAdminSuccess) {
        Write-Log "Successfully created dual versions for: $scriptName" -Level "INFO"
        return @{
            AdminVersion = $adminVersion
            NoAdminVersion = $noAdminVersion
            Success = $true
        }
    } else {
        Write-Log "Failed to create dual versions for: $scriptName" -Level "ERROR"
        return @{
            Success = $false
        }
    }
}

# Export functions for use in other scripts (only if running as module)
if ($MyInvocation.MyCommand.Module) {
    Export-ModuleMember -Function Test-AdminPrivileges, Get-AdminCheckCode, Get-NoAdminCheckCode, Get-StandardAdminFunctions, Get-LimitedFunctionalityNotice, Convert-ToAdminVersion, Convert-ToNoAdminVersion, Create-DualVersions
}
