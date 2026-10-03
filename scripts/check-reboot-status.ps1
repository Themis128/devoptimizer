<#
.SYNOPSIS
    Checks reboot status.
.DESCRIPTION
    Checks reboot status.
#>

# Read-only check: uptime, build, pending reboot markers, key services
$os = Get-CimInstance Win32_OperatingSystem
$boot = $os.LastBootUpTime
$uptime = (Get-Date) - $boot
Write-Host ("LastBoot: {0}  Uptime: {1}h" -f $boot, [math]::Round($uptime.TotalHours,1))
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Write-Host ("Build: {0}.{1} ({2})" -f $cv.CurrentBuildNumber, $cv.UBR, $cv.DisplayVersion)

$sm = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
$pfr = $sm.PendingFileRenameOperations
if ($pfr) {
    $n = @($pfr | Where-Object { $_ }).Count
    Write-Host "PENDING REBOOT: PendingFileRenameOperations present ($n entries)"
} else {
    Write-Host "PENDING REBOOT: none (PendingFileRenameOperations absent/empty)"
}
$wu  = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
$cbs = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
Write-Host ("WU RebootRequired key: {0}  CBS RebootPending key: {1}" -f $wu, $cbs)

# Disk free
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    if ($_.Free -ne $null -and $_.Used -ne $null) {
        $total = $_.Used + $_.Free
        if ($total -gt 0) {
            Write-Host ("Drive {0}: {1:N1} GB free of {2:N1} GB ({3:N0}% free)" -f $_.Name, ($_.Free/1GB), ($total/1GB), (100*$_.Free/$total))
        }
    }
}

# Key services health
foreach ($svc in 'wuauserv','BITS','Docker Desktop Service','com.docker.service') {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) { Write-Host ("Service {0}: {1}" -f $s.Name, $s.Status) }
}
# vmmemWSL memory
$v = Get-Process vmmemWSL -ErrorAction SilentlyContinue
if ($v) { Write-Host ("vmmemWSL working set: {0:N2} GB" -f ($v.WorkingSet64/1GB)) } else { Write-Host "vmmemWSL: not running" }
# PRI-Driver still disabled?
$pd = sc.exe qc PRI-Driver 2>&1 | Select-String 'START_TYPE'
Write-Host ("PRI-Driver: " + $pd)
