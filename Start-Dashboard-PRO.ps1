# Launch Dashboard PRO
$ErrorActionPreference = "Continue"

try {
    & "D:\DevOptimizer\Monitor-Dashboard-PRO.ps1" -Continuous -RefreshSeconds 5
} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
