# WSL2 Memory Optimizer for Playwright Testing
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\optimize-wsl-memory.ps1            # dry-run (preview)
#   powershell -ExecutionPolicy Bypass -File .\optimize-wsl-memory.ps1 -Apply     # write + restart WSL
#   powershell -ExecutionPolicy Bypass -File .\optimize-wsl-memory.ps1 -Apply -MemoryGB 12 -SwapGB 8 -Processors 10
#   powershell -ExecutionPolicy Bypass -File .\optimize-wsl-memory.ps1 -Restore   # restore newest backup
# CATEGORY: cleanup

param(
    # 16GB is the wedge-free floor: the 2026-09-06 Docker integration wedge
    # (0x8007274c) was caused by a low memory cap + no swap while Docker
    # Desktop's VM was running. Do not go below this while Docker is in use.
    [int]$MemoryGB = 16,
    [int]$SwapGB = 8,
    [int]$Processors = 12,
    [switch]$Apply,
    [switch]$Restore,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-ColorLog {
    param($Message, $Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

$wslConfigPath = "$env:USERPROFILE\.wslconfig"
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

Write-ColorLog "============================================================" "Cyan"
Write-ColorLog "   WSL2 Memory Optimizer (mode: $(if ($Restore) { 'RESTORE' } elseif ($Apply) { 'APPLY' } else { 'DRY-RUN' }))" "Cyan"
Write-ColorLog "============================================================" "Cyan"
Write-ColorLog ""

# ============================================
# Restore mode: copy the newest backup back
# ============================================
if ($Restore) {
    $backup = Get-ChildItem "$env:USERPROFILE\.wslconfig.backup-*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $backup) {
        Write-ColorLog "No .wslconfig.backup-* found in $env:USERPROFILE" "Red"
        exit 1
    }
    Copy-Item $backup.FullName $wslConfigPath -Force
    Write-ColorLog ("Restored {0} -> {1}" -f $backup.Name, $wslConfigPath) "Green"
    Write-ColorLog "Run 'wsl --shutdown' to apply." "Yellow"
    exit 0
}

if (-not (Test-Path $wslConfigPath)) {
    Write-ColorLog "No .wslconfig found at $wslConfigPath - nothing to transform." "Red"
    exit 1
}

# ============================================
# Build the transformed configuration in memory
# (transform the EXISTING config so mirrored networking, experimental flags and
# any future settings are preserved - never regenerate from a stale template)
# ============================================
$lines = Get-Content -LiteralPath $wslConfigPath
$out = New-Object System.Collections.Generic.List[string]
$seen = @{}
foreach ($line in $lines) {
    if ($line -match '^\s*memory\s*=')      { $out.Add("memory=$MemoryGB GB".Replace(' ', '')); $seen.memory = $true; continue }
    if ($line -match '^\s*swap\s*=')        { $out.Add("swap=$SwapGB GB".Replace(' ', '')); $seen.swap = $true; continue }
    if ($line -match '^\s*processors\s*=')  { $out.Add("processors=$Processors"); $seen.processors = $true; continue }
    $out.Add($line)
}
if (-not $seen.memory)      { $out.Add("memory=$MemoryGB GB".Replace(' ', '')) }
if (-not $seen.swap)        { $out.Add("swap=$SwapGB GB".Replace(' ', '')) }
if (-not $seen.processors)  { $out.Add("processors=$Processors") }
$newConfig = $out -join "`r`n"

# Show old vs new
$current = Get-Content -LiteralPath $wslConfigPath
Write-ColorLog "Changes (current -> new):" "Cyan"
foreach ($key in @('memory', 'swap', 'processors')) {
    $oldLine = ($current | Where-Object { $_ -match "^\s*$key\s*=" } | Select-Object -First 1)
    $newLine = ($out | Where-Object { $_ -match "^\s*$key\s*=" } | Select-Object -First 1)
    if ($oldLine -ne $newLine) {
        Write-ColorLog ("  {0}" -f $oldLine) "Yellow"
        Write-ColorLog ("  {0}" -f $newLine) "Green"
    }
}

if (-not $Apply) {
    Write-ColorLog ""
    Write-ColorLog "DRY-RUN: nothing was written. Re-run with -Apply to write this config" "Cyan"
    Write-ColorLog "and restart WSL. A backup of the current config is taken on -Apply." "Cyan"
    exit 0
}

# ============================================
# Safety: Docker running containers + wedge floor
# ============================================
$containers = docker ps --format '{{.Names}}' 2>$null
if ($containers) {
    Write-ColorLog "Docker containers currently running:" "Yellow"
    $containers | ForEach-Object { Write-ColorLog "  $_" "Gray" }
    if (-not $Force) {
        Write-ColorLog "Reducing WSL memory while containers run can starve the Docker VM" "Red"
        Write-ColorLog "(the 2026-09-06 wedge). Re-run with -Force to proceed anyway," "Red"
        Write-ColorLog "or stop the containers first." "Red"
        exit 1
    }
}
if ($MemoryGB -lt 16) {
    Write-ColorLog "WARNING: memory=${MemoryGB}GB is below the 16GB wedge-free floor." "Red"
    if (-not $Force) {
        Write-ColorLog "Re-run with -Force to accept this risk." "Red"
        exit 1
    }
}

# ============================================
# Backup + write + restart WSL
# ============================================
$backupPath = "$env:USERPROFILE\.wslconfig.backup-$timestamp"
Copy-Item -LiteralPath $wslConfigPath $backupPath -Force
Write-ColorLog "Backup: $backupPath" "Green"

Set-Content -Path $wslConfigPath -Value $newConfig -Encoding UTF8
Write-ColorLog "Written: $wslConfigPath" "Green"

Write-ColorLog "Shutting down WSL to apply (all distros + Docker VM close)..." "Yellow"
wsl --shutdown
Write-ColorLog "Done. WSL restarts automatically on next use; Docker Desktop will restart its VM." "Green"
