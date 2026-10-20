Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue | ForEach-Object {
    $t = $_
    $triggers = $t.Triggers
    foreach ($tr in $triggers) {
        $timeInfo = $tr.StartBoundary
        if ($tr.DaysOfWeek) { $timeInfo = "$($tr.DaysOfWeek) at $timeInfo" }
        [pscustomobject]@{
            TaskName = $t.TaskName
            Time = $timeInfo
        }
    }
} | Format-Table -AutoSize