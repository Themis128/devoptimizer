Enable-ScheduledTask -TaskName 'Host-Guard' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'Devin-Session-Manager' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'Devin-Daily-Maintenance' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'Devin-Weekly-Restart' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'Extended-Cleanup' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'Safe-Cleanup-Daily' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'Admin-Cleanup-Weekly' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'Nas-Backup' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'SocialAuto-Maintenance' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'WSL-GPU-Rebind' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'WSL-Memory-Watchdog' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'WSL-PreWarm' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'WSL-Ubuntu-Cleanup' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'Docker-WSL-Sync' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'AdminCleanupTask' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'DevinWSLShutdown' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'Docker WSL Integration Watchdog' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'docker-socket-watch' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'WSL-Guardian' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'WSL-Vsock-Watchdog' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'WSL Vsock Health Reset' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'wsl-recycle-watch' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'WSL-Service-Doctor' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'socialauto-metrics-watchdog' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'SocialAuto-RecapPublishCheck' -TaskPath '\' -ErrorAction SilentlyContinue
Enable-ScheduledTask -TaskName 'SocialAuto-StackWatchdog' -TaskPath '\' -ErrorAction SilentlyContinue
Get-ScheduledTask | Where-Object {$_.TaskName -like '*Docker*' -or $_.TaskName -like '*WSL*' -or $_.TaskName -like '*Devin*' -or $_.TaskName -like '*Host*' -or $_.TaskName -like '*Cleanup*' -or $_.TaskName -like '*Backup*' -or $_.TaskName -like '*Social*' -or $_.TaskName -like '*Nas*' -or $_.TaskName -like '*Admin*'} | Select-Object TaskName, State, TaskPath