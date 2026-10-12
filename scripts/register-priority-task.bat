@echo off
schtasks /create /tn "Devin-Lower-Priority" /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"D:\DevOptimizer\scripts\lower-devin-priority.ps1\" -Loop -Interval 30" /sc ONSTART /ru SYSTEM /rl HIGHEST /f
if %errorlevel% equ 0 (
    echo Task created successfully
) else (
    echo Failed to create task
    exit /b 1
)