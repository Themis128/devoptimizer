# Restart Docker Desktop with admin rights
Get-Process -Name 'com.docker.backend', 'Docker Desktop' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 5
& 'C:\Program Files\Docker\Docker\Docker Desktop.exe'