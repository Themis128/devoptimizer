<#
.SYNOPSIS
    Check system restore points and log to file.
#>
$ErrorActionPreference = 'Continue'

$logFile = "D:\DevOptimizer\logs\restore-points-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$restorePoints = Get-ComputerRestorePoint

if ($restorePoints) {
    $output = $restorePoints | Sort-Object SequenceNumber -Descending | Select-Object -First 10 | Format-Table SequenceNumber, Description, CreationTime, Type -AutoSize | Out-String
    $count = ($restorePoints | Measure-Object).Count
    $output += "`nTotal restore points: $count"
    Set-Content -Path $logFile -Value $output -Encoding UTF8
    Write-Host "Restore points logged to: $logFile" -ForegroundColor Green
    $output
} else {
    $msg = "No restore points found or access denied."
    Set-Content -Path $logFile -Value $msg -Encoding UTF8
    Write-Host $msg -ForegroundColor Yellow
}