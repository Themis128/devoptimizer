# sshd-system-diag.ps1 - runs ONCE as SYSTEM via a temp scheduled task.
# Captures sshd's real startup failure in the service-equivalent context
# (service runs as LocalSystem; interactive/elevated-admin -d masks it).
# Writes D:\DevOptimizer\logs\sshd-system-diag.log
$ErrorActionPreference = 'Continue'
$out = 'D:\DevOptimizer\logs\sshd-system-diag.log'
$sshd = 'C:\Windows\System32\OpenSSH\sshd.exe'
"=== system-diag $(Get-Date -Format o) user=$env:USERNAME ===" | Out-File $out
# whoami proves the context
whoami | Out-File $out -Append
# config test as SYSTEM
& $sshd -t 2>&1 | Out-File $out -Append
"--- sshd -t exit=$LASTEXITCODE ---" | Out-File $out -Append
# foreground debug on scratch port with -E file logging, killed after 10s
$log = 'D:\DevOptimizer\logs\sshd-system-debug.log'
$p = Start-Process -FilePath $sshd -ArgumentList '-ddd','-p','22222','-E',$log -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 10
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1
"--- sshd -d exit=$($p.ExitCode) ---" | Out-File $out -Append
if (Test-Path $log) { Get-Content $log | Out-File $out -Append }
"=== done ===" | Out-File $out -Append
