$t = New-ScheduledTaskTrigger -Once -At '12:00'
$t.GetType().FullName
$t.Repetition.GetType().FullName