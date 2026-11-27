<#
.SYNOPSIS
    Safely compact WSL and Docker VHDX files to reclaim host disk space.
.DESCRIPTION
    Compacts docker_data.vhdx and Ubuntu ext4.vhdx after graceful shutdown.
    Requires Administrator. Reports before/after sizes and space reclaimed.
    Registered as hub command: compact-wsl-vhdx (category: storage)
#>
#requires -Version 5.1
# CATEGORY: storage
param(
    [switch]$DryRun,
    [switch]$SkipDocker,
    [switch]$SkipWSL,
    [switch]$Force,
    [int]$TimeoutMinutes = 10
)

$ErrorActionPreference = 'Stop'
$logFile = 'D:\DevOptimizer\logs\compact-wsl-vhdx.log'

function Log { param($msg) Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) }
function Write-Out { param($msg) Write-Host $msg; Log $msg }
function Write-Warn { param($msg) Write-Host $msg -ForegroundColor Yellow; Log "WARN: $msg" }
function Write-Err { param($msg) Write-Host $msg -ForegroundColor Red; Log "ERROR: $msg" }

# --- Admin check ------------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "This script requires Administrator privileges. Re-run from elevated PowerShell."
    exit 1
}

# --- Paths ------------------------------------------------------------------
$dockerVhdx = "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx"
$wslDistro = 'Ubuntu-24.04'
$wslVhdxPath = 'E:\WSL\Ubuntu-24.04\ext4.vhdx'

# Find WSL distro VHDX
$wslVhdx = $null
if (Test-Path $wslVhdxPath) {
    $wslVhdx = $wslVhdxPath
}

Write-Out "=== WSL VHDX Compaction Tool ==="
Write-Out ""

# --- Show current sizes -----------------------------------------------------
function Get-VHDXSize { param($path)
    if (Test-Path $path) {
        $size = (Get-Item $path).Length
        return [math]::Round($size / 1GB, 2)
    }
    return 0
}

$dockerBefore = Get-VHDXSize $dockerVhdx
$wslBefore = Get-VHDXSize $wslVhdx

Write-Out "Current VHDX sizes:"
Write-Out "  docker_data.vhdx : $dockerBefore GB"
if ($wslVhdx) { Write-Out "  Ubuntu ext4.vhdx  : $wslBefore GB" }
else { Write-Out "  Ubuntu ext4.vhdx  : NOT FOUND" }
Write-Out ""

if ($DryRun) {
    Write-Out "DRY RUN - no changes will be made"
    exit 0
}

# --- Confirm -----------------------------------------------------------------
if (-not $Force) {
    Write-Warn "This will:"
    Write-Warn "  1. Stop Docker Desktop"
    Write-Warn "  2. Shutdown WSL ($wslDistro)"
    Write-Warn "  3. Compact VHDX files (can take several minutes)"
    Write-Warn "  4. Restart Docker Desktop"
    Write-Warn ""
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -ne 'y') { Write-Out "Cancelled"; exit 0 }
}

# --- Helper: wait for process to exit ---------------------------------------
function Wait-ProcessExit { param($name, $timeoutSec)
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process $name -ErrorAction SilentlyContinue)) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

# --- Step 1: Stop Docker Desktop --------------------------------------------
Write-Out "[1/6] Stopping Docker Desktop..."
& 'C:\Program Files\Docker\Docker\DockerCli.exe' -Shutdown 2>$null | Out-Null
Start-Sleep -Seconds 3
Get-Process 'Docker Desktop','com.docker.backend','vmmemWSL' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
if (-not (Wait-ProcessExit 'vmmemWSL' 60)) {
    Write-Warn "vmmemWSL still running after 60s, continuing anyway..."
}

