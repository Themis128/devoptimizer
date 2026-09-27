# VS Code Monitor - Aggressive Mode
# Lower thresholds for systems with limited RAM
Write-Host "Starting VS Code Monitor in AGGRESSIVE MODE..." -ForegroundColor Red
Write-Host "Using lower thresholds: 2GB total, 512MB per process, max 10 processes`n" -ForegroundColor Yellow
& "D:\DevOptimizer\VSCode-ProcessMonitor.ps1" -TotalMemoryThresholdMB 2048 -SingleProcessThresholdMB 512 -MaxProcessCount 10 -LogToFile
