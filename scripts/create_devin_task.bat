@echo off
schtasks.exe /Create /TN "Devin-Raise-Priority" /TR "powershell.exe -ExecutionPolicy Bypass -File \"D:\DevOptimizer\scripts\raise-devin-priority.ps1\" -Loop -Interval 30" /SC ONLOGON /RL HIGHEST /F
if %errorlevel% equ 0 (
    echo Successfully created scheduled task
) else (
    echo Failed to create scheduled task
    echo Error code: %errorlevel%
)