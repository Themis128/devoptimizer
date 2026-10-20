<#
.SYNOPSIS
    Re-register all DevOptimizer scheduled tasks with proper staggering and increased time limits.
.DESCRIPTION
    Fixes the 0x41306 task termination issue by:
    1. Staggering tasks in the 02:15-06:00 window (was 02:15-05:30 collision)
    2. Increasing ExecutionTimeLimit for all maintenance tasks
    3. Setting -MultipleInstances IgnoreNew for long-running tasks
#>
#requires -Version 5.1
# CATEGORY: maintenance

param(
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must run elevated (Run as Administrator)"
    exit 1
}

$logPath = 'D:\DevOptimizer\logs\reregister-staggered-tasks.log'
try { Start-Transcript -Path $logPath -Force | Out-Null } catch { }
Write-Host "=== Re-registering DevOptimizer tasks with staggered schedule ===" -ForegroundColor Magenta
Write-Host ("Elevated as: {0}" -f $env:USERNAME)
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

$ps = (Get-Command powershell.exe).Source
$scriptRoot = 'D:\DevOptimizer\scripts'

function Register-StaggeredTask {
    param(
        [string]$TaskName,
        [string]$ScriptFile,
        [string]$ScheduleType,  # Daily, Weekly, DailyInterval
        [string]$Time,
        [string]$DaysOfWeek = '',
        [int]$DaysInterval = 1,
        [TimeSpan]$TimeLimit,
        [string]$User = 'tbaltzakis',
        [string]$RunLevel = 'Highest',
        [string]$Description = '',
        [switch]$MultipleInstancesIgnoreNew
    )

    $action = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptRoot\$ScriptFile`""
    
    $trigger = switch ($ScheduleType) {
        'Daily'       { New-ScheduledTaskTrigger -Daily -At $Time }
        'Weekly'      { New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DaysOfWeek -At $Time }
        'DailyInterval' { New-ScheduledTaskTrigger -Daily -DaysInterval $DaysInterval -At $Time }
        default       { throw "Unknown schedule type: $ScheduleType" }
    }
    
    $settingsParams = @{
        WakeToRun = $true
        StartWhenAvailable = $true
        AllowStartIfOnBatteries = $true
        DontStopIfGoingOnBatteries = $true
        ExecutionTimeLimit = $TimeLimit
    }
    if ($MultipleInstancesIgnoreNew) { $settingsParams.MultipleInstances = 'IgnoreNew' }
    $settings = New-ScheduledTaskSettingsSet @settingsParams
    
    $principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel $RunLevel
    
    $msg = "Registering: $TaskName | $ScheduleType $Time | Limit: $TimeLimit | User: $User"
    Write-Host $msg -ForegroundColor Cyan
    
    if (-not $DryRun) {
        try {
            Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName $TaskName `
                -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
                -Description $Description -Force -ErrorAction Stop | Out-Null
            Write-Host "  [OK] $TaskName" -ForegroundColor Green
        } catch {
            $errMsg = $_.Exception.Message
            Write-Host ("  [FAIL] {0}: {1}" -f $TaskName, $errMsg) -ForegroundColor Red
            throw $_
        }
    }
}

# ======================================================================
# STAGGERED SCHEDULE (02:15 - 06:00 window)
# ======================================================================

# 02:15 - Safe cleanup (user-level, light, ~10 min)
Register-StaggeredTask -TaskName 'Safe-Cleanup-Daily' -ScriptFile 'win11-safe-cleanup.ps1' `
    -ScheduleType 'Daily' -Time '02:15' -TimeLimit (New-TimeSpan -Hours 1) `
    -Description 'Daily user-level safe cleanup (temp files, caches, recycle bin). Runs at 02:15.'

# 02:45 - Extended cleanup (user-level, weekly Mon, ~30 min)
Register-StaggeredTask -TaskName 'Extended-Cleanup' -ScriptFile 'extended-cleanup.ps1' `
    -ScheduleType 'Weekly' -Time '02:45' -DaysOfWeek 'Monday' -TimeLimit (New-TimeSpan -Hours 2) `
    -Description 'Weekly extended cleanup (Mon 02:45): age-gated caches, Docker prune, browser caches.'

