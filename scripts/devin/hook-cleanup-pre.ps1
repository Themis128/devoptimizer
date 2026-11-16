<#
.SYNOPSIS
    Devin cleanup hook - runs before devin-doctor operations
.DESCRIPTION
    Pre-hook for devin-cleanup operations. Validates WSL state and Devin environment.
#>
param(
    [string]$Operation
)

$distro = 'Ubuntu-24.04'

function Invoke-Wsl([string]$cmd) {
    $out = & wsl.exe -d $distro -- bash -c $cmd 2>$null
    $joined = (@($out) -join "`n") -replace "`0", ''
    return ($joined -split "`r?`n") | Where-Object { $_ -ne '' }
}

Write-Host "[devin-cleanup:pre] Validating environment for operation: $Operation" -ForegroundColor Cyan

# Check WSL reachable
$ping = Invoke-Wsl 'echo ok'
if ($ping -notmatch 'ok') {
    Write-Host "[devin-cleanup:pre] FAIL: WSL distro '$distro' unreachable" -ForegroundColor Red
    exit 1
}

# Check if Devin is running (for operations that modify bundle)
if ($Operation -in @('repair-bundle', 'cleanup-sessions', 'daily-maintenance')) {
    $appProc = Get-Process -Name 'Devin' -ErrorAction SilentlyContinue
    if ($appProc) {
        Write-Host "[devin-cleanup:pre] WARN: Devin.exe is running - bundle operations will be deferred" -ForegroundColor Yellow
    }
}

Write-Host "[devin-cleanup:pre] OK: Environment validated" -ForegroundColor Green
exit 0