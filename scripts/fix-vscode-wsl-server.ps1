<#
.SYNOPSIS
    Fix corrupted VS Code Server in WSL
.DESCRIPTION
    Removes corrupted VS Code server installations and forces reinstall on next connect.
    Fixes: "Cannot find package 'cookie' imported from .../server-main.js"
.NOTES
    Run this, then reconnect VS Code to WSL - it will auto-download fresh server.
#>

$ErrorActionPreference = "Continue"

Write-Host "`n=== Fix VS Code Server in WSL ===" -ForegroundColor Magenta

# Get WSL distros
$rawDistros = wsl -l -q 2>$null
$distros = @()
foreach ($r in $rawDistros) {
    $t = $r.Trim() -replace '\0', ''
    if ($t.Length -gt 0 -and $t -ne 'docker-desktop' -and $t -notlike '*data*') {
        $distros += $t
    }
}

if ($distros.Count -eq 0) {
    Write-Host "No WSL distros found" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found distros: $($distros -join ', ')" -ForegroundColor Cyan

foreach ($distro in $distros) {
    Write-Host "`n--- Fixing $distro ---" -ForegroundColor Cyan
    
    # Find all VS Code server installations
    Write-Host "  Scanning for VS Code server installations..." -ForegroundColor Gray
    $serverDirs = wsl -d "$distro" -e bash -c "ls -d ~/.vscode-server/bin/*/ 2>/dev/null" 2>&1
    
    if ($serverDirs) {
        Write-Host "  Found server versions:" -ForegroundColor Gray
        $serverDirs.Trim().Split("`n") | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        
        # Remove all server bin directories (they'll be reinstalled)
        Write-Host "  Removing all VS Code server installations..." -ForegroundColor Yellow
        wsl -d "$distro" -e bash -c "rm -rf ~/.vscode-server/bin/* 2>/dev/null; echo 'DONE:server_bin_removed'" 2>&1 | Out-Null
        Write-Host "  [OK] Removed server bin folders" -ForegroundColor Green
    } else {
        Write-Host "  No server installations found" -ForegroundColor Gray
    }
    
    # Also clear VS Code server data caches (preserves settings/extensions)
    Write-Host "  Clearing VS Code server caches..." -ForegroundColor Yellow
    $cacheDirs = @(
        "~/.vscode-server/data/CachedData"
        "~/.vscode-server/data/User/workspaceStorage"
        "~/.vscode-server/data/logs"
        "~/.vscode-server/extensionsCache"
        "~/.vscode-server/data/Machine"  # May contain corrupted settings
    )
    
    foreach ($cache in $cacheDirs) {
        wsl -d "$distro" -e bash -c "rm -rf $cache 2>/dev/null" 2>&1 | Out-Null
    }
    Write-Host "  [OK] Cleared server caches" -ForegroundColor Green
    
    # Clear any partial/corrupted node_modules in server
    wsl -d "$distro" -e bash -c "rm -rf ~/.vscode-server/bin/*/node_modules 2>/dev/null" 2>&1 | Out-Null
    
    Write-Host "`n  [OK] $distro fixed - VS Code will reinstall server on next connect" -ForegroundColor Green
}

Write-Host "`n=== Next Steps ===" -ForegroundColor Magenta
Write-Host "1. Close VS Code completely" -ForegroundColor Cyan
Write-Host "2. Reopen VS Code and connect to WSL (Remote: Reopen Folder in WSL)" -ForegroundColor Cyan
Write-Host "3. VS Code will download and install a fresh server (~30-60 sec)" -ForegroundColor Cyan
Write-Host "`nThis fixes: 'Cannot find package cookie' and similar module errors" -ForegroundColor Gray