# 03:15 - Elevated cleanup (SYSTEM, every 15 days, ~2-4 hours)
Register-StaggeredTask -TaskName 'DevOptimizer-Elevated-Cleanup' -ScriptFile 'elevated-complete-cleanup.ps1' `
    -ScheduleType 'DailyInterval' -Time '03:15' -DaysInterval 15 -TimeLimit (New-TimeSpan -Hours 4) `
    -User 'SYSTEM' -RunLevel 'Highest' `
    -Description 'Elevated cleanup every 15 days at 03:15: DISM RestoreHealth, component store, WU cache, restore points, VHDX analysis.'

# 03:30 - WSL Ubuntu cleanup (daily, user-level, ~15 min) - MOVED from 03:00
Register-StaggeredTask -TaskName 'WSL-Ubuntu-Cleanup' -ScriptFile 'wsl-ubuntu-cleanup.ps1' `
    -ScheduleType 'Daily' -Time '03:30' -TimeLimit (New-TimeSpan -Hours 1) `
    -Description 'Daily WSL Ubuntu cleanup (03:30): journal, apt, uv caches. Staggered after elevated cleanup.'

# 04:00 - SocialAuto maintenance (daily, user-level, ~30-60 min) - KEEP
Register-StaggeredTask -TaskName 'SocialAuto-Maintenance' -ScriptFile 'socialauto\Maintain-SocialAuto.ps1' `
    -ScheduleType 'Daily' -Time '04:00' -TimeLimit (New-TimeSpan -Hours 2) `
    -Description 'Daily SocialAuto container health check (04:00). Staggered after WSL cleanup.'

# 04:30 - Devin daily maintenance (daily, user-level, ~15 min) - KEEP
Register-StaggeredTask -TaskName 'Devin-Daily-Maintenance' -ScriptFile 'devin\Invoke-DevinDailyMaintenance.ps1' `
    -ScheduleType 'Daily' -Time '04:30' -TimeLimit (New-TimeSpan -Hours 1) `
    -Description 'Daily Devin maintenance (04:30): cache sweep, log retention, bundle-orphan repair.'

# 05:30 - NAS Backup (daily, user-level, ~30-60 min) - KEEP
Register-StaggeredTask -TaskName 'Nas-Backup' -ScriptFile 'backup-docker-nas.ps1' `
    -ScheduleType 'Daily' -Time '05:30' -TimeLimit (New-TimeSpan -Hours 2) `
    -Description 'Nightly Docker + WSL config backup to OMV NAS (05:30). Size-tiered: nightly <2GB volumes + pg_dumpall, weekly large volumes + broad home.'

# 06:00 - VHDX Compaction (daily, SYSTEM, ~30-60 min) - MOVED from 05:30
Register-StaggeredTask -TaskName 'WSL-Vhdx-Compact' -ScriptFile 'Invoke-VhdxCompaction.ps1' `
    -ScheduleType 'Daily' -Time '06:00' -TimeLimit (New-TimeSpan -Hours 2) `
    -User 'SYSTEM' -RunLevel 'Highest' `
    -Description 'Daily WSL/Docker VHDX compaction (06:00): runs AFTER NAS backup. Built-in Devin protection gates.' `
    -MultipleInstancesIgnoreNew

# ======================================================================
# WEEKLY TASKS (Sunday) - STAGGERED
# ======================================================================

# 03:15 - Admin cleanup weekly (Sunday, elevated, ~30-60 min) - MOVED from 03:00
Register-StaggeredTask -TaskName 'Admin-Cleanup-Weekly' -ScriptFile 'win11-admin-cleanup-scheduled.ps1' `
    -ScheduleType 'Weekly' -Time '03:15' -DaysOfWeek 'Sunday' -TimeLimit (New-TimeSpan -Hours 2) `
    -Description 'Weekly elevated Windows admin cleanup (Sun 03:15): DISM component store + RestoreHealth + SFC + WU cache.' `
    -MultipleInstancesIgnoreNew

