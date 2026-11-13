<#
.SYNOPSIS
    Docker Desktop settings persistence watchdog - prevents updates from reverting hardened config
.DESCRIPTION
    Monitors Docker Desktop settings-store.json (DD >= 4.35; legacy settings.json
    fallback) for drift from the desired state. On drift: logs, alerts via ntfy,
    and auto-restores - but only restarts Docker Desktop when the settings file
    was actually modified, and at most once per 6h (restarts are what caused the
    2026-11-13 vsock flap loop when the old script false-positived every run).

    Runs every 5 min as scheduled task \DevOptimizer\DD-Settings-Watchdog.

    Desired state (2026-11-13 rewrite, per docs.docker.com/desktop/settings):
    - settings-store.json: "Ubuntu-24.04" present in IntegratedWslDistros
      (the compose stack's docker.sock lives in that distro - losing the
      integration entry kills every container lane).
    - EnableIntegrationWithDefaultWslDistro must stay $true.
    - userns-remap is NOT checked: Docker Desktop does not support it on the
      WSL2 backend (docker/for-win#6897) and the old script wrote it to
      Ubuntu-24.04:/etc/docker/daemon.json - a distro Docker Desktop never
      reads. That guaranteed-drift key was the false-positive engine.
    - daemon.json is NOT checked for the same reason; DD's engine config is
      %USERPROFILE%\.docker\daemon.json and nothing there needs enforcing.
#>
#requires -Version 5.1
# CATEGORY: monitoring

$ErrorActionPreference = 'SilentlyContinue'

# One-shot elevated rewrap: fix remaining console-popup scheduled tasks
# (this task runs elevated; unelevated runs get Access denied on
# \DevOptimizer\ tasks). Marker prevents re-running every cycle.
try { & 'D:\DevOptimizer\scripts\_rewrap-headless-all.ps1' } catch {}

# Import shared modules
. "$PSScriptRoot\lib\Notify.ps1"
. "$PSScriptRoot\lib\State.ps1"
. "$PSScriptRoot\lib\Log.ps1"

# Configuration
$StoreFile    = "$env:APPDATA\Docker\settings-store.json"
$LegacyFile   = "$env:APPDATA\Docker\settings.json"
$ActiveFile   = if (Test-Path $StoreFile) { $StoreFile } else { $LegacyFile }
$StateFile    = "D:\DevOptimizer\logs\dd-settings-watchdog-state.json"
$LogFile      = "D:\DevOptimizer\logs\dd-settings-watchdog.log"
$RestartCooldownHours = 6

function Write-Log { param($msg, $level='INFO')
    $entry = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $level, $msg
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Get-CurrentState {
    # Returns @{ schema = 'store'|'legacy'|'none'; distros = @(); defaultWsl = $null }
    $result = @{ schema = 'none'; distros = @(); defaultWsl = $null }
    if (-not (Test-Path $ActiveFile)) { return $result }
    try {
        $json = Get-Content $ActiveFile -Raw -ErrorAction Stop | ConvertFrom-Json
    } catch {
        Write-Log "Failed to parse ${ActiveFile}: $($_.Exception.Message)" 'WARN'
        return $result
    }
    if ($ActiveFile -eq $StoreFile) {
        $result.schema = 'store'
        $result.defaultWsl = $json.EnableIntegrationWithDefaultWslDistro
        if ($json.IntegratedWslDistros) { $result.distros = @($json.IntegratedWslDistros) }
    } else {
        # Legacy schema: presence of the file at all is the best signal we get;
        # the old hardening keys were escape-hatch only and no longer exist.
        $result.schema = 'legacy'
    }
    return $result
}

function Test-SettingsDrift {
    param($current)
    $drift = @()
    if ($current.schema -eq 'none') {
        $drift += "settings file missing: $ActiveFile"
        return $drift
    }
    if ($current.schema -eq 'store') {
        if ($current.defaultWsl -ne $true) {
            $drift += "EnableIntegrationWithDefaultWslDistro: current=$($current.defaultWsl) desired=True"
        }
        if ($current.distros -notcontains 'Ubuntu-24.04') {
            $drift += "IntegratedWslDistros missing Ubuntu-24.04: current=[$($current.distros -join ',')]"
        }
    }
    return $drift
}

function Restore-Settings {
    # Re-add Ubuntu-24.04 to IntegratedWslDistros in settings-store.json.
    # Returns $true only when the file was actually rewritten - callers must
    # NOT restart Docker Desktop unless this is $true.
    if ($ActiveFile -ne $StoreFile) {
        Write-Log "Cannot auto-restore: no settings-store.json (legacy schema has no machine-managed integration list)" 'WARN'
        return $false
    }
    try {
        $json = Get-Content $StoreFile -Raw | ConvertFrom-Json
        $changed = $false
        if ($json.EnableIntegrationWithDefaultWslDistro -ne $true) {
            $json.EnableIntegrationWithDefaultWslDistro = $true
            $changed = $true
        }
        $distros = @()
        if ($json.IntegratedWslDistros) { $distros = @($json.IntegratedWslDistros) }
        if ($distros -notcontains 'Ubuntu-24.04') {
            $distros += 'Ubuntu-24.04'
            $json.IntegratedWslDistros = $distros
            $changed = $true
        }
        if (-not $changed) { return $false }
        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $StoreFile -Encoding UTF8
        Write-Log "Restored settings-store.json to desired state" 'WARN'
        return $true
    } catch {
        Write-Log "Restore-Settings failed: $($_.Exception.Message)" 'WARN'
        return $false
    }
}

function Restart-DockerDesktopLimited {
    param($state)
    $last = [DateTime]::MinValue
    if ($state.lastRestart) { [void][DateTime]::TryParse($state.lastRestart, [ref]$last) }
    $cooldown = [TimeSpan]::FromHours($RestartCooldownHours)
    if ((Get-Date) - $last -lt $cooldown) {
        Write-Log "Restart suppressed - last restart $($state.lastRestart) within ${RestartCooldownHours}h cooldown" 'WARN'
        return $false
    }
    & 'C:\Program Files\Docker\Docker\DockerCli.exe' -Shutdown 2>$null
    Get-Process 'Docker Desktop','com.docker.backend' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 5
    Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    return $true
}

# --- Main ---
$desiredNote = 'store-schema: IntegratedWslDistros+=Ubuntu-24.04, EnableIntegrationWithDefaultWslDistro=true'
$current = Get-CurrentState
$drift = Test-SettingsDrift $current

$state = Load-State -StateFile $StateFile -Defaults @{
    lastCheck = [DateTime]::MinValue.ToString('o')
    lastDrift = [DateTime]::MinValue.ToString('o')
    lastRestore = [DateTime]::MinValue.ToString('o')
    lastRestart = $null
    driftCount = 0
    restoreCount = 0
    driftEpisode = $false
}

$now = Get-Date
$state.lastCheck = $now.ToString('o')

if ($drift.Count -gt 0) {
    $state.driftCount++
    $state.lastDrift = $now.ToString('o')
    Write-Log "DRIFT DETECTED ($($current.schema)): $($drift -join '; ')" 'WARN'

    # Alert once per drift episode; reminder every 24h while unresolved.
    $episodeKey = "last_Warning-DDSettingsDrift-$($current.schema)"
    $lastAlert = [DateTime]::MinValue
    if ($state.$episodeKey) { [void][DateTime]::TryParse($state.$episodeKey, [ref]$lastAlert) }
    $shouldAlert = (-not $state.driftEpisode) -or ((Get-Date) - $lastAlert -gt [TimeSpan]::FromHours(24))
    if ($shouldAlert) {
        Send-DevOptAlert -Severity Warning -Title "Docker Desktop Settings Drift Detected" `
            -Message "Drift found ($($current.schema)): $($drift -join '; ')" `
            -Tags 'docker', 'settings', 'watchdog', 'drift' -EventId 1010
        $state.$episodeKey = $now.ToString('o')
        $state.driftEpisode = $true
    }

    # Auto-restore the settings file, then restart DD only if it changed
    # AND the cooldown allows. Never restart on a detection-only pass.
    $rewritten = Restore-Settings
    if ($rewritten) {
        $state.restoreCount++
        $state.lastRestore = $now.ToString('o')
        if (Restart-DockerDesktopLimited $state) {
            $state.lastRestart = $now.ToString('o')
            Write-Log "Docker Desktop restarted to apply restored settings" 'WARN'
            Send-DevOptAlert -Severity Info -Title "Docker Desktop Settings Auto-Restored" `
                -Message "Applied fixes and restarted Docker Desktop (cooldown ${RestartCooldownHours}h)." `
                -Tags 'docker', 'settings', 'watchdog', 'restore' -EventId 1011
        } else {
            Send-DevOptAlert -Severity Warning -Title "Docker Desktop Settings Restored - Restart Pending" `
                -Message "settings-store.json rewritten; Docker Desktop restart deferred by ${RestartCooldownHours}h cooldown. Apply on next DD restart." `
                -Tags 'docker', 'settings', 'watchdog', 'restore' -EventId 1012
        }
    }
} else {
    Write-Log "Settings OK ($($current.schema)) - no drift detected" 'INFO'
    if ($state.driftEpisode) {
        $state.driftEpisode = $false
        Send-DevOptAlert -Severity Info -Title "Docker Desktop Settings Drift Resolved" `
            -Message "settings-store.json back to desired state ($desiredNote)." `
            -Tags 'docker', 'settings', 'watchdog', 'resolved' -EventId 1013
    }
}

Save-State -StateFile $StateFile -State $state
exit 0
