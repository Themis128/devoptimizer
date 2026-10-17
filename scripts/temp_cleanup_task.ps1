$taskName = 'DevOptimizerAdminCleanup'
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Force
}
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\admin-cleanup-elevated.ps1"'
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force
Start-ScheduledTask -TaskName $taskName
while ((Get-ScheduledTask -TaskName $taskName).State -eq 'Running') {
    Start-Sleep 5
}
Unregister-ScheduledTask -TaskName $taskName -Force