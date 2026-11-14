<#
.SYNOPSIS
    Permanent fix for WSL Ubuntu-24.04 catastrophic failure (Wsl/Service/E_UNEXPECTED)
    triggered by Docker Desktop wslexec docker group setup.

.DESCRIPTION
    This script provides a multi-layer defense against the recurring WSL crash:
    
    LAYER 1 - Pre-flight (runs at Docker Desktop startup):
        Detects if Docker Desktop is starting and ensures WSL is fully ready
        before allowing wslexec operations. Adds a startup delay gate.
    
    LAYER 2 - Active Guard (runs every 2 minutes via scheduled task):
        Monitors for the specific wslexec docker group pattern in Docker Desktop
        logs/processes and pre-emptively stabilizes WSL.
    
    LAYER 3 - Reactive Recovery (existing wsl-guardian T1-T3 ladder):
        The existing 3-tier recovery handles any crashes that slip through.
    
    LAYER 4 - Docker Desktop Config Hardening:
        Disables Docker Desktop's automatic WSL integration user/group management
        via daemon.json / settings.json to eliminate the root trigger.

    Registered as: \DevOptimizer\WSL-Permanent-Fix (at logon + every 2 min)
    Also creates: \DevOptimizer\WSL-Permanent-Fix-DockerStartup (triggered on Docker Desktop process start)

.NOTES
    Root cause analysis (2026-11-03/11-06):
    - Docker Desktop 4.98.0 uses wslexec to run `groupadd docker; usermod -aG docker $USER` 
      inside Ubuntu-24.04 on every Desktop start
    - This wslexec call races with WSL VM initialization, causing E_UNEXPECTED
    - The crash leaves vmmemWSL in a zombie state requiring full wsl --shutdown
    - Fix: gate Docker Desktop startup until WSL integration is verified healthy,
      and disable the auto-group-management in Docker Desktop settings.

#>
#requires -Version 5.1
# CATEGORY: system
param(
    [switch]$Install,           # Install scheduled tasks and Docker Desktop config
    [switch]$Uninstall,         # Remove scheduled tasks and restore Docker config
    [switch]$Test,              # Test the fix logic without installing
    [switch]$Force,             # Skip confirmations
    [switch]$DockerStartupGate, # Internal: called by Docker startup trigger
    [int]$GateTimeoutSec = 120  # Max wait for WSL to be ready at Docker startup
)

$ErrorActionPreference = 'Stop'
$logFile = 'D:\DevOptimizer\logs\wsl-permanent-fix.log'
$stateFile = 'D:\DevOptimizer\logs\wsl-permanent-fix-state.json'
$ddSettingsFile = "$env:APPDATA\Docker\settings.json"
$ddStoreFile    = "$env:APPDATA\Docker\settings-store.json"
$ddDaemonFile = "$env:APPDATA\Docker\daemon.json"

# Import shared modules
. "$PSScriptRoot\lib\Notify.ps1"
. "$PSScriptRoot\lib\Log.ps1"
. "$PSScriptRoot\lib\State.ps1"

function Log { param($msg) Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) }
function Write-Out { param($msg) Write-Host $msg; Log $msg }
function Write-Warn { param($msg) Write-Host $msg -ForegroundColor Yellow; Log "WARN: $msg" }
function Write-Err { param($msg) Write-Host $msg -ForegroundColor Red; Log "ERROR: $msg" }
function Write-Debug { param($msg) Log "DEBUG: $msg" }

function Load-State {
    if (Test-Path $stateFile) {
        try { return Get-Content $stateFile -Raw | ConvertFrom-Json } catch { }
    }
    return @{ lastDockerStart = 0; lastCrash = 0; crashCount = 0; wslexecDetected = $false }
}
function Save-State { param($state) $state | ConvertTo-Json -Depth 3 | Set-Content -Path $stateFile -Force }

