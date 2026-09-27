@echo off 
setlocal EnableExtensions EnableDelayedExpansion 
set "SCRIPT_DIR=%~dp0" 
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%" 

title  - Standard Mode-Install-Dev-Tools.bat 
echo. 
echo Running 03-Install-Dev-Tools.bat... 
echo. 
powershell -ExecutionPolicy Bypass -Command "& {Set-ExecutionPolicy Bypass -Scope Process -Force; & '%SCRIPT_DIR%\dev-optimizer-fixed.ps1' -Mode 'Basic' -NoPause}" 

if %errorlevel% neq 0 ( 
echo ERROR: Operation failed Make sure you are running as Administrator. 
pause 
exit /b 1 
) 

echo Operation completed successfully 
pause
