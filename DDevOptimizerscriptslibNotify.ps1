<#
.SYNOPSIS
    Shared notification module for DevOptimizer scripts - ntfy.sh + Event Log
.DESCRIPTION
    Provides Send-DevOptAlert function with severity levels, ntfy.sh integration,
    Windows Event Log fallback, local logging, and rate limiting.
.NOTES
    Requires: DevOptimizer event source (New-EventLog -LogName Application -Source DevOptimizer)
#>
#requires -Version 5.1

$ErrorActionPreference = 'SilentlyContinue'

# Configuration
$NtfyTopic = 'devoptimizer-alerts'
$NtfyServer = 'https://ntfy.cloudless.gr'
$RateLimitMinutes = 5
$StateFile = "D:\DevOptimizer\logs\notify-rate-limit-state.json"

function Load-RateLimitState {
    if (Test-Path $StateFile) {
        try {
            Get-Content $StateFile -Raw -ErrorAction Stop | ConvertFrom-Json
        } catch {
            @{}
        }
    } else {
        @{}
    }
}

function Save-RateLimitState {
    param($state)
    $state | ConvertTo-Json -Depth 3 | Set-Content -Path $StateFile -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Test-RateLimit {
    param($key)
    $state = Load-RateLimitState
    $now = [DateTime]::UtcNow
    if ($state.ContainsKey($key)) {
        $last = [DateTime]::Parse($state[$key])
        if (($now - $last).TotalMinutes -lt $RateLimitMinutes) {
            return $false  # Rate limited
        }
    }
    $state[$key] = $now.ToString('o')
    Save-RateLimitState $state
    return $true  # Not rate limited
}

function Send-Ntfy {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Severity,
        [string[]]$Tags,
        [int]$EventId
    )
    $headers = @{
        'Title' = $Title
        'Priority' = switch ($Severity) { 'Critical' { 5 }; 'Warning' { 4 }; default { 3 } }
        'Tags' = ($Tags -join ',')
    }
    if ($EventId) { $headers['X-Event-ID'] = $EventId.ToString() }
    
    try {
        Invoke-RestMethod -Method POST -Uri "$NtfyServer/$NtfyTopic" -Body $Message -Headers $headers -TimeoutSec 10
        return $true
    } catch {
        Write-Warning "ntfy.sh send failed: $($_.Exception.Message)"
        return $false
    }
}

function Write-EventLogEntry {
    param(
        [string]$Message,
        [string]$Severity,
        [int]$EventId
    )
    $entryType = switch ($Severity) { 'Critical' { 'Error' }; 'Warning' { 'Warning' }; default { 'Information' } }
    try {
        Write-EventLog -LogName 'Application' -Source 'DevOptimizer' -EventId $EventId -EntryType $entryType -Message $Message -ErrorAction Stop
        return $true
    } catch {
        # Event source may not exist - that's OK, we still log locally
        return $false
    }
}

function Write-LocalLog {
    param(
        [string]$Message,
        [string]$Severity
    )
    $logFile = "D:\DevOptimizer\logs\notify.log"
    $entry = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Severity, $Message
    Add-Content -Path $logFile -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Send-DevOptAlert {
    <#
    .SYNOPSIS
        Sends an alert via ntfy.sh with Event Log fallback and local logging.
    .PARAMETER Severity
        Info, Warning, or Critical
    .PARAMETER Title
        Alert title (used for rate limiting key)
    .PARAMETER Message
        Alert message body
    .PARAMETER Tags
        Optional tags for ntfy categorization
    .PARAMETER EventId
        Windows Event Log event ID
    .PARAMETER Force
        Bypass rate limiting
    #>
    param(
        [ValidateSet('Info','Warning','Critical')][string]$Severity = 'Info',
        [string]$Title,
        [string]$Message,
        [string[]]$Tags = @(),
        [int]$EventId = 0,
        [switch]$Force
    )

    if (-not $Title -or -not $Message) {
        Write-Error "Send-DevOptAlert requires -Title and -Message"
        return
    }

    $rateKey = "$Title|$Severity"
    if (-not $Force -and -not (Test-RateLimit $rateKey)) {
        Write-Verbose "Rate limited: $rateKey (max 1 per $RateLimitMinutes min)"
        return
    }

    # Build ntfy tags
    $ntfyTags = @('devoptimizer')
    if ($Severity -eq 'Critical') { $ntfyTags += 'critical' }
    elseif ($Severity -eq 'Warning') { $ntfyTags += 'warning' }
    else { $ntfyTags += 'info' }
    $ntfyTags += $Tags

    # Send via ntfy.sh
    $ntfyOk = Send-Ntfy -Title $Title -Message $Message -Severity $Severity -Tags $ntfyTags -EventId $EventId

    # Fallback to Windows Event Log
    $eventLogOk = Write-EventLogEntry -Message $Message -Severity $Severity -EventId $EventId

    # Always log locally
    Write-LocalLog -Message "$Title: $Message" -Severity $Severity

    # Verbose output
    $channels = @()
    if ($ntfyOk) { $channels += 'ntfy' }
    if ($eventLogOk) { $channels += 'EventLog' }
    $channels += 'local'
    Write-Verbose "Alert sent via: $($channels -join ', ') - [$Severity] $Title"
}
