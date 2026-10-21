Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue | ForEach-Object {
    $t = $_
    foreach ($tr in $t.Triggers) {
        [pscustomobject]@{
            TaskName = $t.TaskName
            Schedule = $tr.GetType().Name
            Time     = $tr.StartBoundary
            Repetition = $tr.RepetitionInterval
        }
    }
} | Format-Table -AutoSize