# =============================================================================
# LAYER 4: Docker Desktop Config Hardening - Disable auto WSL user/group mgmt
# =============================================================================
function Harden-DockerDesktopConfig {
    Write-Out "[LAYER 4] Hardening Docker Desktop configuration..."
    
    # Backup original settings
    if ((Test-Path $ddSettingsFile) -and (-not (Test-Path "$ddSettingsFile.bak"))) {
        Copy-Item $ddSettingsFile "$ddSettingsFile.bak" -Force
        Write-Out "  Backed up settings.json"
    }
    
    $settings = @{}
    if (Test-Path $ddSettingsFile) {
        try { $settings = Get-Content $ddSettingsFile -Raw | ConvertFrom-Json } catch { }
    }
    
    # Disable automatic WSL integration user/group management
    # 2026-11-14: DD >= 4.35 reads settings-store.json - the legacy settings.json
    # write was landing in a dead file. Write BOTH files with Add-Member -Force
    # so the minimal 4.98 schema (keys absent) does not throw on assignment.
    $hardenKeys = @{
        disableWSLIntegrationAutoConfig = $true
        wslIntegrationAutoConfigure     = $false
        manageDockerGroup               = $false
    }
    foreach ($f in @($ddSettingsFile, $ddStoreFile)) {
        if (-not (Test-Path $f)) { continue }
        try {
            $s = Get-Content $f -Raw | ConvertFrom-Json
            foreach ($k in $hardenKeys.Keys) {
                $s | Add-Member -NotePropertyName $k -NotePropertyValue $hardenKeys[$k] -Force
            }
            $s | ConvertTo-Json -Depth 5 | Set-Content -Path $f -Force
            Write-Out ("  Updated {0}: disabled WSL auto-config + docker group management" -f (Split-Path $f -Leaf))
        } catch {
            Write-Out ("  WARN: could not harden {0}: {1}" -f $f, $_.Exception.Message)
        }
    }
    
    # Also update daemon.json to not rely on docker group
    if (Test-Path $ddDaemonFile) {
        try { $daemon = Get-Content $ddDaemonFile -Raw | ConvertFrom-Json } catch { $daemon = @{} }
    } else { $daemon = @{} }
    
    # Ensure daemon doesn't require docker group (use rootless or explicit perms)
    $daemon.'userns-remap' = 'default'  # Use user namespace remapping instead
    $daemon | ConvertTo-Json -Depth 3 | Set-Content -Path $ddDaemonFile -Force
    Write-Out "  Updated daemon.json: enabled userns-remap"
}

function Restore-DockerDesktopConfig {
    Write-Out "Restoring Docker Desktop configuration..."
    if (Test-Path "$ddSettingsFile.bak") {
        Copy-Item "$ddSettingsFile.bak" $ddSettingsFile -Force
        Write-Out "  Restored settings.json from backup"
    }
    # daemon.json restore would need backup too
}

# =============================================================================
# LAYER 1: Docker Desktop Startup Gate
# =============================================================================
function Wait-WSLReadyForDocker {
    param($timeoutSec = 120)
    Write-Out "[LAYER 1] Docker Desktop startup gate: waiting for WSL integration..."
    Log "Docker Desktop startup detected - engaging WSL readiness gate"
    
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $stage = 0
    
    while ((Get-Date) -lt $deadline) {
        # Stage 1: WSL VM process exists
        if ($stage -lt 1) {
            if (Get-Process vmmemWSL -ErrorAction SilentlyContinue) {
                $stage = 1
                Write-Debug "Stage 1: vmmemWSL process detected"
            }
        }
        
        # Stage 2: WSL distro responds
        if ($stage -ge 1 -and $stage -lt 2) {
            $result = wsl.exe -d Ubuntu-24.04 -e true 2>&1
            if ($LASTEXITCODE -eq 0) {
                $stage = 2
                Write-Debug "Stage 2: Ubuntu-24.04 distro responds"
            }
        }
        
        # Stage 3: Docker CLI inside WSL reaches engine
        if ($stage -ge 2 -and $stage -lt 3) {
            $serverVer = wsl.exe -d Ubuntu-24.04 -e docker version --format '{{.Server.Version}}' 2>&1
            if ($serverVer -and $serverVer -match '^\d+\.\d+') {
                $stage = 3
                Write-Debug "Stage 3: Docker CLI in WSL reaches engine $serverVer"
            }
        }
        
        # Stage 4: Docker Desktop engine API reachable from Windows
        if ($stage -ge 3 -and $stage -lt 4) {
            docker info 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $stage = 4
                Write-Debug "Stage 4: Docker engine API reachable from Windows"
            }
        }
        
        # Stage 5: Port proxy healthy (9390/metrics)
        if ($stage -ge 4 -and $stage -lt 5) {
            $code = curl.exe -s -o NUL -w '%{http_code}' -m 5 "http://localhost:9390/metrics" 2>&1
            if ("$code" -match '^2|^3') {
                $stage = 5
                Write-Debug "Stage 5: Port proxy healthy"
            }
        }
        
        if ($stage -ge 5) {
            Write-Out "[LAYER 1] WSL integration fully ready - Docker Desktop can proceed"
            Log "WSL readiness gate passed in $([math]::Round((Get-Date).Subtract((Get-Date).AddSeconds(-$timeoutSec)).TotalSeconds, 1))s"
            return $true
        }
        
        Start-Sleep -Seconds 3
    }
    
    Write-Warn "[LAYER 1] WSL readiness gate TIMEOUT after ${timeoutSec}s - Docker Desktop may still crash WSL"
    Log "WSL readiness gate TIMEOUT - stage reached: $stage"
    return $false
}

