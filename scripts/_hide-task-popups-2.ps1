$t = Get-ScheduledTask -TaskName 'SocialAuto-Maintenance' -ErrorAction Stop
$a = $t.Actions[0]
$newAction = New-ScheduledTaskAction -Execute $a.Execute -Argument ("-WindowStyle Hidden " + $a.Arguments)
Set-ScheduledTask -TaskName 'SocialAuto-Maintenance' -TaskPath $t.TaskPath -Action $newAction -ErrorAction Stop | Out-Null
Write-Output "FIX SocialAuto-Maintenance"

$t = Get-ScheduledTask -TaskName 'WSL-PreWarm' -ErrorAction Stop
$a = $t.Actions[0]
$inner = $a.Execute + ' ' + $a.Arguments
$newAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -Command "' + $inner + '"')
Set-ScheduledTask -TaskName 'WSL-PreWarm' -TaskPath $t.TaskPath -Action $newAction -ErrorAction Stop | Out-Null
Write-Output "FIX WSL-PreWarm"
Write-Output "DONE"
