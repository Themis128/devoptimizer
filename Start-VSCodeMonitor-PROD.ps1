# VS Code Monitor - Production Mode
# This will actively monitor and kill processes that exceed thresholds
Write-Host "Starting VS Code Monitor in PRODUCTION MODE..." -ForegroundColor Green
Write-Host "Monitoring will be ACTIVE - processes will be killed if thresholds exceeded`n" -ForegroundColor Yellow
& "D:\DevOptimizer\VSCode-ProcessMonitor.ps1" -LogToFile
