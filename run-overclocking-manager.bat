@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM Quick launcher for overclocking manager
cd /d "%~dp0"
call portable\overclocking-manager.bat %*
exit /b %ERRORLEVEL%
