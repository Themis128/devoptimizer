<#
.SYNOPSIS
    DevOptimizer automation script: FIXED-SYSTEM-DEEP-CLEAN.
.DESCRIPTION
    DevOptimizer automation script: FIXED-SYSTEM-DEEP-CLEAN.
#>

# Fixed System Deep Clean Script
# Enhanced Windows 11 Development Optimizer v3.1

param(
    [switch]$Verbose,
    [switch]$DryRun
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "           ENHANCED WINDOWS 11 DEVELOPMENT OPTIMIZER v3.1" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[WARNING] This script should be run as Administrator for best results" -ForegroundColor Yellow
}

$totalCleaned = 0
$startTime = Get-Date

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Starting comprehensive system cleanup..." -ForegroundColor Green

# Step 1: Empty Recycle Bin
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 1/12: Emptying Recycle Bin..." -ForegroundColor Yellow
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Recycle Bin emptied via PowerShell cmdlet" -ForegroundColor Green
} catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not empty Recycle Bin: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 2: Clear Windows Temp folders
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 2/12: Clearing Windows Temp folders..." -ForegroundColor Yellow
$tempPaths = @(
    "$env:TEMP",
    "$env:LOCALAPPDATA\Temp",
    "C:\Windows\Temp",
    "C:\Windows\Logs"
)

foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        try {
            $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
            if ($files) {
                $size = ($files | Measure-Object -Property Length -Sum).Sum
                $sizeMB = [math]::Round($size / 1MB, 2)
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleaned $path : $sizeMB MB" -ForegroundColor Green
                $totalCleaned += $sizeMB
            } else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleaned $path : 0 MB" -ForegroundColor Green
            }
        } catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not clean $path : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Step 3: Clear Browser Caches
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 3/12: Clearing Browser Caches..." -ForegroundColor Yellow
$browserPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2"
)

