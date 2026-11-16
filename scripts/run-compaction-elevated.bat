@echo off
powershell.exe -Command "Start-Process powershell -Verb RunAs -ArgumentList '-File D:\DevOptimizer\scripts\compact-wsl-vhdx.ps1 -ForceAll -Force' -Wait"