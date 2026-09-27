# Register-SocialAuto-Maintenance.ps1 - schedules the zero-downtime socialauto
# maintenance pass (Maintain-SocialAuto.ps1) daily at 04:00. Safe to re-run;
# -Remove unregisters. No admin needed: docker commands run via the user's
# WSL docker group membership.
# CATEGORY: maintenance
<#
.SYNOPSIS
    Registers (or removes) the daily 04:00 scheduled task that runs the
    zero-downtime socialauto maintenance pass.

.DESCRIPTION
    Creates scheduled task \DevOptimizer\SocialAuto-Maintenance running
    Maintain-SocialAuto.ps1 daily at 04:00 as the current user (no admin:
    docker is reachable via WSL group membership). -Remove unregisters.

.PARAMETER Remove
    Unregister the scheduled task instead of creating it.

.EXAMPLE
    .\Register-SocialAuto-Maintenance.ps1
#>
param([switch]$Remove)

$taskName = 'SocialAuto-Maintenance'
$taskPath = '\DevOptimizer\'
$scriptPath = 'D:\DevOptimizer\scripts\socialauto\Maintain-SocialAuto.ps1'

if ($Remove) {
    Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed $taskPath$taskName"
    return
}

if (-not (Test-Path $scriptPath)) {
    Write-Host "[FAIL] $scriptPath not found - install the Hub first." -ForegroundColor Red
    exit 1
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\socialauto\Maintain-SocialAuto.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At '04:00'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Registered $taskPath$taskName - runs Maintain-SocialAuto.ps1 daily at 04:00."
Write-Host 'Zero-downtime by design: prunes exited containers/dangling images/old build'
Write-Host 'cache, reports unhealthy containers and DMR health. No healthy container is'
Write-Host 'ever restarted; -Remediate stays opt-in via a manual Hub run.'
