Disable-ScheduledTask -TaskName 'Host-Guard' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Session-Manager' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Daily-Maintenance' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Weekly-Restart' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Extended-Cleanup' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Safe-Cleanup-Daily' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Admin-Cleanup-Weekly' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Nas-Backup' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'SocialAuto-Maintenance' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Get-ScheduledTask | Where-Object {$_.TaskName -like '*Docker*' -or $_.TaskName -like '*WSL*' -or $_.TaskName -like '*Devin*' -or $_.TaskName -like '*Host*' -or $_.TaskName -like '*Cleanup*' -or $_.TaskName -like '*Backup*' -or $_.TaskName -like '*Social*' -or $_.TaskName -like '*Nas*'} | Select-Object TaskName, State, TaskPath