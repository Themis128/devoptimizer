@echo off 
setlocal EnableExtensions EnableDelayedExpansion 
set "SCRIPT_DIR=%~dp0" 
set "SCRIPT_DIR=%SCRIPT_DIR%:~0,-1%" 

title 02-Ultra-Performance-NoAdmin.bat - No Admin Required 
echo. 
echo Running 02-Ultra-Performance-NoAdmin.bat... 
echo. 
echo NOTE: This is a non-admin version with limited functionality. 
echo For full functionality, run as Administrator. 
echo. 
powershell -ExecutionPolicy Bypass -NoProfile -Command "Write-Host 'Running basic system check...' -ForegroundColor Green; Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, TotalPhysicalMemory | Format-Table -AutoSize" 
echo. 
echo Operation completed 
pause
exit /b %ERRORLEVEL%
