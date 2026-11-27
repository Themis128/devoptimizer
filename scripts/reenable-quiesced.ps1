# reenable-quiesced.ps1 - one-shot elevated: enable tasks listed in the
# compactor quiesce state file, then delete the file.
$log = 'D:\DevOptimizer\logs\vmcompute-unstick.log'
function W($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $log -Append -Encoding ascii }
$qfile = 'D:\DevOptimizer\logs\.quiesced-probe-tasks'
if (-not (Test-Path $qfile)) { W 'reenable: no quiesce file - nothing to do'; exit 0 }
$ok = 0; $fail = @()
Get-Content $qfile | ForEach-Object {
    $l = $_.Trim(); if (-not $l) { return }
    $sep = $l.LastIndexOf('|'); $p = $l.Substring(0,$sep); $n = $l.Substring($sep+1)
    try { Enable-ScheduledTask -TaskName $n -TaskPath $p -ErrorAction Stop | Out-Null; $ok++ }
    catch { $fail += "$p$n" }
}
W "reenable: $ok enabled; fails: $(if ($fail) {$fail -join ', '} else {'none'})"
if (-not $fail) { Remove-Item $qfile -Force -ErrorAction SilentlyContinue; W 'reenable: quiesce file removed' }
