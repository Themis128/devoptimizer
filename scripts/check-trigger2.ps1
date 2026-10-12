$t = New-ScheduledTaskTrigger -Once -At '12:00'
$t.Repetition | Format-List *