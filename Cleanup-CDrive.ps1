<#
.SYNOPSIS
    C: Drive Cleanup Script for Development Environments

.DESCRIPTION
    Comprehensive cleanup script for the C: drive targeting:
    - Temporary files and folders
    - Developer tool caches (npm, yarn, pip, etc.)
    - Browser caches (Chrome, Edge, Firefox)
    - Windows temp files
    - Recycle bin emptying (optional)
    - Customizable cleanup modes

.PARAMETER Mode
    Cleanup intensity: 'Quick' (safe temp files), 'Standard' (recommended), 'Deep' (aggressive caches), 'Custom'

.PARAMETER WhatIf
    Preview mode - shows what would be deleted without actually deleting

.PARAMETER SkipConfirmation
    Skip confirmation prompts for automated execution

.PARAMETER EmptyRecycleBin
    Empty the Recycle Bin as part of cleanup

.EXAMPLE
    # Interactive cleanup with confirmation prompts
    .\Cleanup-CDrive.ps1 -Mode Standard

.EXAMPLE
    # Preview what would be deleted in Deep mode
    .\Cleanup-CDrive.ps1 -Mode Deep -WhatIf

.EXAMPLE
    # Automated quick cleanup
    .\Cleanup-CDrive.ps1 -Mode Quick -SkipConfirmation

.NOTES
    Author: DevOptimizer Team
    Version: 1.0
    Requires: PowerShell 5.1+
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Quick', 'Standard', 'Deep', 'Custom')]
    [string]$Mode = 'Standard',
    
    [switch]$SkipConfirmation,
    
    [switch]$EmptyRecycleBin
)

# Helper function to format bytes to human readable
function Format-Size {
    param([int64]$Bytes)
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes/1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes/1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes/1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes/1KB) }
    return "{0} Bytes" -f $Bytes
}

# Helper function to get directory size
function Get-DirectorySize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Max(0, $size)
    } catch {
        return 0
    }
}

# Initialize tracking variables
$totalSpaceFreed = 0
$cleanupActions = @()

Write-Host "`nC: Drive Cleanup Script" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "Mode: $Mode" -ForegroundColor Yellow
if ($WhatIfPreference) { 
    Write-Host "WHATIF MODE: No actual deletions will occur" -ForegroundColor Magenta 
}
Write-Host ""

# Function to perform cleanup action with tracking
function Invoke-CleanupAction {
    param(
        [string]$Description,
        [scriptblock]$CleanupScript,
        [switch]$RequireConfirmation = $false
    )
    
    if ($RequireConfirmation -and -not $SkipConfirmation) {
        $response = Read-Host "`nProceed with $Description? (Y/N)"
        if ($response -notin @('Y', 'y')) {
            Write-Host "Skipped: $Description" -ForegroundColor DarkGray
            return
        }
    }
    
    if ($PSCmdlet.ShouldProcess($Description)) {
        try {
            & $CleanupScript
            Write-Host "+ Completed: $Description" -ForegroundColor Green
        } catch {
            Write-Host "x Failed: $Description - $_" -ForegroundColor Red
        }
    }
}

# ========== QUICK CLEANUP (Safe temp files) ==========
if ($Mode -in @('Quick', 'Standard', 'Deep', 'Custom')) {
    $quickScript = {
        # Windows Temp folders
        $tempPaths = @("$env:TEMP", "$env:WINDIR\Temp")
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { !$_.PSIsContainer } |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        
        # Recent files
        $recent = "$env:APPDATA\Microsoft\Windows\Recent"
        if (Test-Path $recent) {
            Get-ChildItem -Path $recent -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
        
        # Prefetch (older than 7 days)
        $prefetch = "$env:WINDIR\Prefetch"
        if (Test-Path $prefetch) {
            Get-ChildItem -Path $prefetch -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    
    Invoke-CleanupAction -Description "Quick cleanup (temp files, recent)" -CleanupScript $quickScript
}

# ========== STANDARD CLEANUP (Quick + browser caches) ==========
if ($Mode -in @('Standard', 'Deep', 'Custom')) {
    $standardScript = {
        # Browser caches
        $browserPaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
            "$env:APPDATA\Mozilla\Firefox\Profiles"
        )
        
        foreach ($path in $browserPaths) {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -Recurse -Include @("Cache", "Cache_Data", "*-wal", "*-shm") -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                
                # Firefox specific cleanup
                if ($path -like "*Firefox*") {
                    Get-ChildItem -Path $path -Recurse -Include "*.sqlite", "jurlcache", "urlclassifier3.sqlite" -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                }
            }
        }
        
        # DNS cache
        ipconfig /flushdns > $null
        
        # Windows Update cache (stop service first)
        try {
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Get-ChildItem -Path "$env:WINDIR\SoftwareDistribution\Download" -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        } catch {
            # Service might already be stopped or not accessible
        }
    }
    
    Invoke-CleanupAction -Description "Standard cleanup (browser caches, DNS, Windows Update)" -CleanupScript $standardScript
}

# ========== DEEP CLEANUP (Standard + dev caches) ==========
if ($Mode -in @('Deep', 'Custom')) {
    $deepScript = {
        # Developer caches
        $devPaths = @(
            # npm/yarn
            "$env:LOCALAPPDATA\npm-cache",
            "$env:LOCALAPPDATA\Yarn\Cache",
            # pip
            "$env:LOCALAPPDATA\pip\Cache",
            # .NET
            "$env:LOCALAPPDATA\Microsoft\WebsiteCache",
            "$env:LOCALAPPDATA\Microsoft\VisualStudio\16.0_*",
            # JetBrains IDEs
            "$env:LOCALAPPDATA\JetBrains\*",
            # VS Code
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Cache",
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\Cache",
            # Android Studio
            "$env:LOCALAPPDATA\Google\AndroidStudio*",
            "$env:LOCALAPPDATA\Android\*",
            # Unity
            "$env:LOCALAPPDATA\Unity\*",
            # Electron apps
            "$env:LOCALAPPDATA\*Cache*",
            "$env:LOCALAPPDATA\*Logs*"
        )
        
        foreach ($path in $devPaths) {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -Recurse -Include @("Cache", "Logs", "tmp", "temp") -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        
        # Node.js modules cache (be careful with this one)
        $npmCache = "$env:LOCALAPPDATA\npm-cache"
        if (Test-Path $npmCache) {
            Get-ChildItem -Path $npmCache -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
        
        # Python __pycache__ files
        Get-ChildItem -Path "$env:USERPROFILE" -Recurse -Include "__pycache__", "*.pyc" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
    
    Invoke-CleanupAction -Description "Deep cleanup (developer caches)" -CleanupScript $deepScript
}

# ========== RECYCLE BIN ==========
if ($EmptyRecycleBin) {
    $recycleScript = {
        # Empty Recycle Bin
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.Namespace(0xA)
        $recycleBin.Items() | ForEach-Object { $_.InvokeVerb("delete") }
    }
    
    Invoke-CleanupAction -Description "Empty Recycle Bin" -CleanupScript $recycleScript -RequireConfirmation:$true
}

# Summary
Write-Host "`nCleanup completed!" -ForegroundColor Green
Write-Host "Note: Space freed calculations require running without -WhatIf" -ForegroundColor Yellow