# 03:30 - Devin weekly restart (Sunday, user-level, ~5 min) - MOVED from 03:00
Register-StaggeredTask -TaskName 'Devin-Weekly-Restart' -ScriptFile 'restart-devin-weekly.ps1' `
    -ScheduleType 'Weekly' -Time '03:30' -DaysOfWeek 'Sunday' -TimeLimit (New-TimeSpan -Hours 1) `
    -Description 'Weekly Devin Desktop restart (Sun 03:30) to prevent memory leaks.' `
    -MultipleInstancesIgnoreNew

# ======================================================================
# HIGH-FREQUENCY MONITORING TASKS - INCREASED TIME LIMITS
# ======================================================================

# Host-Guard: Every 5 minutes - keep as-is (already fast host-side only)
# Already registered via register-devoptimizer-tasks.ps1 or manually

# WSL-Memory-Watchdog: Every 30 minutes - increase limit from default to PT10M
$wslMemAction = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptRoot\check-wsl-memory-pressure.ps1`""
$wslMemTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration ([TimeSpan]::MaxValue)
$wslMemSettings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew
$wslMemPrincipal = New-ScheduledTaskPrincipal -UserId 'tbaltzakis' -LogonType Interactive -RunLevel Highest
if (-not $DryRun) {
    Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'WSL-Memory-Watchdog' -Action $wslMemAction -Trigger $wslMemTrigger -Settings $wslMemSettings -Principal $wslMemPrincipal -Description 'WSL swap pressure monitor every 30 min (10 min timeout). Logs to logs\wsl-memory-pressure.log.' -Force | Out-Null
    Write-Host "  [OK] WSL-Memory-Watchdog (every 30 min, 10 min timeout)" -ForegroundColor Green
}

# Docker-WSL-Sync: Keep existing or register if missing
$syncAction = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptRoot\sync-docker-wsl.ps1`""
$syncTrigger = New-ScheduledTaskTrigger -Daily -At '04:45'  # Staggered between Devin-Daily and Nas-Backup
$syncSettings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
$syncPrincipal = New-ScheduledTaskPrincipal -UserId 'tbaltzakis' -LogonType Interactive -RunLevel Highest
if (-not $DryRun) {
    Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Docker-WSL-Sync' -Action $syncAction -Trigger $syncTrigger -Settings $syncSettings -Principal $syncPrincipal -Description 'Daily Docker-WSL sync (04:45): verify bind mounts, restart on-demand containers.' -Force | Out-Null
    Write-Host "  [OK] Docker-WSL-Sync (daily 04:45, 30 min timeout)" -ForegroundColor Green
}

# WSL-GPU-Rebind: Keep existing
# WSL-PreWarm: Keep existing

# ======================================================================
# VERIFICATION
# ======================================================================
Write-Host "`n=== Verification ===" -ForegroundColor Cyan
if (-not $DryRun) {
    Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue | Select-Object TaskName, State | Format-Table -AutoSize
    Write-Host ""
    Write-Host "=== Task Schedule Summary ===" -ForegroundColor Cyan
    Write-Host "02:15  Safe-Cleanup-Daily (daily, 1h limit)"
    Write-Host "02:45  Extended-Cleanup (Mon, 2h limit)"
    Write-Host "03:15  DevOptimizer-Elevated-Cleanup (every 15 days, 4h limit, SYSTEM)"
    Write-Host "03:15  Admin-Cleanup-Weekly (Sun, 2h limit)  -- Note: same time as Elevated but different frequency"
    Write-Host "03:30  WSL-Ubuntu-Cleanup (daily, 1h limit)"
    Write-Host "03:30  Devin-Weekly-Restart (Sun, 1h limit)"
    Write-Host "04:00  SocialAuto-Maintenance (daily, 2h limit)"
    Write-Host "04:30  Devin-Daily-Maintenance (daily, 1h limit)"
    Write-Host "04:45  Docker-WSL-Sync (daily, 30m limit)"
    Write-Host "05:30  Nas-Backup (daily, 2h limit)"
    Write-Host "06:00  WSL-Vhdx-Compact (daily, 2h limit, SYSTEM)"
    Write-Host ""
    Write-Host "WSL-Memory-Watchdog: every 30 min (10 min timeout)"
    Write-Host "Host-Guard: every 5 min (existing)"
} else {
    Write-Host "[DRY RUN] No tasks were actually registered" -ForegroundColor Yellow
}

try { Stop-Transcript | Out-Null } catch { }
Write-Host "`n=== Registration complete ===" -ForegroundColor Magenta