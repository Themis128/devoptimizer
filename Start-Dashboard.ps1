# Dashboard Launcher - Keeps window open on errors
$ErrorActionPreference = "Continue"

Write-Host "Starting VS Code Monitor Dashboard..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to exit`n" -ForegroundColor Yellow

try {
    & "D:\DevOptimizer\Monitor-Dashboard.ps1" -Continuous -RefreshSeconds 5
}
catch {
    Write-Host "`nError occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
