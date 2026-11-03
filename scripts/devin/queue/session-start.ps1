# Inject live sync context: latest origin/main, open PRs, PRs merged in the last 24h.
$null = [Console]::In.ReadToEnd()
$ctx = @()
try { git fetch --all --prune -q 2>$null; $ctx += "origin/main head: " + (git log -1 --format='%h %s (%cr, %an)' origin/main 2>$null) } catch {}
# Local gh.exe — the earlier `wsl gh` calls (a) hit WSAETIMEDOUT flakes and
# (b) let bash re-parse 'merged:>=DATE' so '>' became a redirect, writing
# '=<date>' junk files into the repo cwd.
$gh = "$env:LOCALAPPDATA\Programs\gh-cli\bin\gh.exe"
if (-not (Test-Path $gh)) { $gh = 'gh' }
try { $ctx += "Open PRs:`n" + (& $gh pr list --limit 30 2>$null | Out-String) } catch {}
try { $ctx += "Merged in last 24h:`n" + (& $gh pr list --state merged --search "merged:>=$((Get-Date).AddDays(-1).ToString('yyyy-MM-dd'))" --limit 20 2>$null | Out-String) } catch {}
$ctx += "Before any PR or push: re-check this list, never duplicate another agent's PR, branch from latest origin/main."

# Process any pending queued commands (FCFS queue persistence)
$queueManager = "C:\Users\tbaltzakis\devin-queue\hooks\queue-manager.ps1"
if (Test-Path $queueManager) {
    $queueResult = & "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $queueManager -Action 'send-next'
    if ($LASTEXITCODE -eq 0) {
        $ctx += "`n[Queue] Next queued command executed successfully"
    } elseif ($LASTEXITCODE -eq 1) {
        $ctx += "`n[Queue] Queued command failed after retries"
    } else {
        $ctx += "`n[Queue] No pending commands in queue"
    }
}

@{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = ($ctx -join "`n") } } | ConvertTo-Json -Compress
