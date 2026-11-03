<#
.SYNOPSIS
    Registers wsl prewarm.
.DESCRIPTION
    Registers wsl prewarm.
#>

# Register-WSL-PreWarm.ps1 - boots the Ubuntu-24.04 distro 15s after logon so
# Devin Desktop / VS Code remote sessions connect instantly instead of racing
# WSL's ~90s cold boot (root cause of the "Remote Extension host terminated
# unexpectedly" popup after reboots). Safe to re-run; -Remove unregisters.
param([switch]$Remove)

$taskName = 'WSL-PreWarm'
$taskPath = '\DevOptimizer\'

if ($Remove) {
    Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed $taskPath$taskName"
    return
}

$action = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument '-d Ubuntu-24.04 --exec true'
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$trigger.Delay = 'PT15S'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Registered $taskPath$taskName - runs 'wsl -d Ubuntu-24.04 --exec true' 15s after your logon."
Write-Host 'No added cost: Docker Desktop already boots the WSL VM at logon; this just starts the distro immediately.'
