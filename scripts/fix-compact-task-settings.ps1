# fix-compact-task-settings.ps1 - one-shot elevated: disable the
# StartWhenAvailable catch-up on Nightly-Vhdx-Compact (2026-11-26: a missed
# 05:00 re-fired at 00:05 mid-session and wedged the host). Keep WakeToRun
# (the 05:00 forced window is intentional) + PT2H execution limit.
$log = 'D:\DevOptimizer\logs\vmcompute-unstick.log'
function W($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $log -Append -Encoding ascii }
try {
    $s = New-ScheduledTaskSettingsSet -StartWhenAvailable:$false -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Set-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Nightly-Vhdx-Compact' -Settings $s -ErrorAction Stop | Out-Null
    $t = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Nightly-Vhdx-Compact'
    W "taskfix: StartWhenAvailable=$($t.Settings.StartWhenAvailable) WakeToRun=$($t.Settings.WakeToRun) limit=$($t.Settings.ExecutionTimeLimit)"
} catch { W "taskfix failed: $($_.Exception.Message)" }
