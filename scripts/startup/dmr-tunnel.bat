@echo off
REM dmr-tunnel.bat - keep omv:12436 forwarded to this PC's Docker Model Runner
REM Used by Nextcloud assistant on cloud.cloudless.gr
REM Single-instance guard: exit if an ssh -R 12436 is already running.
powershell -NoProfile -Command "exit [int]((Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'ssh.exe' -and $_.CommandLine -match '12436' } | Measure-Object).Count -gt 0)"
if errorlevel 1 exit /b 0
:loop
ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=6 -o ExitOnForwardFailure=yes -N -R 0.0.0.0:12436:127.0.0.1:12436 github-omv
timeout /t 15 /nobreak >nul
goto loop
