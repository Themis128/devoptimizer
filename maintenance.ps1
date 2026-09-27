#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Comprehensive Windows 11 Maintenance & Optimization Script
    
.DESCRIPTION
    Automated system maintenance for Windows 11 Enterprise
    - Disk cleanup and space recovery
    - System optimization
    - Health checks and repairs
    - Performance tuning
    
.AUTHOR
    Created for Themistoklis Baltzakis
    
.DATE
    February 2026
#>

# Color output functions
function Write-Success { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "ℹ $msg" -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }
function Write-Section { param($msg) Write-Host "`n═══ $msg ═══" -ForegroundColor Magenta }

# Initialize
$ErrorActionPreference = "Continue"
$StartTime = Get-Date
$LogFile = "$env:USERPROFILE\Desktop\Maintenance-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param($Message, $Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Host $Message -ForegroundColor $Color
}

Write-Log "═══════════════════════════════════════════════════════" "Magenta"
Write-Log "Windows 11 Maintenance Script Started" "Magenta"
Write-Log "═══════════════════════════════════════════════════════" "Magenta"

# ═══════════════════════════════════════════════════════════════
# SECTION 1: PRE-CHECK & SYSTEM INFORMATION
# ═══════════════════════════════════════════════════════════════
Write-Section "System Information"

$OSInfo = Get-ComputerInfo | Select-Object OsName, OsVersion, OsArchitecture
$Memory = [math]::Round((Get-ComputerInfo).CsTotalPhysicalMemory / 1GB, 2)
Write-Log "OS: $($OSInfo.OsName)" "Cyan"
Write-Log "Version: $($OSInfo.OsVersion)" "Cyan"
Write-Log "RAM: $Memory GB" "Cyan"

Write-Section "Disk Space Analysis (Before)"
$VolumesBefore = Get-Volume | Where-Object {$_.DriveLetter} | Select-Object DriveLetter, 
    @{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,2)}}, 
    @{Name="FreeGB";Expression={[math]::Round($_.SizeRemaining/1GB,2)}}, 
    @{Name="UsedPercent";Expression={[math]::Round((($_.Size - $_.SizeRemaining)/$_.Size)*100,2)}}

$VolumesBefore | ForEach-Object {
    $color = if($_.UsedPercent -gt 90) {"Red"} elseif($_.UsedPercent -gt 80) {"Yellow"} else {"Green"}
    Write-Log "Drive $($_.DriveLetter): $($_.FreeGB) GB free of $($_.SizeGB) GB ($($_.UsedPercent)% used)" $color
}

# ═══════════════════════════════════════════════════════════════
# SECTION 2: CLEANUP OPERATIONS
# ═══════════════════════════════════════════════════════════════
Write-Section "Starting Cleanup Operations"

# 2.1: Clear Windows Update Cache
Write-Info "Clearing Windows Update Cache..."
try {
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
    
    $UpdateCacheSize = (Get-ChildItem C:\Windows\SoftwareDistribution\Download -Recurse -ErrorAction SilentlyContinue | 
        Measure-Object -Property Length -Sum).Sum / 1GB
    
    Remove-Item C:\Windows\SoftwareDistribution\Download\* -Recurse -Force -ErrorAction SilentlyContinue
    
    Start-Service -Name wuauserv
    Start-Service -Name bits
    Write-Success "Cleared $([math]::Round($UpdateCacheSize, 2)) GB from Windows Update cache"
} catch {
    Write-Warning "Windows Update cache cleanup failed: $_"
}

# 2.2: Clear Temp Files
Write-Info "Cleaning temporary files..."
$TempLocations = @(
    "$env:TEMP\*",
    "C:\Windows\Temp\*",
    "$env:LOCALAPPDATA\Temp\*"
)

