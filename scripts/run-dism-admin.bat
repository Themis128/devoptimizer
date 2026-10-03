:: SYNOPSIS: Runs dism admin.
@echo off
Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart
echo.
echo DISM Exit Code: %ERRORLEVEL%
pause