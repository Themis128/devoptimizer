# One-shot: make DevOptimizer scheduled tasks run without console popups.
# - powershell.exe tasks: add -WindowStyle Hidden (idempotent)
# - wsl.exe tasks: rewrap via hidden powershell so wsl's console is hidden too
# - also kills orphaned empty powershell consoles left by broken WSL interop calls

$psTasks = @(
    'Admin-Cleanup-Weekly',
    'Devin-Daily-Maintenance',
    'Docker-WSL-Sync',
    'Extended-Cleanup',
    'Safe-Cleanup-Daily',
    'SocialAuto-Maintenance',
    'WSL-Memory-Watchdog',
    'WSL-Ubuntu-Cleanup'
)

foreach ($name in $psTasks) {
    $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if (-not $task) { Write-Output "SKIP $name (not found)"; continue }
    $action = $task.Actions[0]
    if ($action.Arguments -match 'WindowStyle') {
        Write-Output "OK   $name (already hidden)"
    } else {
        $newArgs = "-WindowStyle Hidden " + $action.Arguments
        $newAction = New-ScheduledTaskAction -Execute $action.Execute -Argument $newArgs
        Set-ScheduledTask -TaskName $name -TaskPath $task.TaskPath -Action $newAction -ErrorAction Stop | Out-Null
        Write-Output "FIX  $name -> added -WindowStyle Hidden"
    }
}

# wsl.exe tasks: replace the action with a hidden powershell wrapper
$wslTasks = @('socialauto-metrics-watchdog', 'WSL-PreWarm')
foreach ($name in $wslTasks) {
    $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if (-not $task) { Write-Output "SKIP $name (not found)"; continue }
    $action = $task.Actions[0]
    if ($action.Execute -match 'powershell') {
        Write-Output "OK   $name (already wrapped)"
    } else {
        $inner = $action.Execute + ' ' + $action.Arguments
        $newAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -Command "' + $inner + '"')
        Set-ScheduledTask -TaskName $name -Action $newAction | Out-Null
        Write-Output "FIX  $name -> wrapped in hidden powershell"
    }
}

# Kill orphaned powershell consoles from broken WSL interop (match only the
# ad-hoc -Command strings used in diagnostics — never -File scripts)
$orphans = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'Win32_Process|Get-ScheduledTask' -and $_.CommandLine -match '-Command' }
foreach ($p in $orphans) {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Output ("KILL orphan powershell pid=" + $p.ProcessId)
}
Write-Output "DONE"
