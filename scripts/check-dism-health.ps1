# DISM CheckHealth - run elevated
Dism /Online /Cleanup-Image /CheckHealth
$exitCode = $LASTEXITCODE
Write-Host "Exit code: $exitCode"
Read-Host "Press Enter to exit"