Disable-ScheduledTask -TaskName 'Host-Guard' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Session-Manager' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Daily-Maintenance' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Weekly-Restart' -ErrorAction SilentlyContinue
Get-ScheduledTask | Where-Object {$_.TaskName -like '*Docker*' -or $_.TaskName -like '*WSL*' -or $_.TaskName -like '*Devin*' -or $_.TaskName -like '*Host*'} | Select-Object TaskName, State, TaskPath