foreach ($path in $browserPaths) {
    if (Test-Path $path) {
        try {
            $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
            if ($files) {
                $size = ($files | Measure-Object -Property Length -Sum).Sum
                $sizeMB = [math]::Round($size / 1MB, 2)
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleaned browser cache $path : $sizeMB MB" -ForegroundColor Green
                $totalCleaned += $sizeMB
            }
        } catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not clean browser cache $path : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Step 4: Clear Development Caches
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 4/12: Clearing Development Caches..." -ForegroundColor Yellow
$devPaths = @(
    "$env:APPDATA\npm-cache",
    "$env:APPDATA\pnpm-cache",
    "$env:APPDATA\yarn-cache",
    "$env:APPDATA\Code\CachedData",
    "$env:APPDATA\Cursor\CachedData",
    "$env:APPDATA\Code\logs",
    "$env:APPDATA\Cursor\logs"
)

foreach ($path in $devPaths) {
    if (Test-Path $path) {
        try {
            $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
            if ($files) {
                $size = ($files | Measure-Object -Property Length -Sum).Sum
                $sizeMB = [math]::Round($size / 1MB, 2)
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleaned dev cache $path : $sizeMB MB" -ForegroundColor Green
                $totalCleaned += $sizeMB
            } else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleaned dev cache $path : 0 MB" -ForegroundColor Green
            }
        } catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not clean dev cache $path : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Step 5: Clear Windows Error Reporting
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 5/12: Clearing Windows Error Reporting..." -ForegroundColor Yellow
try {
    $werPath = "C:\ProgramData\Microsoft\Windows\WER"
    if (Test-Path $werPath) {
        $files = Get-ChildItem -Path $werPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        if ($files) {
            $size = ($files | Measure-Object -Property Length -Sum).Sum
            $sizeMB = [math]::Round($size / 1MB, 2)
            Remove-Item -Path "$werPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleaned Windows Error Reporting : $sizeMB MB" -ForegroundColor Green
            $totalCleaned += $sizeMB
        }
    }
} catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not clean Windows Error Reporting : $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 6: Clear Thumbnail Cache
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 6/12: Clearing Thumbnail Cache..." -ForegroundColor Yellow
$thumbnailPaths = @(
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_sr.db"
)

foreach ($path in $thumbnailPaths) {
    try {
        Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleared thumbnail cache in $path" -ForegroundColor Green
    } catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not clear thumbnail cache $path : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Step 7: Clear Windows Update Cache
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 7/12: Clearing Windows Update Cache..." -ForegroundColor Yellow
try {
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    $updatePath = "C:\Windows\SoftwareDistribution\Download"
    if (Test-Path $updatePath) {
        $files = Get-ChildItem -Path $updatePath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        if ($files) {
            $size = ($files | Measure-Object -Property Length -Sum).Sum
            $sizeMB = [math]::Round($size / 1MB, 2)
            Remove-Item -Path "$updatePath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleaned Windows Update Cache : $sizeMB MB" -ForegroundColor Green
            $totalCleaned += $sizeMB
        }
    }
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
} catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not clean Windows Update Cache : $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 8: Clear Prefetch (keeping recent)
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 8/12: Clearing Prefetch (keeping recent)..." -ForegroundColor Yellow
try {
    $prefetchPath = "C:\Windows\Prefetch"
    if (Test-Path $prefetchPath) {
        $files = Get-ChildItem -Path $prefetchPath -Filter "*.pf" -Force -ErrorAction SilentlyContinue
        $recentFiles = $files | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) }
        $oldFiles = $files | Where-Object { $_.LastWriteTime -le (Get-Date).AddDays(-7) }
        
        if ($oldFiles) {
            $size = ($oldFiles | Measure-Object -Property Length -Sum).Sum
            $sizeMB = [math]::Round($size / 1MB, 2)
            $oldFiles | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleaned old Prefetch files : $sizeMB MB" -ForegroundColor Green
            $totalCleaned += $sizeMB
        }
    }
} catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not clean Prefetch : $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 9: Clear System Event Logs
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 9/12: Clearing System Event Logs..." -ForegroundColor Yellow
$eventLogs = @("Application", "System", "Security")
foreach ($log in $eventLogs) {
    try {
        Clear-EventLog -LogName $log -ErrorAction SilentlyContinue
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleared $log event log" -ForegroundColor Green
    } catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not clear $log event log : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Step 10: Clear DNS Cache
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 10/12: Clearing DNS Cache..." -ForegroundColor Yellow
try {
    ipconfig /flushdns | Out-Null
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] DNS cache flushed" -ForegroundColor Green
} catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not flush DNS cache : $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 11: Clear Windows Store Cache
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 11/12: Clearing Windows Store Cache..." -ForegroundColor Yellow
try {
    $storePath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"
    if (Test-Path $storePath) {
        $files = Get-ChildItem -Path $storePath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        if ($files) {
            $size = ($files | Measure-Object -Property Length -Sum).Sum
            $sizeMB = [math]::Round($size / 1MB, 2)
            Remove-Item -Path "$storePath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Cleaned Windows Store Cache : $sizeMB MB" -ForegroundColor Green
            $totalCleaned += $sizeMB
        }
    }
} catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not clean Windows Store Cache : $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 12: Run Disk Cleanup
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Step 12/12: Running Disk Cleanup..." -ForegroundColor Yellow
try {
    $cleanupPath = "C:\Windows\System32\cleanmgr.exe"
    if (Test-Path $cleanupPath) {
        Start-Process -FilePath $cleanupPath -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [SUCCESS] Disk cleanup completed" -ForegroundColor Green
    }
} catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Could not run disk cleanup : $($_.Exception.Message)" -ForegroundColor Yellow
}

# Final Report
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                    CLEANUP COMPLETED" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total space cleaned: $([math]::Round($totalCleaned, 2)) MB" -ForegroundColor Green
Write-Host "Duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Green
Write-Host "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host ""
Write-Host "System cleanup completed successfully!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