# --- Step 2: Shutdown WSL ---------------------------------------------------
if (-not $SkipWSL) {
    Write-Out "[2/6] Shutting down WSL ($wslDistro)..."
    wsl.exe --terminate $wslDistro 2>$null | Out-Null
    Start-Sleep -Seconds 3
    wsl.exe --shutdown 2>$null | Out-Null
    Start-Sleep -Seconds 5

    # Verify WSL is down
    $attempts = 0
    while ((Get-Process vmmemWSL -ErrorAction SilentlyContinue) -and $attempts -lt 30) {
        Start-Sleep -Seconds 2
        $attempts++
    }
    if (Get-Process vmmemWSL -ErrorAction SilentlyContinue) {
        Write-Err "WSL did not shut down completely (vmmemWSL still running)"
        exit 1
    }
    Write-Out "WSL shut down confirmed"
} else {
    Write-Out "[2/6] Skipping WSL shutdown (SkipWSL)"
}

# --- Step 3: Compact docker_data.vhdx ---------------------------------------
if ((-not $SkipDocker) -and (Test-Path $dockerVhdx)) {
    Write-Out "[3/6] Compacting docker_data.vhdx ($dockerBefore GB)..."
    try {
        Optimize-VHD -Path $dockerVhdx -Mode Full -ErrorAction Stop
        Write-Out "  docker_data.vhdx compacted successfully"
    } catch {
        Write-Warn "  Optimize-VHD failed for docker_data.vhdx: $_"
        Write-Warn "  Trying fallback: optimize-vhd via cmd..."
        cmd.exe /c "optimize-vhd -Path `"$dockerVhdx`" -Mode Full" 2>&1 | ForEach-Object { Write-Out "  $_" }
    }
} else {
    Write-Out "[3/6] Skipping docker_data.vhdx"
}

# --- Step 4: Compact WSL ext4.vhdx ------------------------------------------
if ((-not $SkipWSL) -and $wslVhdx -and (Test-Path $wslVhdx)) {
    Write-Out "[4/6] Compacting Ubuntu ext4.vhdx ($wslBefore GB)..."
    try {
        Optimize-VHD -Path $wslVhdx -Mode Full -ErrorAction Stop
        Write-Out "  ext4.vhdx compacted successfully"
    } catch {
        Write-Warn "  Optimize-VHD failed for ext4.vhdx: $_"
        Write-Warn "  Trying fallback: optimize-vhd via cmd..."
        cmd.exe /c "optimize-vhd -Path `"$wslVhdx`" -Mode Full" 2>&1 | ForEach-Object { Write-Out "  $_" }
    }
} else {
    Write-Out "[4/6] Skipping WSL VHDX"
}

# --- Step 5: Restart Docker Desktop -----------------------------------------
Write-Out "[5/6] Starting Docker Desktop..."
$ddExe = @("$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe",
           'C:\Program Files\Docker\Docker\Docker Desktop.exe') |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($ddExe) { Start-Process $ddExe } else { Write-Out 'WARN: Docker Desktop.exe not found - relaunch skipped' }
Write-Out "Waiting for Docker engine..."
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ((Get-Date) -lt $deadline) {
    docker info 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Out "Docker engine ready"; break }
    Start-Sleep -Seconds 5
}
if ($LASTEXITCODE -ne 0) { Write-Warn "Docker engine not ready within timeout" }

# --- Step 6: Verify results -------------------------------------------------
Write-Out "[6/6] Verifying results..."
Start-Sleep -Seconds 5

$dockerAfter = Get-VHDXSize $dockerVhdx
$wslAfter = Get-VHDXSize $wslVhdx

Write-Out ""
Write-Out "=== Compaction Results ==="
Write-Out "docker_data.vhdx: $dockerBefore GB -> $dockerAfter GB (freed: $([math]::Round($dockerBefore - $dockerAfter, 2)) GB)"
if ($wslVhdx) {
    Write-Out "Ubuntu ext4.vhdx  : $wslBefore GB -> $wslAfter GB (freed: $([math]::Round($wslBefore - $wslAfter, 2)) GB)"
}
$totalFreed = [math]::Round(($dockerBefore + $wslBefore) - ($dockerAfter + $wslAfter), 2)
Write-Out "TOTAL FREED: $totalFreed GB"
Write-Out ""
Write-Out "Log: $logFile"

exit 0