# Create Dual Versions Script for DevOptimizer
# Automatically creates admin and no-admin versions of all batch scripts

param(
    [string]$ScriptPattern = "*.bat",
    [string]$OutputDir = ".",
    [switch]$Force,
    [switch]$ExcludeExisting,
    [switch]$Verbose
)

# Load the admin privilege manager
$scriptPath = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $PWD }
$adminManagerPath = Join-Path $scriptPath "admin-privilege-manager.ps1"

if (-not (Test-Path $adminManagerPath)) {
    Write-Host "❌ Admin privilege manager not found at: $adminManagerPath" -ForegroundColor Red
    exit 1
}

. $adminManagerPath

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
        "DEBUG" { if ($Verbose) { Write-Host $logMessage -ForegroundColor Gray } }
        default { Write-Host $logMessage }
    }
}

function Test-ShouldExcludeScript {
    param(
        [string]$ScriptPath
    )
    
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    
    # Exclude scripts that already have dual versions
    $excludePatterns = @(
        "-Admin$",
        "-NoAdmin$",
        "RUN-AS-ADMIN",
        "create-dual-versions",
        "admin-privilege-manager",
        "test-dual-versions"
    )
    
    foreach ($pattern in $excludePatterns) {
        if ($scriptName -match $pattern) {
            return $true
        }
    }
    
    return $false
}

function Get-ScriptCategory {
    param(
        [string]$ScriptPath
    )
    
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $content = Get-Content $ScriptPath -Raw -ErrorAction SilentlyContinue
    
    # Categorize scripts based on their content and name
    if ($scriptName -match "install|setup|configure|prerequisites") {
        return "Installation"
    }
    elseif ($scriptName -match "optimiz|performance|tune|boost") {
        return "Optimization"
    }
    elseif ($scriptName -match "clean|cleanup|maintenance|health") {
        return "Maintenance"
    }
    elseif ($scriptName -match "monitor|diagnostic|analy|test") {
        return "Analysis"
    }
    elseif ($scriptName -match "launch|open|access|ui") {
        return "Interface"
    }
    elseif ($scriptName -match "ollama|ai|intelligent") {
        return "AI/Analytics"
    }
    else {
        return "General"
    }
}

function Test-ScriptRequiresAdmin {
    param(
        [string]$ScriptPath
    )
    
    $content = Get-Content $ScriptPath -Raw -ErrorAction SilentlyContinue
    
    # Check for admin-required operations
    $adminPatterns = @(
        "HKLM\\",
        "sc config",
        "sc start",
        "sc stop",
        "net user",
        "net localgroup",
        "fsutil",
        "takeown",
        "icacls",
        "bcdedit",
        "powercfg /set",
        "reg add.*HKLM",
        "reg delete.*HKLM",
        "dism",
        "sfc",
        "chkdsk /f"
    )
    
    foreach ($pattern in $adminPatterns) {
        if ($content -match $pattern) {
            return $true
        }
    }
    
    return $false
}

function Main {
    Write-Host "🚀 DevOptimizer Dual-Version Creator" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Find all batch scripts
    $scripts = Get-ChildItem -Path $OutputDir -Filter $ScriptPattern | Where-Object { -not $_.PSIsContainer }
    
    if ($scripts.Count -eq 0) {
        Write-Host "❌ No batch scripts found matching pattern: $ScriptPattern" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "📋 Found $($scripts.Count) batch scripts to process" -ForegroundColor Green
    Write-Host ""
    
    # Statistics
    $stats = @{
        Total = $scripts.Count
        Processed = 0
        Skipped = 0
        Failed = 0
        AdminRequired = 0
        NoAdminRequired = 0
        Categories = @{}
    }
    
    # Process each script
    foreach ($script in $scripts) {
        $scriptName = $script.Name
        $scriptPath = $script.FullName
        
        Write-Log "Processing: $scriptName" -Level "DEBUG"
        
        # Check if we should exclude this script
        if (Test-ShouldExcludeScript -ScriptPath $scriptPath) {
            Write-Log "Skipping excluded: $scriptName" -Level "WARN"
            $stats.Skipped++
            continue
        }
        
        # Check if dual versions already exist
        $scriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
        $adminVersion = Join-Path $script.DirectoryName "$scriptBaseName-Admin.bat"
        $noAdminVersion = Join-Path $script.DirectoryName "$scriptBaseName-NoAdmin.bat"
        
        if ((Test-Path $adminVersion) -or (Test-Path $noAdminVersion)) {
            if (-not $Force) {
                Write-Log "Dual versions already exist for: $scriptName" -Level "WARN"
                $stats.Skipped++
                continue
            } else {
                Write-Log "Overwriting existing dual versions for: $scriptName" -Level "WARN"
            }
        }
        
        # Get script category
        $category = Get-ScriptCategory -ScriptPath $scriptPath
        if (-not $stats.Categories.ContainsKey($category)) {
            $stats.Categories[$category] = 0
        }
        $stats.Categories[$category]++
        
        # Check if script requires admin privileges
        $requiresAdmin = Test-ScriptRequiresAdmin -ScriptPath $scriptPath
        if ($requiresAdmin) {
            $stats.AdminRequired++
        } else {
            $stats.NoAdminRequired++
        }
        
        # Create dual versions
        try {
            $result = Create-DualVersions -ScriptPath $scriptPath
            
            if ($result.Success) {
                Write-Log "✅ Created dual versions for: $scriptName" -Level "INFO"
                Write-Log "   Admin: $([System.IO.Path]::GetFileName($result.AdminVersion))" -Level "DEBUG"
                Write-Log "   NoAdmin: $([System.IO.Path]::GetFileName($result.NoAdminVersion))" -Level "DEBUG"
                $stats.Processed++
            } else {
                Write-Log "❌ Failed to create dual versions for: $scriptName" -Level "ERROR"
                $stats.Failed++
            }
        }
        catch {
            Write-Log "❌ Error processing $scriptName`: $($_.Exception.Message)" -Level "ERROR"
            $stats.Failed++
        }
        
        Write-Host ""
    }
    
    # Display summary
    Write-Host "📊 DUAL-VERSION CREATION SUMMARY" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "Total Scripts Found: $($stats.Total)" -ForegroundColor White
    Write-Host "Successfully Processed: $($stats.Processed)" -ForegroundColor Green
    Write-Host "Skipped: $($stats.Skipped)" -ForegroundColor Yellow
    Write-Host "Failed: $($stats.Failed)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Script Analysis:" -ForegroundColor White
    Write-Host "  Admin Privileges Required: $($stats.AdminRequired)" -ForegroundColor Yellow
    Write-Host "  No Admin Privileges Required: $($stats.NoAdminRequired)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Categories:" -ForegroundColor White
    foreach ($category in $stats.Categories.Keys | Sort-Object) {
        Write-Host "  $category`: $($stats.Categories[$category])" -ForegroundColor Gray
    }
    
    if ($stats.Processed -gt 0) {
        Write-Host ""
        Write-Host "✅ Dual-version creation completed!" -ForegroundColor Green
        Write-Host "Each script now has both Admin and NoAdmin versions available." -ForegroundColor Green
    }
    
    if ($stats.Failed -gt 0) {
        Write-Host ""
        Write-Host "⚠️ Some scripts failed to process. Check the logs above for details." -ForegroundColor Yellow
        exit 1
    }
    
    exit 0
}

# Run the main function
Main