$TotalTempCleaned = 0
foreach ($Location in $TempLocations) {
    try {
        $sizeBefore = (Get-ChildItem (Split-Path $Location) -Recurse -File -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum / 1GB
        Remove-Item $Location -Recurse -Force -ErrorAction SilentlyContinue
        $TotalTempCleaned += $sizeBefore
    } catch {
        Write-Warning "Could not clean: $Location"
    }
}
Write-Success "Cleared $([math]::Round($TotalTempCleaned, 2)) GB from temp folders"

# 2.3: Empty Recycle Bin
Write-Info "Emptying Recycle Bin..."
try {
    $RecycleSize = (Get-ChildItem 'C:\$Recycle.Bin' -Recurse -Force -ErrorAction SilentlyContinue | 
        Measure-Object -Property Length -Sum).Sum / 1GB
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Success "Cleared $([math]::Round($RecycleSize, 2)) GB from Recycle Bin"
} catch {
    Write-Warning "Recycle Bin cleanup failed: $_"
}

# 2.4: Clear Browser Caches
Write-Info "Clearing browser caches..."
$BrowserCaches = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2\*"
)

$BrowserCacheSize = 0
foreach ($Cache in $BrowserCaches) {
    try {
        $path = Split-Path $Cache
        if (Test-Path $path) {
            $sizeBefore = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum / 1GB
            Remove-Item $Cache -Recurse -Force -ErrorAction SilentlyContinue
            $BrowserCacheSize += $sizeBefore
        }
    } catch {}
}
Write-Success "Cleared $([math]::Round($BrowserCacheSize, 2)) GB from browser caches"

# 2.5: Clear Windows Error Reporting
Write-Info "Clearing Windows Error Reporting files..."
try {
    $WERSize = (Get-ChildItem C:\ProgramData\Microsoft\Windows\WER -Recurse -ErrorAction SilentlyContinue | 
        Measure-Object -Property Length -Sum).Sum / 1GB
    Remove-Item C:\ProgramData\Microsoft\Windows\WER\* -Recurse -Force -ErrorAction SilentlyContinue
    Write-Success "Cleared $([math]::Round($WERSize, 2)) GB from Error Reporting"
} catch {
    Write-Warning "WER cleanup failed"
}

# 2.6: Clear Windows Logs
Write-Info "Clearing old Windows Event Logs..."
try {
    wevtutil el | ForEach-Object { wevtutil cl $_ 2>$null }
    Write-Success "Cleared Windows Event Logs"
} catch {
    Write-Warning "Event log cleanup failed"
}

# 2.7: Windows Disk Cleanup (Deep Clean)
Write-Info "Running Windows Disk Cleanup utility..."
try {
    # Configure cleanmgr for automated cleanup
    $VolumeCaches = @(
        "Active Setup Temp Folders",
        "BranchCache",
        "Downloaded Program Files",
        "Internet Cache Files",
        "Offline Pages Files",
        "Old ChkDsk Files",
        "Previous Installations",
        "Recycle Bin",
        "Service Pack Cleanup",
        "Setup Log Files",
        "System error memory dump files",
        "System error minidump files",
        "Temporary Files",
        "Temporary Setup Files",
        "Thumbnail Cache",
        "Update Cleanup",
        "Upgrade Discarded Files",
        "Windows Defender",
        "Windows Error Reporting Archive Files",
        "Windows Error Reporting Queue Files",
        "Windows Error Reporting System Archive Files",
        "Windows Error Reporting System Queue Files",
        "Windows ESD installation files",
        "Windows Upgrade Log Files"
    )
    
    foreach ($VolumeCache in $VolumeCaches) {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$VolumeCache"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name StateFlags0100 -Type DWORD -Value 2 -ErrorAction SilentlyContinue
        }
    }
    
    Start-Process -FilePath CleanMgr.exe -ArgumentList "/sagerun:100" -Wait -NoNewWindow
    Write-Success "Disk Cleanup completed"
} catch {
    Write-Warning "Disk Cleanup failed: $_"
}

# 2.8: Clear Package Cache
Write-Info "Clearing package manager caches..."
try {
    # npm cache
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $npmCachePath = npm config get cache
        if (Test-Path $npmCachePath) {
            $npmSize = (Get-ChildItem $npmCachePath -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum / 1GB
            npm cache clean --force 2>$null
            Write-Success "Cleared $([math]::Round($npmSize, 2)) GB from npm cache"
        }
    }
    
    # pip cache
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        pip cache purge 2>$null
        Write-Success "Cleared pip cache"
    }
} catch {
    Write-Warning "Package cache cleanup partial"
}

