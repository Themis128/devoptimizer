@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
echo Testing batch execution
pause
exit /b %ERRORLEVEL%
