<#
.SYNOPSIS
    Admin cleanup suite run elevated: DISM, update caches, shadow-copy pruning, WSL VHDX compaction.
.DESCRIPTION
    Admin cleanup suite run elevated: DISM, update caches, shadow-copy pruning.
    Section 6 compacts docker_data.vhdx (terminates only the docker-desktop
    distro - Ubuntu keeps running). Pass -ShutdownWsl to also compact the
    Ubuntu ext4.vhdx, which requires a full wsl --shutdown.
#>
param(
    [switch]$ShutdownWsl
)

# Windows 11 Admin Cleanup - Run Elevated
$ErrorActionPreference = 'Continue'

# Import shared modules
. "$PSScriptRoot\lib\Notify.ps1"

function MB { param($b) [math]::Round($b/1MB, 1) }
function GB { param($b) [math]::Round($b/1GB, 2) }

# Check if running with administrator privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


$before = (Get-PSDrive C).Free
Write-Host "=== Windows 11 Admin Cleanup ===" -ForegroundColor Magenta
Write-Host ("C: free before: {0:N2} GB`n" -f ($before/1GB))

# 0. Docker Desktop firewall repair: published container ports are served by
# com.docker.backend.exe, but the built-in "Docker Desktop Backend" allow rules
# point at the old Program Files path. After Docker Desktop moved to
# %LOCALAPPDATA%\Programs\DockerDesktop, inbound LAN traffic to published ports
# (e.g. social-metrics :9390 scraped by Prometheus) is dropped on the Public
# profile. Re-create an allow rule for the real binary path when missing.
$dockerBackend = "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\com.docker.backend.exe"
if (Test-Path $dockerBackend) {
    $existing = Get-NetFirewallRule -DisplayName 'Docker Desktop Backend (user path)' -ErrorAction SilentlyContinue
    if (-not $existing) {
        try {
            New-NetFirewallRule -DisplayName 'Docker Desktop Backend (user path)' `
                -Direction Inbound -Action Allow -Program $dockerBackend `
                -Profile Any -Enabled True -ErrorAction Stop | Out-Null
            Write-Host "[0] Created inbound allow rule for $dockerBackend" -ForegroundColor Green
        } catch {
            Write-Host "[0] Firewall rule creation failed: $_" -ForegroundColor Yellow
        }
    }
}

# 1. DISM Component Store Cleanup
Write-Host "--- [1] DISM Component Store Cleanup ---" -ForegroundColor Cyan
Write-Host "Running: Dism /Online /Cleanup-Image /StartComponentCleanup"
Write-Host "This may take several minutes..." -ForegroundColor Yellow
$dismResult = Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart 2>&1
$dismResult | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -eq 0) {
    Write-Host "[1] DISM component cleanup: COMPLETED" -ForegroundColor Green
} else {
    Write-Host "[1] DISM component cleanup: EXIT CODE $LASTEXITCODE" -ForegroundColor Red
    Write-Host "  This script is running with administrator privileges." -ForegroundColor Yellow
    Write-Host "  The DISM error may be transient; consider running DISM /Online /Cleanup-Image /RestoreHealth first." -ForegroundColor Yellow
    Send-DevOptAlert -Severity Warning -Title "Admin Cleanup: DISM Failed" -Message "DISM /StartComponentCleanup exited with code $LASTEXITCODE. Output: $($dismResult -join '; ')" -Tags 'cleanup', 'dism', 'admin' -EventId 1005
}