# 2.9: Clear Microsoft Store Cache
Write-Info "Clearing Microsoft Store cache..."
try {
    Start-Process wsreset.exe -WindowStyle Hidden
    Start-Sleep -Seconds 5
    Stop-Process -Name WinStore.App -ErrorAction SilentlyContinue
    Write-Success "Microsoft Store cache cleared"
} catch {
    Write-Warning "Store cache cleanup failed"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 3: SYSTEM OPTIMIZATION
# ═══════════════════════════════════════════════════════════════
Write-Section "System Optimization"

# 3.1: Optimize Drives
Write-Info "Optimizing drives..."
Get-Volume | Where-Object {$_.DriveLetter -and $_.DriveType -eq 'Fixed'} | ForEach-Object {
    try {
        Optimize-Volume -DriveLetter $_.DriveLetter -Defrag -Verbose
        Write-Success "Optimized drive $($_.DriveLetter):"
    } catch {
        Write-Warning "Could not optimize drive $($_.DriveLetter):"
    }
}

# 3.2: Check and Repair System Files
Write-Info "Running System File Checker..."
try {
    $sfcResult = sfc /scannow
    Write-Success "System File Check completed"
} catch {
    Write-Warning "SFC failed: $_"
}

# 3.3: DISM Health Check and Repair
Write-Info "Running DISM health check..."
try {
    DISM /Online /Cleanup-Image /CheckHealth
    DISM /Online /Cleanup-Image /ScanHealth
    DISM /Online /Cleanup-Image /RestoreHealth
    Write-Success "DISM repair completed"
} catch {
    Write-Warning "DISM repair failed: $_"
}

# 3.4: Update Windows Defender Definitions
Write-Info "Updating Windows Defender..."
try {
    Update-MpSignature
    Write-Success "Defender signatures updated"
} catch {
    Write-Warning "Defender update failed"
}

# 3.5: Clear DNS Cache
Write-Info "Clearing DNS cache..."
try {
    Clear-DnsClientCache
    Write-Success "DNS cache cleared"
} catch {
    Write-Warning "DNS cache clear failed"
}

# 3.6: Reset Network Stack
Write-Info "Resetting network stack..."
try {
    netsh winsock reset
    netsh int ip reset
    Write-Success "Network stack reset"
} catch {
    Write-Warning "Network reset failed"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 4: PERFORMANCE TUNING
# ═══════════════════════════════════════════════════════════════
Write-Section "Performance Tuning"

# 4.1: Disable Unnecessary Startup Programs
Write-Info "Analyzing startup programs..."
$StartupItems = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location
Write-Log "Found $($StartupItems.Count) startup items" "Yellow"

# 4.2: Clear Prefetch
Write-Info "Clearing prefetch data..."
try {
    Remove-Item C:\Windows\Prefetch\* -Force -ErrorAction SilentlyContinue
    Write-Success "Prefetch cleared"
} catch {
    Write-Warning "Prefetch cleanup failed"
}

# 4.3: Optimize Page File
Write-Info "Checking page file configuration..."
$PageFile = Get-CimInstance Win32_PageFileUsage
Write-Log "Page file: $($PageFile.AllocatedBaseSize) MB allocated" "Cyan"

# 4.4: Check Windows Search Index
Write-Info "Rebuilding Windows Search index..."
try {
    Stop-Service -Name WSearch -Force
    Remove-Item C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb -Force -ErrorAction SilentlyContinue
    Start-Service -Name WSearch
    Write-Success "Search index rebuilt"
} catch {
    Write-Warning "Search index rebuild failed"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 5: HEALTH CHECKS
# ═══════════════════════════════════════════════════════════════
Write-Section "System Health Checks"

# 5.1: Check Disk Health
Write-Info "Checking disk health..."
Get-PhysicalDisk | ForEach-Object {
    $health = if ($_.HealthStatus -eq 'Healthy') { 'Green' } else { 'Red' }
    Write-Log "  $($_.FriendlyName): $($_.HealthStatus) - $($_.OperationalStatus)" $health
}

# 5.2: Check Memory Diagnostics
Write-Info "Checking system memory..."
$Memory = Get-CimInstance Win32_PhysicalMemory
$TotalMemory = ($Memory | Measure-Object -Property Capacity -Sum).Sum / 1GB
Write-Log "Total RAM: $([math]::Round($TotalMemory, 2)) GB" "Green"

# 5.3: Check Battery Health (if laptop)
try {
    $Battery = Get-CimInstance Win32_Battery
    if ($Battery) {
        Write-Log "Battery Status: $($Battery.Status)" "Cyan"
        Write-Log "Battery Charge: $($Battery.EstimatedChargeRemaining)%" "Cyan"
    }
} catch {
    Write-Info "No battery detected (desktop system)"
}

# 5.4: Check Temperature Sensors (if available)
Write-Info "Checking system sensors..."
try {
    $Temps = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction SilentlyContinue
    if ($Temps) {
        $Temps | ForEach-Object {
            $celsius = [math]::Round(($_.CurrentTemperature - 2732) / 10, 1)
            Write-Log "  Zone: $celsius°C" "Cyan"
        }
    }
} catch {
    Write-Info "Temperature sensors not available"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 6: FINAL REPORT
# ═══════════════════════════════════════════════════════════════
Write-Section "Final Report"

# Space recovery calculation
Write-Log "`nDisk Space Analysis (After):" "Magenta"
$VolumesAfter = Get-Volume | Where-Object {$_.DriveLetter} | Select-Object DriveLetter, 
    @{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,2)}}, 
    @{Name="FreeGB";Expression={[math]::Round($_.SizeRemaining/1GB,2)}}, 
    @{Name="UsedPercent";Expression={[math]::Round((($_.Size - $_.SizeRemaining)/$_.Size)*100,2)}}

$SpaceRecovered = 0
for ($i = 0; $i -lt $VolumesBefore.Count; $i++) {
    $before = $VolumesBefore[$i]
    $after = $VolumesAfter[$i]
    $recovered = [math]::Round($after.FreeGB - $before.FreeGB, 2)
    $SpaceRecovered += $recovered
    
    $color = if($after.UsedPercent -lt 80) {"Green"} elseif($after.UsedPercent -lt 90) {"Yellow"} else {"Red"}
    Write-Log "Drive $($after.DriveLetter): $($after.FreeGB) GB free (+$recovered GB recovered)" $color
}

Write-Log "`n══════════════════════════════════════" "Magenta"
Write-Log "Total Space Recovered: $([math]::Round($SpaceRecovered, 2)) GB" "Green"
Write-Log "══════════════════════════════════════" "Magenta"

# Execution time
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
Write-Log "`nScript execution time: $($Duration.Minutes) minutes, $($Duration.Seconds) seconds" "Cyan"

Write-Log "`n═══════════════════════════════════════════════════════" "Magenta"
Write-Log "Maintenance Complete! Log saved to: $LogFile" "Green"
Write-Log "═══════════════════════════════════════════════════════" "Magenta"

# Recommendations
Write-Log "`nRECOMMENDATIONS:" "Yellow"
if ($VolumesAfter[0].UsedPercent -gt 85) {
    Write-Warning "C: drive still critically full. Consider:"
    Write-Warning "  1. Move personal files to D: drive"
    Write-Warning "  2. Uninstall unused applications"
    Write-Warning "  3. Move development projects to D: drive"
    Write-Warning "  4. Clean up old VM images or containers"
}

Write-Warning "`nA system restart is recommended to complete optimization."
$Restart = Read-Host "`nWould you like to restart now? (Y/N)"
if ($Restart -eq 'Y' -or $Restart -eq 'y') {
    Write-Success "Restarting in 30 seconds... (Press Ctrl+C to cancel)"
    Start-Sleep -Seconds 30
    Restart-Computer -Force
} else {
    Write-Info "Please restart your computer when convenient."
}