# VS Code Insiders - One-Time Cleanup
# Kills all VS Code Insiders processes immediately
# CATEGORY: cleanup
Write-Host "`nVS Code Insiders One-Time Cleanup" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$processes = Get-Process -Name "Code - Insiders" -ErrorAction SilentlyContinue

if (!$processes) {
    Write-Host "No VS Code Insiders processes running." -ForegroundColor Green
    exit 0
}

$count = ($processes | Measure-Object).Count
$totalMemoryMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)

Write-Host "Found $count processes using $totalMemoryMB MB total" -ForegroundColor Yellow
Write-Host "`nProcess Details:" -ForegroundColor Cyan
$processes | Select-Object Id, @{Name="MemoryMB";Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}} | Format-Table -AutoSize

$response = Read-Host "`nDo you want to kill all these processes? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host "`nKilling processes..." -ForegroundColor Red
    Stop-Process -Name "Code - Insiders" -Force
    Write-Host "Done! All VS Code Insiders processes terminated." -ForegroundColor Green
} else {
    Write-Host "Cancelled." -ForegroundColor Yellow
}
