#Requires -Version 5.1
<#
.SYNOPSIS
    Intelligent VS Code Insiders Process Monitor v4.0
.DESCRIPTION
    Major upgrade featuring:
    - System-aware adaptive thresholds (dynamically adjust based on free RAM)
    - Smart selective kills (target heaviest processes, not everything)
    - Windows toast/balloon notifications for critical alerts
    - Compact logging (only log state changes, suppress noise)
    - Extension host identification and profiling
    - WSL2 memory coordination (vmmem tracking)
    - Health score dashboard (composite 0-100 score)
    - Improved trend analysis with EMA (Exponential Moving Average)
.NOTES
    Auto-stops when VS Code Insiders closes
    Logs to: D:\DevOptimizer\logs\vscode-monitor-YYYYMMDD.log
#>

[CmdletBinding()]
param(
    [int]$TotalMemoryThresholdMB = 8192,
    [int]$SingleProcessThresholdMB = 2048,
    [int]$MaxProcessCount = 35,
    [int]$CheckIntervalSeconds = 30,
    [switch]$DryRun,
    [switch]$HideWindow
)

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════
$ProcessName = "Code - Insiders"
$LogPath = "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log"
$MaxLogSizeMB = 10

# Adaptive threshold settings
$AdaptiveMinFreeGB = 3.0          # Minimum free RAM before tightening thresholds
$AdaptiveWarningFreeGB = 5.0      # Start reducing thresholds below this
$AdaptiveFloorPercent = 0.5       # Never reduce below 50% of base threshold
$AdaptiveCeilingPercent = 1.0     # Never exceed 100% of base threshold

# Predictive settings
$PredictiveThreshold = 0.85
$TrendHistorySize = 8
$EmaAlpha = 0.3                   # EMA smoothing factor (higher = more weight to recent)

# Notification settings
$NotificationCooldownMinutes = 10
$CriticalCooldownMinutes = 3

# Selective kill settings
$SelectiveKillTargetPercent = 0.3  # Kill enough to free 30% of threshold
$PreserveMainWindow = $true        # Try to keep the main editor process alive

# Health score weights
$HealthWeights = @{
    Memory       = 0.35
    ProcessCount = 0.20
    Trend        = 0.15
    SystemRAM    = 0.20
    WSL          = 0.10
}

# ═══════════════════════════════════════════════════════════════
# State Tracking
# ═══════════════════════════════════════════════════════════════
$memoryHistory = [System.Collections.Generic.List[double]]::new()
$emaTrend = $null
$startTime = Get-Date
$lastNotificationTime = $null
$lastCriticalTime = $null
$lastLoggedState = $null         # For compact logging
$lastHealthScore = -1

$stats = @{
    TotalChecks      = 0
    AlertsSent       = 0
    ToastsSent       = 0
    ProcessesKilled  = 0
    SelectiveKills   = 0
    FullKills        = 0
    GracefulCloses   = 0
    ForcedKills      = 0
    AdaptiveAdjusts  = 0
    HealthScoreMin   = 100
    HealthScoreMax   = 0
    HealthScoreSum   = 0
}

# Base thresholds (saved for adaptive calculations)
$baseThresholds = @{
    TotalMemoryMB   = $TotalMemoryThresholdMB
    SingleProcessMB = $SingleProcessThresholdMB
    MaxProcessCount = $MaxProcessCount
}

# ═══════════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════════
$logDir = Split-Path $LogPath -Parent
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

# Rotate log if too large
if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length / 1MB) -gt $MaxLogSizeMB) {
    $archivePath = $LogPath -replace '\.log$', "-archive-$(Get-Date -Format 'HHmmss').log"
    Move-Item -Path $LogPath -Destination $archivePath -Force
}

# Hide window if requested
if ($HideWindow) {
    try {
        $code = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
        Add-Type -MemberDefinition $code -Name "Win32Hide" -Namespace "Monitor" -ErrorAction SilentlyContinue
        $hwnd = (Get-Process -Id $PID).MainWindowHandle
        [Monitor.Win32Hide]::ShowWindow($hwnd, 0) | Out-Null
    } catch { }
}