# 2. Windows Update Download Cache
Write-Host "`n--- [2] Windows Update Download Cache ---" -ForegroundColor Cyan
$wuPath = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wuPath) {
    $wuItems = Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
    if ($wuItems) {
        $size = ($wuItems | Measure-Object Length -Sum).Sum
    } else {
        $size = 0
    }
    Write-Host "Stopping wuauserv service..."
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    if (Test-Path $wuPath) {
        Write-Host "Clearing $wuPath ($([math]::Round($size/1GB,2)) GB)..."
        Get-ChildItem $wuPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Restarting wuauserv service..."
    Start-Service wuauserv -ErrorAction SilentlyContinue
    if (Test-Path $wuPath) {
        $wuItemsAfter = Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
        if ($wuItemsAfter) {
            $newSize = ($wuItemsAfter | Measure-Object Length -Sum).Sum
        } else {
            $newSize = 0
        }
        Write-Host ("[2] Windows Update cache cleaned: -{0} GB" -f (GB ($size - $newSize))) -ForegroundColor Green
    } else {
        Write-Host ("[2] Windows Update cache cleaned: -{0} GB" -f (GB ($size))) -ForegroundColor Green
    }
} else {
    Write-Host "[2] Windows Update cache: path not found" -ForegroundColor DarkGray
}

# 3. Delivery Optimization Cache - Using direct folder deletion to avoid interactive prompt
Write-Host "`n--- [3] Delivery Optimization Cache ---" -ForegroundColor Cyan
try {
    $doCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\DeliveryOptimization"
    if (Test-Path $doCachePath) {
        $doItems = Get-ChildItem $doCachePath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
        if ($doItems) {
            $size = ($doItems | Measure-Object Length -Sum).Sum
        } else {
            $size = 0
        }
        Write-Host "Removing Delivery Optimization cache ($([math]::Round($size/1MB,2)) MB)..."
        Remove-Item -Path $doCachePath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[3] Delivery Optimization cache: CLEARED" -ForegroundColor Green
    } else {
        Write-Host "[3] Delivery Optimization cache: not found" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "[3] Delivery Optimization cache: SKIPPED ($($_.Exception.Message.Split("`n")[0]))" -ForegroundColor DarkGray
}

# 4. System Restore Points / Shadow Copies
Write-Host "`n--- [4] System Restore Points (oldest only) ---" -ForegroundColor Cyan
Write-Host "Running: vssadmin delete shadows /for=c: /oldest /quiet"
try {
    $vssResult = vssadmin delete shadows /for=c: /oldest /quiet 2>&1
    $vssResult | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[4] Oldest shadow copy: DELETED" -ForegroundColor Green
    } else {
        Write-Host "[4] Shadow copy: EXIT CODE $LASTEXITCODE (may be none to delete)" -ForegroundColor DarkGray
        # Alert on unexpected vssadmin failures (not just "no shadows")
        $vssOutput = $vssResult -join ' '
        if ($vssOutput -notmatch 'no items|no shadows|nothing to delete') {
            Send-DevOptAlert -Severity Warning -Title "Admin Cleanup: Shadow Copy Failed" -Message "vssadmin delete shadows exited with code $LASTEXITCODE. Output: $vssOutput" -Tags 'cleanup', 'vss', 'admin' -EventId 1006
        }
    }
} catch {
    Write-Host "[4] Shadow copy deletion skipped (may require admin): $($_.Exception.Message)" -ForegroundColor DarkGray
    Send-DevOptAlert -Severity Warning -Title "Admin Cleanup: Shadow Copy Exception" -Message "vssadmin threw exception: $($_.Exception.Message)" -Tags 'cleanup', 'vss', 'admin' -EventId 1006
}

# 5. Windows.old if exists
Write-Host "`n--- [5] Windows.old folder (if present) ---" -ForegroundColor Cyan
$winOld = "C:\Windows.old"
if (Test-Path $winOld) {
    $winOldItems = Get-ChildItem $winOld -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
    if ($winOldItems) {
        $size = ($winOldItems | Measure-Object Length -Sum).Sum
    } else {
        $size = 0
    }
    Write-Host "Found Windows.old ($([math]::Round($size/1GB,2)) GB) - removing..."
    takeown /f "$winOld" /r /d y 2>&1 | Out-Null
    icacls "$winOld" /grant administrators:F /t /c /q 2>&1 | Out-Null
    Remove-Item $winOld -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ("[5] Windows.old removed: -{0} GB" -f (GB ($size))) -ForegroundColor Green
} else {
    Write-Host "[5] Windows.old: not found" -ForegroundColor DarkGray
}

# 6. WSL VHDX compaction - docker_data.vhdx is the largest file on C: (~230GB
# allocated vs ~90GB used after the 2026-11-11 image prune). Compaction needs
# the disk detached, which only needs the docker-desktop distro stopped -
# Ubuntu-24.04 keeps running. ext4.vhdx (Ubuntu) additionally needs a full
# wsl --shutdown, so it only runs with -ShutdownWsl.
Write-Host "`n--- [6] WSL VHDX compaction ---" -ForegroundColor Cyan

function Test-VhdxLocked([string]$path) {
    try {
        $fs = [System.IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
        $fs.Close()
        return $false
    } catch { return $true }
}

function Compact-Vhdx([string]$path, [string]$label) {
    if (-not (Test-Path $path)) { Write-Host "  $label`: not found" -ForegroundColor DarkGray; return }
    $sizeBefore = (Get-Item $path).Length
    if (Test-VhdxLocked $path) { Write-Host "  $label`: still in use, skipped" -ForegroundColor Yellow; return }
    Write-Host ("  {0}: {1:N1} GB before compact" -f $label, ($sizeBefore/1GB))
    try {
        Optimize-VHD -Path $path -Mode Full -ErrorAction Stop
        $sizeAfter = (Get-Item $path).Length
        Write-Host ("  {0}: {1:N1} GB after  (-{2:N1} GB)" -f $label, ($sizeAfter/1GB), (($sizeBefore-$sizeAfter)/1GB)) -ForegroundColor Green
    } catch {
        Write-Host ("  {0}: compact failed - {1}" -f $label, $_.Exception.Message.Split("`n")[0]) -ForegroundColor Red
        Send-DevOptAlert -Severity Warning -Title "VHDX Compact Failed: $label" -Message $_.Exception.Message -Tags 'cleanup','vhdx','admin' -EventId 1007
    }
}

$dockerData = "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx"
$wslExe = 'wsl.exe'
try {
    & $wslExe --manage docker-desktop --set-sparse true 2>&1 | Out-Null
} catch {}
& $wslExe --terminate docker-desktop 2>&1 | Out-Null
$waited = 0
while ((Test-Path $dockerData) -and (Test-VhdxLocked $dockerData) -and $waited -lt 60) {
    Start-Sleep 5; $waited += 5
}
if ((Test-Path $dockerData) -and -not (Test-VhdxLocked $dockerData)) {
    Compact-Vhdx $dockerData 'docker_data.vhdx'
} else {
    Write-Host "  docker_data.vhdx: still locked after ${waited}s, skipped" -ForegroundColor Yellow
}
# Docker Desktop restarts its backend on the next docker command / app launch.

if ($ShutdownWsl) {
    Write-Host "  -ShutdownWsl: running wsl --shutdown (ALL distros stop) ..." -ForegroundColor Yellow
    & $wslExe --shutdown 2>&1 | Out-Null
    Start-Sleep 10
    $ubuntuVhdx = 'C:\WSL\Ubuntu-24.04\ext4.vhdx'
    foreach ($d in 'docker-desktop', 'Ubuntu-24.04') {
        try { & $wslExe --manage $d --set-sparse true 2>&1 | Out-Null } catch {}
    }
    Compact-Vhdx $dockerData 'docker_data.vhdx (post-shutdown)'
    Compact-Vhdx $ubuntuVhdx 'Ubuntu ext4.vhdx'
    Write-Host "  WSL distros restart on demand (wsl -d Ubuntu-24.04 / Docker Desktop)." -ForegroundColor DarkGray
} else {
    $ubuntuVhdx = 'C:\WSL\Ubuntu-24.04\ext4.vhdx'
    if (Test-Path $ubuntuVhdx) {
        Write-Host "  Ubuntu ext4.vhdx: skipped (needs -ShutdownWsl for full wsl --shutdown)" -ForegroundColor DarkGray
    }
}

# Summary
$after = (Get-PSDrive C).Free
Write-Host "`n=== Summary ===" -ForegroundColor Magenta
Write-Host ("C: free before: {0:N2} GB" -f ($before/1GB))
Write-Host ("C: free after  : {0:N2} GB" -f ($after/1GB))
Write-Host ("Freed on C:   : {0:N2} GB" -f (($after - $before)/1GB))
Write-Host "`nDone. A reboot is recommended after DISM operations." -ForegroundColor Yellow

exit 0