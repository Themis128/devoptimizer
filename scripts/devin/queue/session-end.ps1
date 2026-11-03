# Record session end and raise a Windows toast; optionally POST to a webhook if DEVIN_WEBHOOK_URL is set.
$raw = [Console]::In.ReadToEnd()
$q = 'C:\Users\tbaltzakis\devin-queue'
$e = try { $raw | ConvertFrom-Json } catch { $null }
$msg = "Devin session $($e.session_id) ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Add-Content "$q\sessions.log" $msg
if ($env:DEVIN_WEBHOOK_URL) { try { Invoke-RestMethod -Method Post -Uri $env:DEVIN_WEBHOOK_URL -ContentType 'application/json' -Body (@{ text = $msg } | ConvertTo-Json) -TimeoutSec 10 | Out-Null } catch {} }
try { msg.exe * /TIME:30 $msg 2>$null } catch {}

# Ensure queue state is persisted on session end (FCFS queue persistence)
$queueManager = "C:\Users\tbaltzakis\devin-queue\hooks\queue-manager.ps1"
if (Test-Path $queueManager) {
    # Verify queue file exists and is valid JSON
    $queueStatePath = "$q\queue-state.json"
    if (Test-Path $queueStatePath) {
        try {
            $queueContent = Get-Content $queueStatePath -Raw -Encoding UTF8
            $null = $queueContent | ConvertFrom-Json
            Add-Content "$q\sessions.log" "[Queue] Queue state verified and persisted at session end"
        } catch {
            Add-Content "$q\sessions.log" "[Queue] WARNING: Queue state file exists but is invalid JSON at session end"
        }
    } else {
        Add-Content "$q\sessions.log" "[Queue] No queue state file at session end"
    }
}

exit 0