# Notification system setup
$notifyIcon = $null
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
    $notifyIcon.Text = "VS Code Monitor v4.0"
    $notifyIcon.Visible = $false
    $hasNotifyIcon = $true
} catch {
    $hasNotifyIcon = $false
}

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "ALERT", "HEALTH", "ADAPT", "KILL")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    try { Add-Content -Path $LogPath -Value $logMessage -ErrorAction SilentlyContinue } catch { }
    if (!$HideWindow) {
        $color = switch ($Level) {
            "ERROR"   { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "ALERT"   { "Magenta" }
            "HEALTH"  { "Cyan" }
            "ADAPT"   { "DarkCyan" }
            "KILL"    { "DarkRed" }
            default   { "White" }
        }
        Write-Host $logMessage -ForegroundColor $color
    }
}

function Send-ToastNotification {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    if (!$hasNotifyIcon) { return }
    
    # Cooldown check
    $cooldown = if ($Type -eq "Error") { $CriticalCooldownMinutes } else { $NotificationCooldownMinutes }
    $lastTime = if ($Type -eq "Error") { $script:lastCriticalTime } else { $script:lastNotificationTime }
    
    if ($lastTime -and ((Get-Date) - $lastTime).TotalMinutes -lt $cooldown) { return }
    
    try {
        $tipIcon = switch ($Type) {
            "Error"   { [System.Windows.Forms.ToolTipIcon]::Error }
            "Warning" { [System.Windows.Forms.ToolTipIcon]::Warning }
            default   { [System.Windows.Forms.ToolTipIcon]::Info }
        }
        $notifyIcon.Visible = $true
        $notifyIcon.ShowBalloonTip(5000, $Title, $Message, $tipIcon)
        
        $script:stats.ToastsSent++
        if ($Type -eq "Error") { $script:lastCriticalTime = Get-Date }
        else { $script:lastNotificationTime = Get-Date }
        
        Write-Log "Toast sent: $Title - $Message" "INFO"
    } catch {
        # Notification failed silently
    }
}

function Get-SystemMemory {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB, 0)
    $freeMB = [math]::Round($os.FreePhysicalMemory / 1KB, 0)
    return @{
        TotalMB     = $totalMB
        FreeMB      = $freeMB
        FreeGB      = [math]::Round($freeMB / 1024, 2)
        UsedPercent = [math]::Round((($totalMB - $freeMB) / $totalMB) * 100, 0)
    }
}

function Get-WSLMemory {
    $vmmem = Get-Process vmmem -ErrorAction SilentlyContinue
    if ($vmmem) {
        return @{
            Running  = $true
            MemoryMB = [math]::Round($vmmem.WorkingSet64 / 1MB, 0)
            MemoryGB = [math]::Round($vmmem.WorkingSet64 / 1GB, 2)
        }
    }
    return @{ Running = $false; MemoryMB = 0; MemoryGB = 0 }
}

function Get-AdaptiveThresholds {
    param([hashtable]$SysMem, [hashtable]$WSLMem)
    
    $freeGB = $SysMem.FreeGB
    $scaleFactor = 1.0
    
    if ($freeGB -lt $AdaptiveMinFreeGB) {
        # Critical: scale down aggressively
        $scaleFactor = $AdaptiveFloorPercent
    } elseif ($freeGB -lt $AdaptiveWarningFreeGB) {
        # Proportional scaling between floor and ceiling
        $range = $AdaptiveWarningFreeGB - $AdaptiveMinFreeGB
        $position = ($freeGB - $AdaptiveMinFreeGB) / $range
        $scaleFactor = $AdaptiveFloorPercent + ($position * ($AdaptiveCeilingPercent - $AdaptiveFloorPercent))
    }
    
    # WSL pressure: if WSL is using a lot, tighten further
    if ($WSLMem.Running -and $WSLMem.MemoryGB -gt 8) {
        $scaleFactor *= 0.85
    }
    
    $scaleFactor = [math]::Max($AdaptiveFloorPercent, [math]::Min($AdaptiveCeilingPercent, $scaleFactor))
    
    $adapted = @{
        TotalMemoryMB   = [math]::Round($baseThresholds.TotalMemoryMB * $scaleFactor, 0)
        SingleProcessMB = [math]::Round($baseThresholds.SingleProcessMB * $scaleFactor, 0)
        MaxProcessCount = [math]::Max(15, [math]::Round($baseThresholds.MaxProcessCount * $scaleFactor, 0))
        ScaleFactor     = [math]::Round($scaleFactor, 2)
    }
    
    return $adapted
}

