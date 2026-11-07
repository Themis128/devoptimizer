<#
.SYNOPSIS
    Shared notification module for DevOptimizer - unified alerting via ntfy.sh + Event Log
.DESCRIPTION
    Provides Send-DevOptAlert function for consistent notifications across all DevOptimizer scripts.
    Uses ntfy.cloudless.gr (same as wsl-guardian) with rate limiting and Event Log fallback.
.NOTES
    Requires: ntfy topic (from wsl-guardian config), DevOptimizer event source registered
#>
#requires -Version 5.1

$ErrorActionPreference = 'Stop'

# Configuration - uses same topic as wsl-guardian
$script:NtfyTopic = 'devoptimizer-alerts'
$script:NtfyBaseUrl = 'https://ntfy.cloudless.gr'
$script:RateLimitMinutes = 5
$script:StateFile = 'D:\DevOptimizer\logs\notify-state.json'

function Load-NotifyState {
    if (Test-Path $script:StateFile) {
        try { return Get-Content $script:StateFile -Raw | ConvertFrom-Json } catch { }
    }
    return [pscustomobject]@{}
}

function Save-NotifyState {
    param($state)
    $state | ConvertTo-Json -Depth 3 | Set-Content -Path $script:StateFile -Force -Encoding ASCII
}

function Test-RateLimit {
    param([string]$Key)
    $state = Load-NotifyState
    $now = [DateTime]::Now
    $lastKey = "last_$Key"
    if ($state.PSObject.Properties[$lastKey]) {
        $last = [DateTime]::Parse($state.($lastKey))
        if (($now - $last).TotalMinutes -lt $script:RateLimitMinutes) {
            return $false
        }
    }
    $state | Add-Member -NotePropertyName $lastKey -NotePropertyValue $now.ToString('o') -Force
    Save-NotifyState $state
    return $true
}

function Send-Ntfy {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Priority = 'high',  # default, high, urgent, low, min
        [string[]]$Tags = @()
    )
    try {
        $headers = @{
            'Title'    = $Title
            'Priority' = $Priority
        }
        if ($Tags.Count -gt 0) {
            $headers['Tags'] = $Tags -join ','
        }
        Invoke-RestMethod -Uri "$script:NtfyBaseUrl/$script:NtfyTopic" `
            -Method Post -Body $Message -Headers $headers -TimeoutSec 10
        return $true
    } catch {
        return $false
    }
}

function Write-EventLogEntry {
    param(
        [string]$Message,
        [string]$EntryType = 'Warning',  # Information, Warning, Error
        [int]$EventId = 1000
    )
    try {
        Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' `
            -EventId $EventId -EntryType $EntryType -Message $Message `
            -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

<#
.SYNOPSIS
    Send a DevOptimizer alert via ntfy.sh and/or Windows Event Log
.PARAMETER Severity
    Info, Warning, or Critical - determines priority, event type, and tags
.PARAMETER Title
    Short alert title (shown in ntfy notification)
.PARAMETER Message
    Detailed alert message body
.PARAMETER Tags
    Optional array of tags for ntfy (e.g., 'wsl', 'docker', 'cleanup')
.PARAMETER EventId
    Custom Event Log ID (default: auto-assigned by severity)
.PARAMETER Force
    Bypass rate limiting (use sparingly for critical alerts)
.EXAMPLE
    Send-DevOptAlert -Severity Warning -Title "WSL Unresponsive" -Message "Ubuntu-24.04 not responding after 3 probes" -Tags 'wsl', 'guardian'
.EXAMPLE
    Send-DevOptAlert -Severity Critical -Title "Host Memory Critical" -Message "Available 800 MB - auto-bounce initiated" -Force
#>
function Send-DevOptAlert {
    [CmdletBinding()]
    param(
        [ValidateSet('Info','Warning','Critical')]
        [string]$Severity = 'Warning',
        [string]$Title,
        [string]$Message,
        [string[]]$Tags = @(),
        [int]$EventId = 0,
        [switch]$Force
    )

    if (-not $Title) { throw 'Title is required' }
    if (-not $Message) { throw 'Message is required' }

    # Rate limit key: severity + title (normalized)
    $rateKey = "$Severity-$($Title -replace '[^a-zA-Z0-9]','')"
    if (-not $Force -and -not (Test-RateLimit $rateKey)) {
        # Rate limited - still log locally for debugging
        $logFile = 'D:\DevOptimizer\logs\notify-rate-limited.log'
        Add-Content -Path $logFile -Value ("{0} RATE_LIMITED: {1} - {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Title, $Message)
        return
    }

    # Determine ntfy priority and Event Log type from severity
    $ntfyPriority = switch ($Severity) {
        'Info'      { 'default' }
        'Warning'   { 'high' }
        'Critical'  { 'urgent' }
    }
    $eventType = switch ($Severity) {
        'Info'      { 'Information' }
        'Warning'   { 'Warning' }
        'Critical'  { 'Error' }
    }
    $defaultEventId = switch ($Severity) {
        'Info'      { 1000 }
        'Warning'   { 1001 }
        'Critical'  { 1002 }
    }
    $eventIdToUse = if ($EventId -gt 0) { $EventId } else { $defaultEventId }

    # Add severity tag
    $allTags = $Tags + @($($Severity).ToLower())

    # Send via ntfy
    $ntfyOk = Send-Ntfy -Title $Title -Message $Message -Priority $ntfyPriority -Tags $allTags

    # Fallback to Event Log (always write for audit trail)
    $eventMsg = "[{0}] {1}: {2}" -f $Severity, $Title, $Message
    $eventOk = Write-EventLogEntry -Message $eventMsg -EntryType $eventType -EventId $eventIdToUse

    # Log locally
    $logFile = 'D:\DevOptimizer\logs\notify.log'
    $status = if ($ntfyOk -and $eventOk) { 'OK' } elseif ($ntfyOk) { 'NTFY_ONLY' } elseif ($eventOk) { 'EVENTLOG_ONLY' } else { 'FAILED' }
    Add-Content -Path $logFile -Value ("{0} [{1}] {2} - {3} (ntfy={4} eventlog={5})" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Severity, $Title, $status, $ntfyOk, $eventOk)
}

# Allow direct invocation for testing
if ($MyInvocation.InvocationName -eq $MyInvocation.ScriptName) {
    $Severity = 'Info'
    $Title = 'Test Alert'
    $Message = 'This is a test notification from DevOptimizer'
    $Tags = @('test')
    $Force = $false
    Send-DevOptAlert -Severity $Severity -Title $Title -Message $Message -Tags $Tags -Force:$Force
}

