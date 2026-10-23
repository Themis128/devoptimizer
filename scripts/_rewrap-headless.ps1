# Re-wrap every \DevOptimizer\ + root task action in conhost.exe --headless.
# Bare powershell.exe actions allocate a visible console on every run.
$log = 'D:\DevOptimizer\scripts\_rewrap-headless.log'
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') rewrap run ===" | Out-File $log -Append -Encoding utf8
$conhost = 'C:\Windows\System32\conhost.exe'
$targets = @()
Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue | ForEach-Object { $targets += $_ }
Get-ScheduledTask -TaskName 'AdminCleanupTask','socialauto-metrics-watchdog' -ErrorAction SilentlyContinue | ForEach-Object { $targets += $_ }
foreach ($t in $targets) {
    try {
        $action = $t.Actions[0]
        if ($action.Execute -match 'conhost') {
            "SKIP $($t.TaskName) (already headless)" | Out-File $log -Append -Encoding utf8
            continue
        }
        $newArgs = '--headless ' + $action.Execute + ' ' + $action.Arguments
        $newAction = New-ScheduledTaskAction -Execute $conhost -Argument $newArgs.Trim()
        Set-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Action $newAction -ErrorAction Stop | Out-Null
        "FIX  $($t.TaskName) -> $newArgs" | Out-File $log -Append -Encoding utf8
    } catch {
        "ERR  $($t.TaskName) : $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
    }
}
"DONE" | Out-File $log -Append -Encoding utf8
