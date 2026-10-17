schtasks /create /tn DevOptimizerAdminCleanup /tr powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\admin-cleanup-elevated.ps1" /ru %USERNAME% /rl highest /f