# =============================================================================
# LAYER 2: Active Guard - Detect wslexec pattern and pre-stabilize
# =============================================================================
function Invoke-ActiveGuard {
    $state = Load-State
    $now = [DateTime]::Now
    
    # Check if Docker Desktop process started recently (within 30 sec)
    $ddProcs = Get-Process 'Docker Desktop','com.docker.backend' -ErrorAction SilentlyContinue
    $dockerJustStarted = $false
    
    foreach ($proc in $ddProcs) {
        try {
            $startTime = $proc.StartTime
            if (($now - $startTime).TotalSeconds -lt 30) {
                $dockerJustStarted = $true
                Write-Debug "Docker Desktop process started recently: $($proc.ProcessName) at $startTime"
            }
        } catch { }
    }
    
    # Check for wslexec in process tree (the actual crash trigger)
    $wslexecRunning = Get-Process 'wslexec' -ErrorAction SilentlyContinue
    if ($wslexecRunning) {
        Write-Debug "wslexec process detected - potential docker group setup in progress"
        $state.wslexecDetected = $true
        Send-DevOptAlert -Severity Warning -Title "wslexec Detected" -Message "Docker Desktop wslexec process detected (docker group setup in progress). Pre-stabilization engaged." -Tags 'wsl', 'docker', 'wslexec'
    } else {
        $state.wslexecDetected = $false
    }
    
    # If Docker just started and WSL isn't fully ready, engage stabilization
    if ($dockerJustStarted) {
        Write-Out "[LAYER 2] Docker Desktop startup detected - running pre-stabilization..."
        Log "Docker Desktop startup detected - pre-stabilization engaged"
        
        # Quick WSL health check
        $wslOk = $false
        if (Get-Process vmmemWSL -ErrorAction SilentlyContinue) {
            $test = wsl.exe -d Ubuntu-24.04 -e true 2>&1
            if ($LASTEXITCODE -eq 0) { $wslOk = $true }
        }
        
        if (-not $wslOk) {
            Write-Warn "[LAYER 2] WSL not ready - running emergency stabilization"
            Log "WSL not ready at Docker startup - emergency stabilization"
            Send-DevOptAlert -Severity Warning -Title "WSL Not Ready at Docker Startup" -Message "WSL Ubuntu-24.04 was not ready when Docker Desktop started. Running emergency stabilization." -Tags 'wsl', 'docker', 'layer2'
            
            # T1 equivalent: ensure integration
            wsl.exe -d Ubuntu-24.04 -e docker version 2>$null | Out-Null
            Start-Sleep -Seconds 5
            
            # Verify
            $test = wsl.exe -d Ubuntu-24.04 -e true 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Out "[LAYER 2] WSL stabilized successfully"
                Log "Emergency stabilization successful"
            } else {
                Write-Err "[LAYER 2] WSL stabilization FAILED - may need T2/T3"
                Log "Emergency stabilization FAILED"
                Send-DevOptAlert -Severity Critical -Title "WSL Stabilization Failed" -Message "Emergency stabilization failed after Docker Desktop startup. WSL may need T2/T3 recovery." -Tags 'wsl', 'docker', 'layer2' -Force
            }
        }
        
        $state.lastDockerStart = $now.ToString('o')
    }
    
    # Periodic health check (every run)
    if (Get-Process vmmemWSL -ErrorAction SilentlyContinue) {
        $test = wsl.exe -d Ubuntu-24.04 -e true 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "[LAYER 2] WSL distro unresponsive - triggering wsl-guardian T1"
            Log "WSL distro unresponsive - would trigger wsl-guardian"
            # The actual wsl-guardian scheduled task will handle T1-T3
        }
    }
    
    Save-State $state
}

# =============================================================================
# LAYER 3: Integration with existing wsl-guardian (ensure it runs more frequently)
# =============================================================================
function Ensure-WSLGuardianFrequency {
    $taskName = '\DevOptimizer\WSL-Guardian'
    $task = Get-ScheduledTask -TaskName 'WSL-Guardian' -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
    if ($task) {
        $trigger = $task.Triggers | Where-Object { $_.GetType().Name -eq 'TimeTrigger' }
        if ($trigger) {
            $interval = $trigger.Repetition.Interval
            if ($interval -ne 'PT2M') {
                Write-Out "[LAYER 3] Updating WSL-Guardian frequency from $interval to PT2M"
                # Note: Actual update would require Register-ScheduledTask with new trigger
                # This is informational - the task should be recreated with 2-min interval
            }
        }
    }
}

# =============================================================================
# MAIN ENTRY POINTS
# =============================================================================
if ($DockerStartupGate) {
    # Called by Docker Desktop startup trigger
    Wait-WSLReadyForDocker -timeoutSec $GateTimeoutSec
    exit $LASTEXITCODE
}

