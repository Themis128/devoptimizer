# VS Code Monitor - Test Mode (Dry Run)
# This will show what WOULD happen without actually killing processes
Write-Host "Starting VS Code Monitor in TEST MODE..." -ForegroundColor Cyan
Write-Host "This will monitor but NOT kill any processes`n" -ForegroundColor Yellow
& "D:\DevOptimizer\VSCode-ProcessMonitor.ps1" -DryRun -LogToFile
