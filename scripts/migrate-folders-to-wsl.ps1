<# 
.SYNOPSIS
    Migrates D:\DevOptimizer folder to /home/tbaltzakis/DevOptimizer in WSL2 Ubuntu-24.04

.DESCRIPTION
    Copies the DevOptimizer project folder from Windows D: drive to the WSL2 Ubuntu-24.04
    home directory for better Devin Desktop integration. Uses wsl.exe for the copy operation.
    
.NOTES
    Run from PowerShell (not Git Bash) as Administrator for best results.
    Requires WSL2 Ubuntu-24.04 to be installed and running.
#>

param(
    [string]$SourcePath = "D:\DevOptimizer",
    [string]$DestPath = "/home/tbaltzakis/DevOptimizer",
    [string]$WslDistro = "Ubuntu-24.04",
    [switch]$Force,
    [switch]$DryRun
)

# Colors for output
$Green = [ConsoleColor]::Green
$Yellow = [ConsoleColor]::Yellow
$Red = [ConsoleColor]::Red
$Cyan = [ConsoleColor]::Cyan

function Write-Log {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::White)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function Test-WslDistro {
    param([string]$Distro)
    $result = wsl.exe -l -v 2>&1 | Select-String $Distro
    return $null -ne $result
}

function Test-PathInWsl {
    param([string]$Distro, [string]$Path)
    $result = wsl.exe -d $Distro -- bash -c "test -e '$Path' && echo 'EXISTS' || echo 'NOT_EXISTS'" 2>&1
    return $result.Trim() -eq "EXISTS"
}

# Main execution
Write-Log "Starting DevOptimizer folder migration to WSL2" $Cyan
Write-Log "Source: $SourcePath" $Cyan
Write-Log "Destination (WSL): $DestPath" $Cyan
Write-Log "WSL Distro: $WslDistro" $Cyan

# Check WSL distro exists
if (-not (Test-WslDistro $WslDistro)) {
    Write-Log "ERROR: WSL distro '$WslDistro' not found. Available distros:" $Red
    wsl.exe -l -v
    exit 1
}

# Check source exists
if (-not (Test-Path $SourcePath)) {
    Write-Log "ERROR: Source path '$SourcePath' does not exist" $Red
    exit 1
}

Write-Log "Source path verified: $SourcePath" $Green

# Check if destination already exists in WSL
if (Test-PathInWsl $WslDistro $DestPath) {
    if ($Force) {
        Write-Log "Destination exists in WSL, removing (Force specified)..." $Yellow
        if (-not $DryRun) {
            wsl.exe -d $WslDistro -- bash -c "rm -rf '$DestPath'"
        }
    } else {
        Write-Log "WARNING: Destination '$DestPath' already exists in WSL. Use -Force to overwrite." $Yellow
        exit 1
    }
}

# Ensure parent directory exists in WSL
$parentDir = Split-Path $DestPath
Write-Log "Ensuring parent directory exists: $parentDir" $Cyan
if (-not $DryRun) {
    wsl.exe -d $WslDistro -- bash -c "mkdir -p '$parentDir'"
}

# Perform the copy using wsl.exe with rsync for efficiency
Write-Log "Starting folder copy to WSL2..." $Cyan

if ($DryRun) {
    Write-Log "DRY RUN: Would copy $SourcePath to WSL:$DestPath" $Yellow
    Write-Log "DRY RUN: Command would be:" $Yellow
    Write-Log "  wsl.exe -d $WslDistro -- bash -c \"rsync -av --progress '/mnt/d/DevOptimizer/' '$DestPath'\"" $Yellow
} else {
    # Convert Windows path to WSL path for source
    $wslSourcePath = $SourcePath -replace '^D:', '/mnt/d' -replace '\\', '/'
    
    Write-Log "Copying from $wslSourcePath to $DestPath" $Cyan
    
    # Use rsync for efficient copy with progress
    $result = wsl.exe -d $WslDistro -- bash -c "rsync -av --progress '$wslSourcePath/' '$DestPath' 2>&1"
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Log "Copy completed successfully!" $Green
    } else {
        Write-Log "ERROR: Copy failed with exit code $exitCode" $Red
        Write-Log "Output: $result" $Red
        exit 1
    }
}

# Verify the copy
Write-Log "Verifying migration..." $Cyan
if (-not $DryRun) {
    $verifyResult = wsl.exe -d $WslDistro -- bash -c "ls -la '$DestPath' 2>&1"
    Write-Log "Destination contents:" $Cyan
    Write-Host $verifyResult
    
    # Count files
    $fileCount = wsl.exe -d $WslDistro -- bash -c "find '$DestPath' -type f | wc -l"
    $dirCount = wsl.exe -d $WslDistro -- bash -c "find '$DestPath' -type d | wc -l"
    Write-Log "Files copied: $fileCount, Directories: $dirCount" $Green
}

Write-Log "Migration complete!" $Green