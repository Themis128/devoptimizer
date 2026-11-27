# Restart Docker Desktop with admin rights
Get-Process -Name 'com.docker.backend', 'Docker Desktop' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 5
$ddExe = @("$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe",
           'C:\Program Files\Docker\Docker\Docker Desktop.exe') |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($ddExe) { & $ddExe } else { Write-Error 'Docker Desktop.exe not found' }