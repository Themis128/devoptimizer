@echo off
REM One-click elevation for the 2026-10-27 scheduled-task trigger fixes:
REM  1) Devin-Session-Manager: 4h repetition made INDEFINITE (was 1 day then died forever)
REM  2) WSL-Ubuntu-Cleanup: 02:30 -> 02:20 (de-collide with Devin-Weekly-Restart 02:30 Sat)
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','D:\DevOptimizer\logs\trigger-fixes-20261027.ps1' -Wait"
echo.
echo Done. Log: D:\DevOptimizer\logs\trigger-fixes-20261027.log
pause