function Get-ProcessStats {
    $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if (!$processes) { return $null }
    
    $processArray = @($processes)
    $totalMemoryBytes = ($processArray | Measure-Object -Property WorkingSet64 -Sum).Sum
    
    # Identify extension hosts vs renderer vs main
    $classified = $processArray | Select-Object Id,
        @{Name="MemoryMB"; Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}},
        @{Name="CPUSeconds"; Expression={[math]::Round($_.CPU, 2)}},
        MainWindowTitle,
        @{Name="Type"; Expression={
            try {
                $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
                if ($cmdLine -match '--type=extensionHost') { 'ExtensionHost' }
                elseif ($cmdLine -match '--type=renderer') { 'Renderer' }
                elseif ($cmdLine -match '--type=gpu') { 'GPU' }
                elseif ($cmdLine -match '--type=utility') { 'Utility' }
                elseif ($_.MainWindowTitle) { 'MainWindow' }
                else { 'Worker' }
            } catch { 'Unknown' }
        }},
        @{Name="CmdLineSnippet"; Expression={
            try {
                $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
                if ($cmd.Length -gt 120) { $cmd.Substring(0, 120) + "..." } else { $cmd }
            } catch { "" }
        }} |
        Sort-Object MemoryMB -Descending
    
    return @{
        Count         = $processArray.Count
        TotalMemoryMB = [math]::Round($totalMemoryBytes / 1MB, 2)
        TotalMemoryGB = [math]::Round($totalMemoryBytes / 1GB, 2)
        Processes     = $classified
        TopProcess    = $classified[0]
        ExtensionHosts = @($classified | Where-Object { $_.Type -eq 'ExtensionHost' })
        MainWindows    = @($classified | Where-Object { $_.Type -eq 'MainWindow' })
    }
}

function Get-MemoryTrendEMA {
    if ($memoryHistory.Count -lt 3) { return @{ Trend = "COLLECTING"; EMA = 0; Change = 0 } }
    
    # Calculate EMA
    $values = $memoryHistory.ToArray()
    $ema = $values[0]
    for ($i = 1; $i -lt $values.Count; $i++) {
        $ema = ($EmaAlpha * $values[$i]) + ((1 - $EmaAlpha) * $ema)
    }
    
    # Calculate rate of change (MB per check)
    $recentValues = if ($values.Count -ge 5) { $values[-5..-1] } else { $values }
    $avgChange = 0
    for ($i = 1; $i -lt $recentValues.Count; $i++) {
        $avgChange += ($recentValues[$i] - $recentValues[$i-1])
    }
    $avgChange = $avgChange / [math]::Max(1, ($recentValues.Count - 1))
    
    $trend = if ([math]::Abs($avgChange) -lt 100) { "STABLE" }
             elseif ($avgChange -gt 0) { "RISING" }
             else { "FALLING" }
    
    return @{ Trend = $trend; EMA = [math]::Round($ema, 0); Change = [math]::Round($avgChange, 0) }
}

