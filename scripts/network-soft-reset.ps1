<#
.SYNOPSIS
    Soft network-stack reset - the automatable alternative to
    `netsh winsock reset` (which on Windows 11 is near no-op because LSPs are
    deprecated since Win8, AND requires a reboot).
.DESCRIPTION
    Rebuilds the socket-adjacent state that actually wedges the WSL vsock /
    port-forwarding path, without a reboot:
      1. DNS resolver cache flush + ARP cache clear
      2. Physical adapter restart (DHCP renew comes free with the bounce)

    Causes a ~5-10s connectivity blip. Must only run inside a safe window -
    the caller (vhdx-compact-on-devin-exit.ps1) gates on Devin/idle before
    firing the task. Runs elevated via the on-demand task
    \DevOptimizer\Net-Soft-Reset (far-future Once trigger; schtasks /run
    fires it regardless). Once per calendar day via stamp file.

    Escalation tier for the heal-resistant vsock-wedge class: fires when
    wedge evidence in wsl-repair.log is NEWER than today's wsl --shutdown
    heal (i.e. the heal did not hold). Next tier above this is a real
    reboot - still manual.
#>
#requires -Version 5.1
# CATEGORY: maintenance
param(
    [switch]$RegisterTask
)

$ErrorActionPreference = 'Continue'
$log = 'D:\DevOptimizer\logs\net-soft-reset.log'
$stampFile = 'D:\DevOptimizer\logs\.net-soft-reset-fired'
function Log([string]$m) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" }

$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($RegisterTask) {
    if (-not $elevated) { Log '[task] -RegisterTask needs elevation (watchdog piggyback lane)'; exit 3 }
    $act = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' `
        -Argument '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\network-soft-reset.ps1"'
    # Far-future Once trigger = on-demand only; schtasks /run fires it any time.
    $trg = New-ScheduledTaskTrigger -Once -At (Get-Date '2030-01-01')
    $pri = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Net-Soft-Reset' `
        -Action $act -Trigger $trg -Principal $pri -Force | Out-Null
    Log '[task] \DevOptimizer\Net-Soft-Reset registered (on-demand, headless, elevated)'
    exit 0
}

Log '=== net-soft-reset start ==='
if (-not $elevated) { Log 'not elevated - adapter restart impossible, aborting'; exit 3 }

# Once per calendar day - repeated blips are worse than a persistent wedge.
$today = Get-Date -Format 'yyyy-MM-dd'
if ((Test-Path $stampFile) -and ((Get-Content $stampFile -Raw).Trim() -eq $today)) {
    Log 'already ran today - skipping'
    exit 0
}

try {
    . 'D:\DevOptimizer\scripts\lib\Notify.ps1'
    Send-DevOptAlert -Severity Warning -Title 'Network soft reset' `
        -Message 'Heal-resistant vsock wedge - flushing DNS/ARP and restarting physical adapters (~10s blip).' `
        -Tags 'network','wsl' -ErrorAction SilentlyContinue
} catch { }

& ipconfig.exe /flushdns | Out-Null
& netsh.exe interface ip delete arpcache | Out-Null
Log 'dns resolver + arp cache flushed'

$adapters = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Hyper-V|Virtual|Bluetooth' })
foreach ($a in $adapters) {
    try {
        Log "restarting adapter: $($a.Name) ($($a.InterfaceDescription))"
        Restart-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction Stop
    } catch {
        Log "adapter $($a.Name) restart failed: $($_.Exception.Message)"
    }
}

# Wait for adapters to come back, then renew DHCP explicitly.
Start-Sleep -Seconds 8
$back = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
& ipconfig.exe /renew 2>&1 | Out-Null
Log ("adapters back up: {0}/{1}" -f $back.Count, $adapters.Count)

Set-Content -Path $stampFile -Value $today
try {
    Send-DevOptAlert -Severity Info -Title 'Network soft reset done' `
        -Message ("{0}/{1} adapters restarted. If the vsock wedge persists past this, the remaining fix is a reboot." -f $back.Count, $adapters.Count) `
        -Tags 'network','wsl' -ErrorAction SilentlyContinue
} catch { }
Log '=== net-soft-reset done ==='
exit 0
