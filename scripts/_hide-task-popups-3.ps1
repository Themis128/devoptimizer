# v3: switch task actions to `conhost.exe --headless` — zero console window.
# -WindowStyle Hidden still allocates a visible conhost; --headless never does.
# Runs elevated. Rewrites every task action so Execute=conhost.exe and
# Arguments="--headless <original exe> <original args>". Idempotent.
$log = 'D:\DevOptimizer\scripts\_hide-v3.log'
$names = @(
    'socialauto-metrics-watchdog','Admin-Cleanup-Weekly','Devin-Daily-Maintenance',
    'Docker-WSL-Sync','Extended-Cleanup','Safe-Cleanup-Daily','SocialAuto-Maintenance',
    'WSL-Memory-Watchdog','WSL-PreWarm','WSL-Ubuntu-Cleanup'
)
foreach ($name in $names) {
    try {
        $task = Get-ScheduledTask -TaskName $name -ErrorAction Stop
        $action = $task.Actions[0]
        if ($action.Execute -match 'conhost') {
            Write-Output "OK   $name (already headless)" | Out-File $log -Append -Encoding utf8
            continue
        }
        if ($action.Execute -match 'powershell') {
            # already wrapped in hidden powershell for wsl tasks -> unwrap to the inner command
            if ($action.Arguments -match '-Command\s+"(.+)"') {
                $newArgs = '--headless ' + $Matches[1]
            } else {
                $newArgs = '--headless ' + $action.Execute + ' ' + $action.Arguments
            }
        } else {
            $newArgs = '--headless ' + $action.Execute + ' ' + $action.Arguments
        }
        $newAction = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' -Argument $newArgs
        Set-ScheduledTask -TaskName $name -TaskPath $task.TaskPath -Action $newAction -ErrorAction Stop | Out-Null
        Write-Output "FIX  $name -> $newArgs" | Out-File $log -Append -Encoding utf8
    } catch {
        Write-Output "ERR  $name : $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
    }
}
Write-Output "DONE" | Out-File $log -Append -Encoding utf8
