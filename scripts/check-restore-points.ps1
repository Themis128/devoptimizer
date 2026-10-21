<#
.SYNOPSIS
    Check system restore points.
#>
$ErrorActionPreference = 'Continue'

$restorePoints = Get-ComputerRestorePoint
if ($restorePoints) {
    $restorePoints | Sort-Object SequenceNumber -Descending | Select-Object -First 10 | Format-Table SequenceNumber, Description, CreationTime, Type -AutoSize
    $count = ($restorePoints | Measure-Object).Count
    Write-Host "Total restore points: $count" -ForegroundColor Cyan
} else {
    Write-Host "No restore points found or access denied." -ForegroundColor Yellow
}