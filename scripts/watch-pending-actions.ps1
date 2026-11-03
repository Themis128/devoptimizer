<#
.SYNOPSIS
    Watch pending actions - monitor task fixes and reboot status
.DESCRIPTION
    Run this periodically to check if pending actions are complete.
#>

Write-Host "=== PENDING ACTIONS WATCH ===" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# 1. Check 3 tasks needing elevated fix
Write-Host "1. TASKS NEEDING ELEVATED FIX (run fix-remaining-tasks-elevated.ps1 as Admin):" -ForegroundColor Yellow
$tasksToCheck = @('Devin-Daily-Maintenance', 'Devin-Weekly-Restart', 'WSL-Memory-Watchdog')
$allFixed = $true

foreach ($name in $tasksToCheck) {
    $task = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName $name -ErrorAction SilentlyContinue
    if ($task) {
        $args = $task.Actions[0].Arguments
        $hasHidden = $args -match 'WindowStyle Hidden'
        $hasHeadless = $args -match '--headless'
        $status = if ($hasHidden -and $hasHeadless) { '✅ FIXED' } else { '❌ PENDING'; $allFixed = $false }
        Write-Host "   $status  $name"
        if (-not $hasHidden) { Write-Host "      Missing: -WindowStyle Hidden" -ForegroundColor Red }
        if (-not $hasHeadless -and $name -eq 'Devin-Daily-Maintenance') { Write-Host "      Missing: --headless" -ForegroundColor Red }
    }
}

# 2. Check reboot needed (zombie vmmemWSL)
Write-Host ""
Write-Host "2. REBOOT STATUS:" -ForegroundColor Yellow
$vmmem = Get-Process vmmemWSL -ErrorAction SilentlyContinue
if ($vmmem) {
    Write-Host "   ❌ REBOOT NEEDED - vmmemWSL running (PID $($vmmem.Id), WS $([math]::Round($vmmem.WorkingSet/1GB,1)) GB)"
    Write-Host "      Zombie process holds ext4.vhdx - only reboot clears it (~9.5 GB reclaim)"
} else {
    Write-Host "   ✅ REBOOT DONE - no vmmemWSL process"
}

# 3. Check docker_data.vhdx size
Write-Host ""
Write-Host "3. DOCKER VHDX SIZE:" -ForegroundColor Yellow
$vhdx = Get-Item 'C:\Users\tbaltzakis\AppData\Local\Docker\wsl\disk\docker_data.vhdx' -ErrorAction SilentlyContinue
if ($vhdx) {
    $sizeGB = [math]::Round($vhdx.Length / 1GB, 1)
    Write-Host "   docker_data.vhdx: $sizeGB GB"
    if ($sizeGB -gt 170) { Write-Host "      (Post-compaction: 172 GB, reclaim ~9.5 GB pending reboot)" -ForegroundColor Gray }
}

# 4. Check git commit status
Write-Host ""
Write-Host "4. GIT STATUS:" -ForegroundColor Yellow
$gitStatus = git status --porcelain 2>$null
if ($gitStatus) {
    Write-Host "   ❌ UNCOMMITTED CHANGES:"
    $gitStatus | ForEach-Object { Write-Host "      $_" }
} else {
    Write-Host "   ✅ CLEAN - nothing to commit"
}

# 5. Next scheduled task runs
Write-Host ""
Write-Host "5. NEXT TASK RUNS:" -ForegroundColor Yellow
Get-ScheduledTask -TaskPath '\DevOptimizer\' | Select-Object TaskName, NextRunTime | Sort-Object NextRunTime | Format-Table -AutoSize

Write-Host ""
if ($allFixed -and (-not $vmmem)) {
    Write-Host "🎉 ALL PENDING ACTIONS COMPLETE!" -ForegroundColor Green
} else {
    Write-Host "⏳ PENDING ACTIONS REMAIN" -ForegroundColor Yellow
}
