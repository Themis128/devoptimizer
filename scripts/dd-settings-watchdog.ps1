<#
.SYNOPSIS
    Docker Desktop settings persistence watchdog - prevents updates from reverting hardened config
.DESCRIPTION
    Monitors Docker Desktop settings.json and daemon.json for drift from the hardened
    configuration applied by wsl-permanent-fix.ps1 Layer 4. On drift: logs, alerts via ntfy,
    and auto-restores. Runs every 5 min as scheduled task \DevOptimizer\DD-Settings-Watchdog.
.NOTES
    Desired state (from wsl-permanent-fix.ps1 Layer 4):
    - settings.json: disableWSLIntegrationAutoConfig=true, wslIntegrationAutoConfigure=false, manageDockerGroup=false
    - daemon.json: userns-remap=default
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
$SettingsFile = "$env:APPDATA\Docker\settings.json"
$DaemonFile   = "/etc/docker/daemon.json"  # Inside WSL, accessed via wsl.exe
$StateFile    = "D:\DevOptimizer\logs\dd-settings-watchdog-state.json"
$LogFile      = "D:\DevOptimizer\logs\dd-settings-watchdog.log"

function Write-Log { param($msg, $level='INFO')
    $entry = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $level, $msg
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Load-DesiredSettings {
    # Returns the desired state we want to enforce
    return @{
        settings = @{
            disableWSLIntegrationAutoConfig = $true
            wslIntegrationAutoConfigure     = $false
            manageDockerGroup               = $false
        }
        daemon = @{
            'userns-remap' = 'default'
        }
    }
}

function Get-CurrentSettings {
    $result = @{ settings = @{}; daemon = @{} }
    
    # Read settings.json (Windows side)
    if (Test-Path $SettingsFile) {
        try {
            $json = Get-Content $SettingsFile -Raw -ErrorAction Stop | ConvertFrom-Json
            $result.settings.disableWSLIntegrationAutoConfig = $json.disableWSLIntegrationAutoConfig
            $result.settings.wslIntegrationAutoConfigure     = $json.wslIntegrationAutoConfigure
            $result.settings.manageDockerGroup               = $json.manageDockerGroup
        } catch {
            Write-Log "Failed to read settings.json: $($_.Exception.Message)" 'WARN'
        }
    }
    
    # Read daemon.json via WSL (Linux side)
    $daemonJson = wsl.exe -d Ubuntu-24.04 -e cat $DaemonFile 2>$null
    if ($daemonJson) {
        try {
            $daemon = $daemonJson | ConvertFrom-Json
            $result.daemon['userns-remap'] = $daemon.'userns-remap'
        } catch {
            Write-Log "Failed to parse daemon.json: $($_.Exception.Message)" 'WARN'
        }
    }
    
    return $result
}

function Test-SettingsDrift {
    param($current, $desired)
    $drift = @()
    
    foreach ($key in $desired.settings.Keys) {
        $currentVal = $current.settings[$key]
        $desiredVal = $desired.settings[$key]
        if ($currentVal -ne $desiredVal) {
            $drift += "settings.${key}: current=$currentVal desired=$desiredVal"
        }
    }
    
    foreach ($key in $desired.daemon.Keys) {
        $currentVal = $current.daemon[$key]
        $desiredVal = $desired.daemon[$key]
        if ($currentVal -ne $desiredVal) {
            $drift += "daemon.${key}: current=$currentVal desired=$desiredVal"
        }
    }
    
    return $drift
}

function Restore-Settings {
    param($desired)
    $actions = @()
    
    # Restore settings.json
    if (Test-Path $SettingsFile) {
        $json = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        $changed = $false
        foreach ($key in $desired.settings.Keys) {
            if ($json.$key -ne $desired.settings[$key]) {
                $json.$key = $desired.settings[$key]
                $changed = $true
            }
        }
        if ($changed) {
            $json | ConvertTo-Json -Depth 5 | Set-Content -Path $SettingsFile -Encoding UTF8
            $actions += "Restored settings.json"
            Write-Log "Restored settings.json to desired state" 'WARN'
        }
    }
    
    # Restore daemon.json via WSL
    $daemonContent = $desired.daemon | ConvertTo-Json -Depth 3
    wsl.exe -d Ubuntu-24.04 -e bash -c "echo '$daemonContent' | sudo tee $DaemonFile > /dev/null" 2>$null | Out-Null
    $actions += "Restored daemon.json"
    Write-Log "Restored daemon.json to desired state" 'WARN'
    
    # Signal Docker Desktop to reload (restart backend)
    & 'C:\Program Files\Docker\Docker\DockerCli.exe' -Shutdown 2>$null
    Get-Process 'Docker Desktop','com.docker.backend' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 5
    Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    $actions += "Restarted Docker Desktop"
    
    return $actions
}

# --- Main ---
$desired = Load-DesiredSettings
$current = Get-CurrentSettings
$drift = Test-SettingsDrift $current $desired

$state = Load-State -StateFile $StateFile -Defaults @{
    lastCheck = [DateTime]::MinValue.ToString('o')
    lastDrift = [DateTime]::MinValue.ToString('o')
    lastRestore = [DateTime]::MinValue.ToString('o')
    driftCount = 0
    restoreCount = 0
}

$now = Get-Date
$state.lastCheck = $now.ToString('o')

if ($drift.Count -gt 0) {
    $state.driftCount++
    $state.lastDrift = $now.ToString('o')
    Write-Log "DRIFT DETECTED: $($drift -join '; ')" 'WARN'
    
    # Alert via ntfy
    Send-DevOptAlert -Severity Warning -Title "Docker Desktop Settings Drift Detected" `
        -Message "Drift found: $($drift -join '; ')" `
        -Tags 'docker', 'settings', 'watchdog', 'drift' -EventId 1010
    
    # Auto-restore
    $actions = Restore-Settings $desired
    $state.restoreCount++
    $state.lastRestore = $now.ToString('o')
    Write-Log "Auto-restored: $($actions -join ', ')" 'WARN'
    
    Send-DevOptAlert -Severity Info -Title "Docker Desktop Settings Auto-Restored" `
        -Message "Applied fixes: $($actions -join ', ')" `
        -Tags 'docker', 'settings', 'watchdog', 'restore' -EventId 1011
} else {
    Write-Log "Settings OK - no drift detected" 'INFO'
}

Save-State -StateFile $StateFile -State $state
exit 0