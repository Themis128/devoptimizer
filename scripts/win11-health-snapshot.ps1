<#
.SYNOPSIS
    Windows 11 health snapshot: SMART, Defender, PnP devices, services, event-log errors.
.DESCRIPTION
    Windows 11 health snapshot: SMART, Defender, PnP devices, services, event-log errors.
#>

# Read-only Windows 11 health snapshot - no changes made
$ErrorActionPreference = 'SilentlyContinue'
Write-Host '=== WINDOWS 11 HEALTH SNAPSHOT ===' -ForegroundColor Cyan

# 1. Disks / storage health
Write-Host "`n-- Storage --"
Get-PhysicalDisk | ForEach-Object { Write-Host ("{0}: Health={1} Op={2} Size={3:N0}GB" -f $_.FriendlyName, $_.HealthStatus, $_.OperationalStatus, ($_.Size/1GB)) }
Get-Volume | Where-Object DriveLetter | ForEach-Object {
    $pct = if ($_.Size) { [math]::Round(100*($_.SizeRemaining/$_.Size),0) } else { 0 }
    Write-Host ("{0}: {1} free {2}% of {3:N0}GB" -f $_.DriveLetter, $_.FileSystem, $pct, ($_.Size/1GB)) }

# 2. Pending reboot?
$rb = @()
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $rb += 'CBS' }
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $rb += 'WU' }
$pendingRename = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue) -ne $null
if ($pendingRename) { $rb += 'FileRename' }
Write-Host ("`n-- Reboot pending: {0} --" -f ($(if ($rb) { $rb -join ', ' } else { 'no' })))

# 3. Windows Update service state
$wu = Get-Service wuauserv
Write-Host ("WU service: {0}" -f $wu.Status)

# 4. Defender
$mp = Get-MpComputerStatus
Write-Host ("`n-- Defender: RealTime={0} Definitions={1} ({2}) --" -f $mp.RealTimeProtectionEnabled, $mp.AntivirusSignatureVersion, $mp.AntivirusSignatureLastUpdated)

# 5. Devices in error state
$errDev = Get-PnpDevice | Where-Object { $_.Status -eq 'Error' }
Write-Host ("`n-- Devices with errors: {0} --" -f ($errDev | Measure-Object).Count)
$errDev | Select-Object -First 8 | ForEach-Object { Write-Host ("  {0} [{1}]: {2}" -f $_.FriendlyName, $_.InstanceId, $_.Problem) }

# 6. Critical/Error events last 48h
Write-Host "`n-- Critical/Error events (48h) --"
$crit = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddHours(-48)} -MaxEvents 40
$crit | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
    $sample = ($_.Group | Select-Object -First 1).Message
    if ($sample) { $sample = ($sample -split "`n")[0].Trim() }
    Write-Host ("  {0}x {1} [{2}] {3}" -f $_.Count, $_.Name, $_.Group[0].TimeCreated.ToString('MM-dd HH:mm'), $sample) }

# 7. Services crashed repeatedly (last 48h, Service Control Manager 7031/7034)
$svcFail = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'; Id=7031,7034; StartTime=(Get-Date).AddHours(-48)} -ErrorAction SilentlyContinue
Write-Host ("`n-- Services crashed in 48h: {0} events --" -f ($svcFail | Measure-Object).Count)
$svcFail | Group-Object { ($_.Message -replace '.*service\s+','' -replace '\s+terminated.*','') } | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object { Write-Host ("  {0}x {1}" -f $_.Count, $_.Name) }

# 8. Memory / pagefile
$os = Get-CimInstance Win32_OperatingSystem
Write-Host ("`n-- RAM: {0:N1}GB total, {1:N1}GB free | Last boot: {2:MM-dd HH:mm} --" -f ($os.TotalVisibleMemorySize/1MB), ($os.FreePhysicalMemory/1MB), $os.LastBootUpTime)

# 9. DNS resolution quick test
try { $null = Resolve-DnsName microsoft.com -ErrorAction Stop; Write-Host 'DNS resolution: OK' } catch { Write-Host 'DNS resolution: FAILED' -ForegroundColor Red }

# 10. System Restore enabled on C:?
$sr = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Select-Object -First 1
$vss = vssadmin list shadows 2>$null | Select-String 'shadow'
Write-Host ("System restore/shadows present: {0}" -f [bool]($sr -or $vss))

# 11. Fast Startup / pending chkdsk
$dirty = fsutil dirty query C: 2>$null
Write-Host ("C: dirty bit: {0}" -f ($dirty -join ' ').Replace('Dirty Bit Set : ',''))
