@echo off
echo Creating Devin-Lower-Priority scheduled task...
echo This requires Administrator privileges.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\create-priority-task.ps1"
echo.
echo If the task was not created, run this file as Administrator:
echo Right-click this file -> "Run as administrator"
pause