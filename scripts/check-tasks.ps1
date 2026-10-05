$tasks = Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
$results = @()
foreach ($t in $tasks) {
    $info = Get-ScheduledTaskInfo -TaskName $t.TaskName
    $results += [pscustomobject]@{
        TaskName = $t.TaskName
        NextRunTime = $info.NextRunTime
        LastRunTime = $info.LastRunTime
        LastTaskResult = $info.LastTaskResult
    }
}
$results | Format-Table -AutoSize