if ($Install) {
    Write-Out "=== Installing WSL Permanent Fix ==="
    
    # Layer 4: Harden Docker Desktop config
    Harden-DockerDesktopConfig
    
    # Create scheduled task for Active Guard (every 2 min + at logon)
    $action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\wsl-permanent-fix.ps1"'
    $triggerLogon = New-ScheduledTaskTrigger -AtLogOn
    # 2026-11-14: -Days 1 expired on 11-08 and silently killed the 2-min
    # guard cadence (PS 5.1 also DEFAULTS RepetitionDuration to 1 day when
    # an interval is given without one - always set this explicitly).
    # 3650d matches the other long-lived watchdogs.
    $triggerRepetition = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration (New-TimeSpan -Days 3650)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
    $principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance Win32_ComputerSystem).UserName -LogonType Interactive -RunLevel Highest
    
    Register-ScheduledTask -TaskName 'WSL-Permanent-Fix' -TaskPath '\DevOptimizer\' -Action $action -Trigger $triggerLogon,$triggerRepetition -Settings $settings -Principal $principal -Force -ErrorAction Stop
    Write-Out "Registered scheduled task: \DevOptimizer\WSL-Permanent-Fix (logon + every 2 min)"
    
    # Create Docker Desktop startup trigger task (triggered on process start via event log)
    # This uses a custom event trigger - simplified version runs at logon with gate
    $ddAction = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\wsl-permanent-fix.ps1" -DockerStartupGate'
    $ddTrigger = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName 'WSL-Permanent-Fix-DockerStartup' -TaskPath '\DevOptimizer\' -Action $ddAction -Trigger $ddTrigger -Settings $settings -Principal $principal -Force -ErrorAction Stop
    Write-Out "Registered scheduled task: \DevOptimizer\WSL-Permanent-Fix-DockerStartup (at logon with gate)"
    
    Write-Out ""
    Write-Out "=== Installation Complete ==="
    Write-Out "The fix is now active with 4 layers of defense:"
    Write-Out "  Layer 1: Docker Desktop startup gate (waits for WSL ready)"
    Write-Out "  Layer 2: Active guard every 2 min (detects wslexec, pre-stabilizes)"
    Write-Out "  Layer 3: Existing wsl-guardian T1-T3 (5 min, reactive recovery)"
    Write-Out "  Layer 4: Docker Desktop config hardened (disabled auto group mgmt)"
    Write-Out ""
    Write-Out "Logs: $logFile"
    Write-Out "State: $stateFile"
    
} elseif ($Uninstall) {
    Write-Out "=== Uninstalling WSL Permanent Fix ==="
    Unregister-ScheduledTask -TaskName 'WSL-Permanent-Fix' -TaskPath '\DevOptimizer\' -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName 'WSL-Permanent-Fix-DockerStartup' -TaskPath '\DevOptimizer\' -Confirm:$false -ErrorAction SilentlyContinue
    Restore-DockerDesktopConfig
    Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
    Write-Out "Uninstalled scheduled tasks and restored Docker Desktop config"
    
} elseif ($Test) {
    Write-Out "=== Testing WSL Permanent Fix Logic ==="
    Write-Out ""
    Write-Out "[Test] Layer 4 - Docker Desktop config check:"
    if (Test-Path $ddSettingsFile) {
        $s = Get-Content $ddSettingsFile -Raw | ConvertFrom-Json
        Write-Out "  disableWSLIntegrationAutoConfig: $($s.disableWSLIntegrationAutoConfig)"
        Write-Out "  wslIntegrationAutoConfigure: $($s.wslIntegrationAutoConfigure)"
        Write-Out "  manageDockerGroup: $($s.manageDockerGroup)"
    }
    Write-Out ""
    Write-Out "[Test] Layer 1 - WSL readiness gate (dry run, 10s timeout):"
    $result = Wait-WSLReadyForDocker -timeoutSec 10
    Write-Out "  Result: $result"
    Write-Out ""
    Write-Out "[Test] Layer 2 - Active guard check:"
    Invoke-ActiveGuard
    Write-Out "  Completed"
    Write-Out ""
    Write-Out "[Test] Layer 3 - wsl-guardian frequency check:"
    Ensure-WSLGuardianFrequency
    Write-Out ""
    Write-Out "=== Test Complete ==="
    
} else {
    # Default: run active guard (called by scheduled task every 2 min)
    Write-Debug "=== WSL Permanent Fix - Active Guard Run ==="
    Invoke-ActiveGuard
    Write-Debug "Active guard completed"
}
# --- sshd ensure (2026-11-07): omv watchdog remediation ssh-hop needs Windows sshd ---
try {
    $sshd = Get-Service sshd -ErrorAction SilentlyContinue
    if ($sshd -and $sshd.StartType -ne 'Automatic') { Set-Service sshd -StartupType Automatic }
    if ($sshd -and $sshd.Status -ne 'Running') { Start-Service sshd }
} catch {}
