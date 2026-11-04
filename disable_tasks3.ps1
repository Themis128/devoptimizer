Disable-ScheduledTask -TaskName 'Admin-Cleanup-Weekly' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Daily-Maintenance' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Devin-Weekly-Restart' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Extended-Cleanup' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Nas-Backup' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'AdminCleanupTask' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'DevinWSLShutdown' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'socialauto-metrics-watchdog' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'SocialAuto-RecapPublishCheck' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'SocialAuto-StackWatchdog' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'WSL Vsock Health Reset' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'wsl-recycle-watch' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'WSL-Service-Doctor' -ErrorAction SilentlyContinue
Get-ScheduledTask | Where-Object {$_.TaskName -like '*Docker*' -or $_.TaskName -like '*WSL*' -or $_.TaskName -like '*Devin*' -or $_.TaskName -like '*Host*' -or $_.TaskName -like '*Cleanup*' -or $_.TaskName -like '*Backup*' -or $_.TaskName -like '*Social*' -or $_.TaskName -like '*Nas*' -or $_.TaskName -like '*Admin*'} | Select-Object TaskName, State, TaskPath