function Get-HealthScore {
    param(
        [hashtable]$Stats,
        [hashtable]$Thresholds,
        [hashtable]$TrendInfo,
        [hashtable]$SysMem,
        [hashtable]$WSLMem
    )
    
    # Memory component (0-100): how close to adapted threshold
    $memScore = [math]::Max(0, 100 - (($Stats.TotalMemoryMB / $Thresholds.TotalMemoryMB) * 100))
    
    # Process count component (0-100)
    $procScore = [math]::Max(0, 100 - (($Stats.Count / $Thresholds.MaxProcessCount) * 100))
    
    # Trend component (0-100)
    $trendScore = switch ($TrendInfo.Trend) {
        "FALLING" { 100 }
        "STABLE"  { 75 }
        "RISING"  { 30 }
        default   { 50 }
    }
    # Adjust by rate of change
    if ($TrendInfo.Change -gt 200) { $trendScore = [math]::Max(0, $trendScore - 20) }
    
    # System RAM component (0-100)
    $ramScore = [math]::Max(0, [math]::Min(100, $SysMem.FreeGB * 20))  # 5GB free = 100
    
    # WSL component (0-100)
    $wslScore = if ($WSLMem.Running) {
        [math]::Max(0, 100 - ($WSLMem.MemoryGB * 8))  # 12GB WSL = ~4
    } else { 100 }
    
    $composite = [math]::Round(
        ($memScore * $HealthWeights.Memory) +
        ($procScore * $HealthWeights.ProcessCount) +
        ($trendScore * $HealthWeights.Trend) +
        ($ramScore * $HealthWeights.SystemRAM) +
        ($wslScore * $HealthWeights.WSL)
    , 0)
    
    $composite = [math]::Max(0, [math]::Min(100, $composite))
    
    return @{
        Score      = $composite
        Memory     = [math]::Round($memScore, 0)
        Processes  = [math]::Round($procScore, 0)
        Trend      = [math]::Round($trendScore, 0)
        SystemRAM  = [math]::Round($ramScore, 0)
        WSL        = [math]::Round($wslScore, 0)
        Grade      = if ($composite -ge 80) { 'A' }
                     elseif ($composite -ge 60) { 'B' }
                     elseif ($composite -ge 40) { 'C' }
                     elseif ($composite -ge 20) { 'D' }
                     else { 'F' }
    }
}

function Stop-ProcessesSelectively {
    param(
        [array]$AllProcesses,
        [double]$CurrentMemoryMB,
        [double]$TargetMemoryMB,
        [string]$Reason
    )
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would selectively kill processes. Reason: $Reason" "WARNING"
        return $false
    }
    
    Write-Log "Selective cleanup initiated: $Reason" "KILL"
    
    $memoryToFree = $CurrentMemoryMB - ($TargetMemoryMB * (1 - $SelectiveKillTargetPercent))
    Write-Log "Target: free ~$([math]::Round($memoryToFree, 0)) MB" "KILL"
    
    # Sort by memory descending, but protect main windows
    $killCandidates = $AllProcesses | Sort-Object MemoryMB -Descending
    
    if ($PreserveMainWindow) {
        # Move main windows to the end of kill list
        $mainWindows = @($killCandidates | Where-Object { $_.Type -eq 'MainWindow' })
        $others = @($killCandidates | Where-Object { $_.Type -ne 'MainWindow' })
        $killCandidates = $others + $mainWindows
    }
    
    $freedMemory = 0
    $killedCount = 0
    
    foreach ($proc in $killCandidates) {
        if ($freedMemory -ge $memoryToFree) {
            Write-Log "Freed enough memory ($([math]::Round($freedMemory, 0)) MB). Stopping selective kill." "SUCCESS"
            break
        }
        
        try {
            $liveProc = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if (!$liveProc) { continue }
            
            # Try graceful close for windowed processes
            $closed = $false
            if ($proc.MainWindowTitle -and $liveProc.CloseMainWindow()) {
                Start-Sleep -Milliseconds 500
                $stillAlive = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
                if (!$stillAlive) {
                    $closed = $true
                    $script:stats.GracefulCloses++
                }
            }
            
            if (!$closed) {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                $script:stats.ForcedKills++
            }
            
            $freedMemory += $proc.MemoryMB
            $killedCount++
            $script:stats.ProcessesKilled++
            $script:stats.SelectiveKills++
            
            Write-Log "  Killed PID $($proc.Id) [$($proc.Type)] - $($proc.MemoryMB) MB (freed total: $([math]::Round($freedMemory, 0)) MB)" "KILL"
            
        } catch {
            Write-Log "  Failed to kill PID $($proc.Id): $($_.Exception.Message)" "ERROR"
        }
    }
    
    Write-Log "Selective kill complete: $killedCount processes, $([math]::Round($freedMemory, 0)) MB freed" "SUCCESS"
    
    Send-ToastNotification -Title "VS Code Monitor - Cleanup" `
        -Message "Killed $killedCount processes, freed $([math]::Round($freedMemory, 0)) MB. Reason: $Reason" `
        -Type "Warning"
    
    return $true
}

