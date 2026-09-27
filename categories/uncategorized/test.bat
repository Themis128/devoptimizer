@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
echo Hello World
exit /b %ERRORLEVEL%
