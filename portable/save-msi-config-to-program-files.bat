@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal EnableExtensions
if defined DEVOPT_HOME goto rootReady
set "DEVOPT_HOME=D:\DevOptimizer"
:rootReady
set "TARGET_PS1=%DEVOPT_HOME%\config\overclocking\save-msi-config-to-program-files.ps1"
if not exist "%TARGET_PS1%" (
echo [ERROR] PowerShell script not found: %TARGET_PS1%
exit /b 1
)
where pwsh >nul 2>nul
if %errorlevel% EQU 0 (
set "PS_CMD=pwsh"
) else (
set "PS_CMD=powershell"
)
%PS_CMD% -NoProfile -ExecutionPolicy Bypass -File "%TARGET_PS1%" %*
endlocal
