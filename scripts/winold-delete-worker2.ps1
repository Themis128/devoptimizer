<#
.SYNOPSIS
    Deletes C:\Windows.old (and leftover upgrade folders) as SYSTEM via a
    one-shot scheduled task. For files that deny delete even to elevated
    admins - TrustedInstaller-owned WinSxS component trees inside Windows.old.
.DESCRIPTION
    Run elevated: registers a scheduled task running the rd passes as
    SYSTEM, waits for completion, then unregisters the task. Pair with
    scripts\win11-os-deep-cleanup.ps1 which handles the bulk deletion first.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\winold-delete-worker2.ps1
#>
# CATEGORY: cleanup
#requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'
$log = 'D:\DevOptimizer\logs\winold-worker2.log'
$taskName = 'DevOptimizer-WinOldDelete'
function Log([string]$m) { Add-Content $log ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m); Write-Host $m }

$worker = @'
$ErrorActionPreference = 'Continue'
$log = 'D:\DevOptimizer\logs\winold-worker2.log'
function Log([string]$m) { Add-Content $log ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }
Log "=== worker body start (user=$env:USERNAME) ==="
foreach ($t in 'C:\Windows.old','C:\$WINDOWS.~BT','C:\$WinREAgent','C:\Windows10Upgrade','C:\$GetCurrent') {
    if (-not (Test-Path -LiteralPath $t)) { continue }
    for ($i = 1; $i -le 6 -and (Test-Path -LiteralPath $t); $i++) {
        Log "rd pass $i on $t"
        & cmd.exe /c "rd /s /q `"$t`"" 2>&1 | ForEach-Object { Log "  $_" }
        Start-Sleep -Seconds 5
    }
    Log "$t exists now: $(Test-Path -LiteralPath $t)"
}
Log "=== worker body done ==="
'@
$workerPath = Join-Path $env:TEMP 'winold-delete-body.ps1'
Set-Content -Path $workerPath -Value $worker -Encoding UTF8

Log "registering SYSTEM task $taskName"
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$workerPath`""
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Log "task started, waiting (max 60 min)..."
$deadline = (Get-Date).AddMinutes(60)
while ((Get-Date) -lt $deadline) {
    if ((Test-Path $log) -and (Select-String -Path $log -Pattern 'worker body done' -Quiet)) { break }
    Start-Sleep -Seconds 20
}
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item $workerPath -Force -ErrorAction SilentlyContinue
Log "done. Windows.old exists: $(Test-Path 'C:\Windows.old')"
