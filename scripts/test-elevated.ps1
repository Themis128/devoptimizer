Write-Host "Running elevated: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Host "IsAdmin: $([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)"

Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue | Select-Object TaskName, State, TaskPath | Format-Table -AutoSize