<#
.SYNOPSIS
    Create a system restore point before maintenance operations.
#>
$ErrorActionPreference = 'Stop'

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$description = "Pre-restore audit $timestamp"

Write-Host "Creating system restore point: $description" -ForegroundColor Cyan

try {
    Checkpoint-Computer -Description $description -RestorePointType MODIFY_SETTINGS
    Write-Host "System restore point created successfully." -ForegroundColor Green
    
    # Verify the restore point
    $restorePoints = Get-ComputerRestorePoint
    $latest = $restorePoints | Where-Object { $_.Description -eq $description } | Select-Object -First 1
    if ($latest) {
        Write-Host "Verified restore point: Sequence $($latest.SequenceNumber), Time $($latest.CreationTime)" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to create restore point: $($_.Exception.Message)"
    exit 1
}