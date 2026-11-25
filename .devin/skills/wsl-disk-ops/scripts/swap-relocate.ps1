# swap-relocate.ps1 — move the WSL2 swap VHDX off the system drive.
# Idempotent: skips the edit when swapfile= already present. ~5 min downtime.
param([string]$Target = 'D:\wsl-sys')
$log = 'C:\Users\tbaltzakis\logs\swap-relocate.log'
"start $(Get-Date -Format o)" | Out-File $log
if ((Test-Path $Target) -and -not (Get-Item $Target).PSIsContainer) {
  "ABORT: $Target exists as a file — swap path unusable" | Out-File $log -Append
  exit 1
}
New-Item -ItemType Directory -Force $Target | Out-Null
$cfg = "$env:USERPROFILE\.wslconfig"
$txt = [IO.File]::ReadAllText($cfg)
if ($txt -match '(?m)^\s*swapfile\s*=') {
  "swapfile already configured" | Out-File $log -Append
} else {
  Copy-Item $cfg "$cfg.bak-$(Get-Date -Format yyyyMMdd)-swapmove" -Force
  # strip commented-out swapfile lines so no stale directive shadows ours
  $txt = $txt -replace '(?m)^\s*#\s*swapfile\s*=.*\r?\n', ''
  $vhdx = ($Target + '\swap.vhdx') -replace '\\','\\'
  if ($txt -match '(?m)^(swap=\S+)') {
    $txt = $txt -replace '(?m)^(swap=\S+)', "`$1`r`nswapfile=$vhdx"
  } else {
    # no explicit swap size — insert both under [wsl2]
    $txt = $txt -replace '(?m)^(\[wsl2\])', "`$1`r`nswapfile=$vhdx"
  }
  [IO.File]::WriteAllText($cfg, $txt)
  "swapfile=$vhdx added" | Out-File $log -Append
}
Get-Process 'Docker Desktop','com.docker.backend' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 5
wsl.exe --shutdown
Start-Sleep 8
Start-Process "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
"docker relaunched $(Get-Date -Format o)" | Out-File $log -Append
