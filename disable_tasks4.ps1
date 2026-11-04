Disable-ScheduledTask -TaskName 'Admin-Cleanup-Weekly' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Daily-Maintenance' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Weekly-Restart' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Extended-Cleanup' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Nas-Backup' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'AdminCleanupTask' -ErrorAction SilentlyContinue
Get-ScheduledTask | Where-Object {$_.TaskName -like '*Docker*' -or $_.TaskName -like '*WSL*' -or $_.TaskName -like '*Devin*' -or $_.TaskName -like '*Host*' -or $_.TaskName -like '*Cleanup*' -or $_.TaskName -like '*Backup*' -or $_.TaskName -like '*Social*' -or $_.TaskName -like '*Nas*' -or $_.TaskName -like '*Admin*'} | Select-Object TaskName, State, TaskPath