function Stop-AllProcesses {
    param([string]$Reason)
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would kill ALL processes. Reason: $Reason" "WARNING"
        return $false
    }
    
    Write-Log "FULL CLEANUP: $Reason" "KILL"
    $script:stats.FullKills++
    
    # Try graceful first
    $allProcs = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    $windowedProcs = @($allProcs | Where-Object { $_.MainWindowTitle })
    
    foreach ($proc in $windowedProcs) {
        try {
            if ($proc.CloseMainWindow()) { $script:stats.GracefulCloses++ }
        } catch { }
    }
    
    Start-Sleep -Seconds 2
    
    # Force kill remaining
    $remaining = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($remaining) {
        $count = @($remaining).Count
        Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
        $script:stats.ForcedKills += $count
        $script:stats.ProcessesKilled += $count
    }
    
    Write-Log "All VS Code processes terminated" "SUCCESS"
    
    Send-ToastNotification -Title "VS Code Monitor - Emergency" `
        -Message "All processes killed. Reason: $Reason" `
        -Type "Error"
    
    return $true
}

function Get-CompactState {
    param(
        [hashtable]$Stats,
        [hashtable]$Health,
        [hashtable]$Thresholds
    )
    
    # Create a state fingerprint for change detection
    return "$($Stats.Count)|$([math]::Round($Stats.TotalMemoryMB / 100) * 100)|$($Health.Grade)|$([math]::Round($Thresholds.ScaleFactor, 1))"
}

function Write-ExtensionHostProfile {
    param([array]$ExtHosts)
    
    if ($ExtHosts.Count -eq 0) { return }
    
    $totalExtMem = ($ExtHosts | Measure-Object -Property MemoryMB -Sum).Sum
    Write-Log "Extension Hosts: $($ExtHosts.Count) hosts, $([math]::Round($totalExtMem, 0)) MB total" "INFO"
    
    foreach ($ext in ($ExtHosts | Sort-Object MemoryMB -Descending | Select-Object -First 3)) {
        Write-Log "  EH PID $($ext.Id): $($ext.MemoryMB) MB, CPU: $($ext.CPUSeconds)s" "INFO"
    }
}

# ═══════════════════════════════════════════════════════════════
# Duplicate Instance Check
# ═══════════════════════════════════════════════════════════════
$existingMonitor = Get-Process -Name "powershell","pwsh" -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -ne $PID } |
    Where-Object {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
            $cmd -like "*VSCode-AutoMonitor*"
        } catch { $false }
    }

if ($existingMonitor) {
    Write-Log "Another monitor instance detected (PID: $($existingMonitor.Id)). Exiting." "WARNING"
    exit 0
}

# ═══════════════════════════════════════════════════════════════
# Startup
# ═══════════════════════════════════════════════════════════════
Write-Log "══════════════════════════════════════════════════════════════════" "INFO"
Write-Log "VS Code Insiders Intelligent Monitor v4.0 Started" "SUCCESS"
Write-Log "══════════════════════════════════════════════════════════════════" "INFO"
Write-Log "Base Thresholds: Memory=$TotalMemoryThresholdMB MB, Per-Process=$SingleProcessThresholdMB MB, MaxProcs=$MaxProcessCount" "INFO"
Write-Log "Features: Adaptive Thresholds, Selective Kills, Toast Notifications, Compact Logging" "INFO"
Write-Log "Features: WSL2 Coordination, Extension Host Profiling, Health Score Dashboard" "INFO"
Write-Log "Mode: $(if($DryRun){'DRY RUN'}else{'Active Protection'}) | Interval: ${CheckIntervalSeconds}s" "INFO"

