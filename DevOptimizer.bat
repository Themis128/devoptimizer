@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
	if "%~1"=="" (
	    powershell.exe -ExecutionPolicy Bypass -File "D:\DevOptimizer\devoptimizer.ps1" -Menu
	) else (
	    powershell.exe -ExecutionPolicy Bypass -File "D:\DevOptimizer\devoptimizer.ps1" %*
	)
exit /b %ERRORLEVEL%
