# Quick Playwright Cleanup
# Kills orphaned browser processes before testing
# CATEGORY: cleanup

Write-Host ""
Write-Host "Cleaning up Playwright processes..." -ForegroundColor Yellow

$beforeMem = (Get-Process | Where-Object { 
    $_.ProcessName -like "*WebKit*" -or 
    $_.ProcessName -like "*chrome-headless*" -or 
    $_.ProcessName -eq "Playwright" 
} | Measure-Object -Property WorkingSet64 -Sum).Sum / 1GB

Get-Process | Where-Object { 
    $_.ProcessName -like "*WebKit*" -or 
    $_.ProcessName -like "*chrome-headless*" -or 
    $_.ProcessName -eq "Playwright" 
} | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 1

Write-Host "Cleaned up orphaned browsers" -ForegroundColor Green
if ($beforeMem -gt 0) {
    Write-Host "Freed: $([math]::Round($beforeMem, 2)) GB" -ForegroundColor Cyan
}

# Show current RAM
$os = Get-CimInstance Win32_OperatingSystem
$freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
Write-Host "Available RAM: $freeRAM GB" -ForegroundColor White
Write-Host ""