$noProcessCount = 0
$maxNoProcessIterations = 10
$checksSinceExtProfile = 0

# ═══════════════════════════════════════════════════════════════
# Main Monitor Loop
# ═══════════════════════════════════════════════════════════════
while ($true) {
    $script:stats.TotalChecks++
    
    $currentStats = Get-ProcessStats
    
    # ─────────────────────────────────────────────────────────
    # No processes running
    # ─────────────────────────────────────────────────────────
    if ($null -eq $currentStats) {
        $noProcessCount++
        
        if ($noProcessCount -eq 1) {
            Write-Log "No VS Code Insiders processes detected" "INFO"
        }
        
        if ($noProcessCount -ge $maxNoProcessIterations) {
            $runtime = (Get-Date) - $startTime
            Write-Log "══════════════════════════════════════════════════════════════════" "INFO"
            Write-Log "VS Code Insiders closed. Monitor stopping." "SUCCESS"
            Write-Log "Session Stats:" "INFO"
            Write-Log "  Runtime: $([math]::Round($runtime.TotalMinutes, 1)) min | Checks: $($script:stats.TotalChecks)" "INFO"
            Write-Log "  Alerts: $($script:stats.AlertsSent) | Toasts: $($script:stats.ToastsSent)" "INFO"
            Write-Log "  Kills: $($script:stats.ProcessesKilled) (Selective: $($script:stats.SelectiveKills), Full: $($script:stats.FullKills))" "INFO"
            Write-Log "  Graceful: $($script:stats.GracefulCloses) | Forced: $($script:stats.ForcedKills)" "INFO"
            Write-Log "  Adaptive Adjustments: $($script:stats.AdaptiveAdjusts)" "INFO"
            if ($script:stats.TotalChecks -gt 0) {
                $avgHealth = [math]::Round($script:stats.HealthScoreSum / [math]::Max(1, $script:stats.TotalChecks - $noProcessCount), 0)
                Write-Log "  Health Score: Min=$($script:stats.HealthScoreMin) Avg=$avgHealth Max=$($script:stats.HealthScoreMax)" "HEALTH"
            }
            Write-Log "══════════════════════════════════════════════════════════════════" "INFO"
            
            # Cleanup notification icon
            if ($notifyIcon) { $notifyIcon.Visible = $false; $notifyIcon.Dispose() }
            break
        }
        
        Start-Sleep -Seconds $CheckIntervalSeconds
        continue
    }
    
    $noProcessCount = 0
    
    # ─────────────────────────────────────────────────────────
    # Gather system context
    # ─────────────────────────────────────────────────────────
    $sysMem = Get-SystemMemory
    $wslMem = Get-WSLMemory
    
    # ─────────────────────────────────────────────────────────
    # Adaptive threshold calculation
    # ─────────────────────────────────────────────────────────
    $adaptedThresholds = Get-AdaptiveThresholds -SysMem $sysMem -WSLMem $wslMem
    
    # Log adaptation only when it changes significantly
    if ($adaptedThresholds.ScaleFactor -ne $AdaptiveCeilingPercent) {
        $script:stats.AdaptiveAdjusts++
        if ($script:stats.TotalChecks -le 1 -or $script:stats.TotalChecks % 20 -eq 0) {
            Write-Log "Adaptive: scale=$($adaptedThresholds.ScaleFactor)x → Memory=$($adaptedThresholds.TotalMemoryMB)MB, Procs=$($adaptedThresholds.MaxProcessCount) (Free RAM: $($sysMem.FreeGB)GB$(if($wslMem.Running){", WSL: $($wslMem.MemoryGB)GB"}))" "ADAPT"
        }
    }
    
    # Update live thresholds
    $TotalMemoryThresholdMB = $adaptedThresholds.TotalMemoryMB
    $SingleProcessThresholdMB = $adaptedThresholds.SingleProcessMB
    $MaxProcessCount = $adaptedThresholds.MaxProcessCount
    
    # ─────────────────────────────────────────────────────────
    # Update memory history & trend
    # ─────────────────────────────────────────────────────────
    $memoryHistory.Add($currentStats.TotalMemoryMB)
    if ($memoryHistory.Count -gt $TrendHistorySize * 2) {
        $memoryHistory.RemoveAt(0)
    }
    
    $trendInfo = Get-MemoryTrendEMA
    
    # ─────────────────────────────────────────────────────────
    # Health score
    # ─────────────────────────────────────────────────────────
    $health = Get-HealthScore -Stats $currentStats -Thresholds $adaptedThresholds `
                              -TrendInfo $trendInfo -SysMem $sysMem -WSLMem $wslMem
    
    $script:stats.HealthScoreMin = [math]::Min($script:stats.HealthScoreMin, $health.Score)
    $script:stats.HealthScoreMax = [math]::Max($script:stats.HealthScoreMax, $health.Score)
    $script:stats.HealthScoreSum += $health.Score
    
    # ─────────────────────────────────────────────────────────
    # Compact logging: only log when state changes
    # ─────────────────────────────────────────────────────────
    $currentState = Get-CompactState -Stats $currentStats -Health $health -Thresholds $adaptedThresholds
    $shouldLog = ($currentState -ne $lastLoggedState) -or ($script:stats.TotalChecks % 20 -eq 0)
    
    if ($shouldLog) {
        $wslStr = if ($wslMem.Running) { " | WSL:$($wslMem.MemoryGB)GB" } else { "" }
        $adaptStr = if ($adaptedThresholds.ScaleFactor -lt 1.0) { " | Scale:$($adaptedThresholds.ScaleFactor)x" } else { "" }
        
        Write-Log "Health:$($health.Score)/100($($health.Grade)) | Procs:$($currentStats.Count)/$MaxProcessCount | Mem:$([math]::Round($currentStats.TotalMemoryMB,0))/${TotalMemoryThresholdMB}MB | Trend:$($trendInfo.Trend)($($trendInfo.Change)MB/chk) | Free:$($sysMem.FreeGB)GB${wslStr}${adaptStr}" "HEALTH"
        
        $lastLoggedState = $currentState
    }
    
    # ─────────────────────────────────────────────────────────
    # Extension host profiling (every ~10 minutes)
    # ─────────────────────────────────────────────────────────
    $checksSinceExtProfile++
    if ($checksSinceExtProfile -ge [math]::Round(600 / $CheckIntervalSeconds)) {
        $checksSinceExtProfile = 0
        Write-ExtensionHostProfile -ExtHosts $currentStats.ExtensionHosts
    }
    
    # ─────────────────────────────────────────────────────────
    # Predictive alerts with toast notifications
    # ─────────────────────────────────────────────────────────
    $memUsagePercent = ($currentStats.TotalMemoryMB / $TotalMemoryThresholdMB) * 100
    $procUsagePercent = ($currentStats.Count / $MaxProcessCount) * 100
    
    if ($memUsagePercent -ge ($PredictiveThreshold * 100)) {
        $msg = "Memory at $([math]::Round($memUsagePercent, 0))% ($([math]::Round($currentStats.TotalMemoryMB, 0))/$TotalMemoryThresholdMB MB)"
        Write-Log "PREDICTIVE: $msg" "ALERT"
        $script:stats.AlertsSent++
        
        if ($memUsagePercent -ge 95) {
            Send-ToastNotification -Title "⚠️ VS Code Memory Critical" -Message $msg -Type "Error"
        } else {
            Send-ToastNotification -Title "VS Code Memory Warning" -Message $msg -Type "Warning"
        }
    }
    
    if ($procUsagePercent -ge ($PredictiveThreshold * 100)) {
        $msg = "Process count at $([math]::Round($procUsagePercent, 0))% ($($currentStats.Count)/$MaxProcessCount)"
        Write-Log "PREDICTIVE: $msg" "ALERT"
        $script:stats.AlertsSent++
        Send-ToastNotification -Title "VS Code Processes Warning" -Message $msg -Type "Warning"
    }
    
    if ($health.Score -le 20 -and $lastHealthScore -gt 20) {
        Send-ToastNotification -Title "⚠️ VS Code Health Critical" `
            -Message "Health score dropped to $($health.Score)/100 (Grade: $($health.Grade))" -Type "Error"
    }
    $lastHealthScore = $health.Score
    
    # ─────────────────────────────────────────────────────────
    # CRITICAL CHECK 1: Process count exceeded → FULL KILL
    # (Too many processes usually means runaway spawning)
    # ─────────────────────────────────────────────────────────
    if ($currentStats.Count -gt $MaxProcessCount) {
        Stop-AllProcesses -Reason "Process count ($($currentStats.Count)) exceeds limit ($MaxProcessCount)"
        Start-Sleep -Seconds 5
        continue
    }
    
    # ─────────────────────────────────────────────────────────
    # CRITICAL CHECK 2: Total memory exceeded → SELECTIVE KILL
    # ─────────────────────────────────────────────────────────
    if ($currentStats.TotalMemoryMB -gt $TotalMemoryThresholdMB) {
        Stop-ProcessesSelectively -AllProcesses $currentStats.Processes `
                                  -CurrentMemoryMB $currentStats.TotalMemoryMB `
                                  -TargetMemoryMB $TotalMemoryThresholdMB `
                                  -Reason "Total memory ($([math]::Round($currentStats.TotalMemoryMB, 0)) MB) exceeds threshold ($TotalMemoryThresholdMB MB)"
        Start-Sleep -Seconds 5
        continue
    }
    
    # ─────────────────────────────────────────────────────────
    # CRITICAL CHECK 3: Individual process bloat → SELECTIVE KILL
    # ─────────────────────────────────────────────────────────
    $bloatedProcesses = @($currentStats.Processes | Where-Object { $_.MemoryMB -gt $SingleProcessThresholdMB })
    if ($bloatedProcesses.Count -gt 0) {
        foreach ($proc in $bloatedProcesses) {
            Write-Log "Bloated: PID $($proc.Id) [$($proc.Type)] using $($proc.MemoryMB) MB (limit: $SingleProcessThresholdMB MB)" "WARNING"
        }
        
        Stop-ProcessesSelectively -AllProcesses $bloatedProcesses `
                                  -CurrentMemoryMB ($bloatedProcesses | Measure-Object -Property MemoryMB -Sum).Sum `
                                  -TargetMemoryMB $SingleProcessThresholdMB `
                                  -Reason "$($bloatedProcesses.Count) processes exceed $SingleProcessThresholdMB MB per-process limit"
        Start-Sleep -Seconds 5
        continue
    }
    
    # ─────────────────────────────────────────────────────────
    # System RAM emergency: if free RAM dangerously low
    # ─────────────────────────────────────────────────────────
    if ($sysMem.FreeGB -lt 1.5) {
        Write-Log "SYSTEM RAM CRITICAL: Only $($sysMem.FreeGB) GB free!" "ERROR"
        Send-ToastNotification -Title "🚨 System RAM Critical" `
            -Message "Only $($sysMem.FreeGB) GB free. Killing heaviest VS Code processes." -Type "Error"
        
        Stop-ProcessesSelectively -AllProcesses $currentStats.Processes `
                                  -CurrentMemoryMB $currentStats.TotalMemoryMB `
                                  -TargetMemoryMB ($currentStats.TotalMemoryMB * 0.5) `
                                  -Reason "System RAM critical ($($sysMem.FreeGB) GB free)"
        Start-Sleep -Seconds 5
        continue
    }
    
    # All OK
    if ($script:stats.TotalChecks % 40 -eq 0) {
        Write-Log "✓ All systems healthy (Health: $($health.Score)/100)" "SUCCESS"
    }
    
    Start-Sleep -Seconds $CheckIntervalSeconds
}
