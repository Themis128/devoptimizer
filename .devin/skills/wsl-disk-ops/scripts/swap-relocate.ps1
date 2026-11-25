# swap-relocate.ps1 — move the WSL2 swap VHDX off the system drive.
# Idempotent: skips the edit when swapfile= already present. ~5 min downtime.
param([string]$Target = 'D:\wsl-sys')
$log = 'C:\Users\tbaltzakis\logs\swap-relocate.log'
"start $(Get-Date -Format o)" | Out-File $log
New-Item -ItemType Directory -Force $Target | Out-Null
$cfg = "$env:USERPROFILE\.wslconfig"
Copy-Item $cfg "$cfg.bak-$(Get-Date -Format yyyyMMdd)-swapmove" -Force
$txt = [IO.File]::ReadAllText($cfg)
if ($txt -notmatch 'swapfile') {
  $vhdx = ($Target + '\swap.vhdx') -replace '\\','\\'
  $txt = $txt -replace '(?m)^(swap=\S+)', "`$1`r`nswapfile=$vhdx"
  [IO.File]::WriteAllText($cfg, $txt)
  "swapfile=$vhdx added" | Out-File $log -Append
} else { "swapfile already configured" | Out-File $log -Append }
Get-Process 'Docker Desktop','com.docker.backend' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 5
wsl.exe --shutdown
Start-Sleep 8
& "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe" | Out-Null
"docker relaunched $(Get-Date -Format o)" | Out-File $log -Append
