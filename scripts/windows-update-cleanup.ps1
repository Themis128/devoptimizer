# Windows Update Cleanup and Troubleshooting Functions
# CATEGORY: cleanup

function Get-WindowsUpdateStatus {
    Write-Log "Checking Windows Update status..." -Level "INFO"
    
    try {
        $updateResults = @{
            Service = @{}
            PendingUpdates = @()
            UpdateHistory = @()
            LastCheck = $null
            Errors = @()
            CacheSize = 0
        }
        
        # Check Windows Update service status
        $wuService = Get-Service "wuauserv" -ErrorAction SilentlyContinue
        if ($wuService) {
            $updateResults.Service = @{
                Name = $wuService.Name
                Status = $wuService.Status
                StartType = $wuService.StartType
                DisplayName = $wuService.DisplayName
            }
            Write-Log "Windows Update Service: $($wuService.Status)" -Level $(if($wuService.Status -eq "Running") { "SUCCESS" } else { "WARN" })
        }
        
        # Check BITS service (Background Intelligent Transfer Service)
        $bitsService = Get-Service "BITS" -ErrorAction SilentlyContinue
        if ($bitsService) {
            Write-Log "BITS Service: $($bitsService.Status)" -Level $(if($bitsService.Status -eq "Running") { "SUCCESS" } else { "WARN" })
        }
        
        # Check Cryptographic Services
        $cryptService = Get-Service "CryptSvc" -ErrorAction SilentlyContinue
        if ($cryptService) {
            Write-Log "Cryptographic Services: $($cryptService.Status)" -Level $(if($cryptService.Status -eq "Running") { "SUCCESS" } else { "WARN" })
        }
        
        # Get pending updates
        try {
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
            
            foreach ($update in $searchResult.Updates) {
                $updateResults.PendingUpdates += @{
                    Title = $update.Title
                    Description = $update.Description
                    Size = [math]::Round($update.MaxDownloadSize / 1MB, 2)
                    IsDownloaded = $update.IsDownloaded
                    IsMandatory = $update.IsMandatory
                    RebootRequired = $update.RebootRequired
                }
            }
            
            Write-Log "Pending updates: $($updateResults.PendingUpdates.Count)" -Level $(if($updateResults.PendingUpdates.Count -eq 0) { "SUCCESS" } else { "INFO" })
        }
        catch {
            Write-Log "Could not check pending updates: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Check last update check time
        try {
            $lastCheck = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Detect" -Name "LastSuccessTime" -ErrorAction SilentlyContinue
            if ($lastCheck) {
                $updateResults.LastCheck = $lastCheck.LastSuccessTime
                $daysSinceCheck = ((Get-Date) - [DateTime]$lastCheck.LastSuccessTime).Days
                Write-Log "Last successful check: $($lastCheck.LastSuccessTime) ($daysSinceCheck days ago)" -Level $(if($daysSinceCheck -le 1) { "SUCCESS" } elseif($daysSinceCheck -le 7) { "INFO" } else { "WARN" })
            }
        }
        catch {
            Write-Log "Could not determine last update check time" -Level "WARN"
        }
        
        # Check Windows Update cache size
        $cacheFolder = "$env:WINDIR\SoftwareDistribution\Download"
        if (Test-Path $cacheFolder) {
            $cacheSize = (Get-ChildItem $cacheFolder -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $updateResults.CacheSize = $cacheSize
            Write-Log "Update cache size: $([math]::Round($cacheSize / 1MB, 2)) MB" -Level "INFO"
        }
        
        # Check for common update errors in event log
        try {
            $errorEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ID=@(7000,7001,7023,7034); StartTime=(Get-Date).AddDays(-7)} -MaxEvents 50 -ErrorAction SilentlyContinue
            $updateErrors = $errorEvents | Where-Object { $_.Message -like "*Windows Update*" -or $_.Message -like "*wuauserv*" -or $_.Message -like "*BITS*" }
            
            foreach ($error in $updateErrors) {
                $updateResults.Errors += @{
                    Time = $error.TimeCreated
                    ID = $error.Id
                    Level = $error.LevelDisplayName
                    Message = $error.Message.Substring(0, [Math]::Min(200, $error.Message.Length))
                }
            }
            
            if ($updateResults.Errors.Count -gt 0) {
                Write-Log "Found $($updateResults.Errors.Count) recent Windows Update related errors" -Level "WARN"
            }
        }
        catch {
            Write-Log "Could not check event log for update errors" -Level "WARN"
        }
        
        return $updateResults
    }
    catch {
        Write-Log "Error checking Windows Update status: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Reset-WindowsUpdateComponents {
    Write-Log "Resetting Windows Update components..." -Level "INFO"
    
    try {
        # Stop Windows Update services
        $services = @("wuauserv", "cryptSvc", "bits", "msiserver")
        
        Write-Log "Stopping Windows Update services..." -Level "INFO"
        foreach ($service in $services) {
            try {
                $svc = Get-Service $service -ErrorAction SilentlyContinue
                if ($svc -and $svc.Status -eq "Running") {
                    Stop-Service $service -Force -ErrorAction SilentlyContinue
                    Write-Log "Stopped service: $service" -Level "SUCCESS"
                }
            }
            catch {
                Write-Log "Could not stop service: $service" -Level "WARN"
            }
        }
        
        Start-Sleep -Seconds 3
        
        # Clear Windows Update cache
        Write-Log "Clearing Windows Update cache..." -Level "INFO"
        $cacheFolder = "$env:WINDIR\SoftwareDistribution"
        $backupFolder = "$env:WINDIR\SoftwareDistribution.bak"
        
        if (Test-Path $cacheFolder) {
            if (Test-Path $backupFolder) {
                Remove-Item $backupFolder -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            try {
                Rename-Item $cacheFolder $backupFolder -ErrorAction Stop
                Write-Log "Windows Update cache backed up and cleared" -Level "SUCCESS"
            }
            catch {
                Write-Log "Could not clear Windows Update cache: $($_.Exception.Message)" -Level "WARN"
            }
        }
        
        # Clear BITS queue
        Write-Log "Clearing BITS transfer queue..." -Level "INFO"
        try {
            Get-BitsTransfer -AllUsers -ErrorAction SilentlyContinue | Remove-BitsTransfer -ErrorAction SilentlyContinue
            Write-Log "BITS queue cleared" -Level "SUCCESS"
        }
        catch {
            Write-Log "Could not clear BITS queue: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Reset Windows Update registry settings
        Write-Log "Resetting Windows Update registry settings..." -Level "INFO"
        try {
            # Reset Windows Update policies
            $policyPaths = @(
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
            )
            
            foreach ($path in $policyPaths) {
                if (Test-Path $path) {
                    # Backup and remove problematic registry keys
                    $backupPath = "$env:TEMP\WindowsUpdate_Registry_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
                    reg export $path.Replace('HKLM:\', 'HKEY_LOCAL_MACHINE\') $backupPath /y 2>$null
                    
                    # Remove specific problematic values
                    $problematicValues = @("UseWUServer", "WUServer", "WUStatusServer", "NoAutoUpdate")
                    foreach ($value in $problematicValues) {
                        try {
                            Remove-ItemProperty -Path $path -Name $value -ErrorAction SilentlyContinue
                            Write-Log "Removed registry value: $value" -Level "SUCCESS"
                        }
                        catch { }
                    }
                }
            }
        }
        catch {
            Write-Log "Error resetting registry settings: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Re-register Windows Update DLLs
        Write-Log "Re-registering Windows Update DLLs..." -Level "INFO"
        $dlls = @(
            "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
            "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll",
            "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll",
            "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll",
            "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", "wuapi.dll",
            "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll",
            "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll", "wuwebv.dll"
        )
        
        $registeredCount = 0
        foreach ($dll in $dlls) {
            try {
                regsvr32 /s $dll
                if ($LASTEXITCODE -eq 0) {
                    $registeredCount++
                }
            }
            catch { }
        }
        Write-Log "Re-registered $registeredCount Windows Update DLLs" -Level "SUCCESS"
        
        # Reset Winsock
        Write-Log "Resetting Winsock..." -Level "INFO"
        try {
            netsh winsock reset | Out-Null
            Write-Log "Winsock reset completed" -Level "SUCCESS"
        }
        catch {
            Write-Log "Could not reset Winsock: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Start Windows Update services
        Write-Log "Starting Windows Update services..." -Level "INFO"
        foreach ($service in $services) {
            try {
                $svc = Get-Service $service -ErrorAction SilentlyContinue
                if ($svc) {
                    Start-Service $service -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    $svc = Get-Service $service -ErrorAction SilentlyContinue
                    if ($svc.Status -eq "Running") {
                        Write-Log "Started service: $service" -Level "SUCCESS"
                    } else {
                        Write-Log "Service may not have started properly: $service" -Level "WARN"
                    }
                }
            }
            catch {
                Write-Log "Could not start service: $service" -Level "WARN"
            }
        }
        
        Write-Log "Windows Update components reset completed!" -Level "SUCCESS"
        Write-Log "RECOMMENDATION: Restart your computer and then check for updates" -Level "INFO"
        
        return $true
    }
    catch {
        Write-Log "Error resetting Windows Update components: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Clear-WindowsUpdateCache {
    param([switch]$IncludeHistory)
    
    Write-Log "Clearing Windows Update cache..." -Level "INFO"
    
    try {
        $totalCleaned = 0
        
        # Stop Windows Update service
        $wuService = Get-Service "wuauserv" -ErrorAction SilentlyContinue
        $wasRunning = $wuService -and $wuService.Status -eq "Running"
        
        if ($wasRunning) {
            Stop-Service "wuauserv" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        
        # Clear download cache
        $downloadCache = "$env:WINDIR\SoftwareDistribution\Download"
        if (Test-Path $downloadCache) {
            $sizeBefore = (Get-ChildItem $downloadCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            Remove-Item "$downloadCache\*" -Recurse -Force -ErrorAction SilentlyContinue
            $sizeAfter = (Get-ChildItem $downloadCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $cleaned = $sizeBefore - $sizeAfter
            $totalCleaned += $cleaned
            Write-Log "Cleared download cache: $([math]::Round($cleaned / 1MB, 2)) MB" -Level "SUCCESS"
        }
        
        # Clear Windows Update logs
        $logPaths = @(
            "$env:WINDIR\WindowsUpdate.log",
            "$env:WINDIR\Logs\WindowsUpdate\*"
        )
        
        foreach ($logPath in $logPaths) {
            if (Test-Path $logPath) {
                try {
                    $sizeBefore = (Get-ChildItem $logPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    Remove-Item $logPath -Recurse -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $sizeBefore
                }
                catch { }
            }
        }
        
        # Clear update history if requested
        if ($IncludeHistory) {
            Write-Log "Clearing Windows Update history..." -Level "INFO"
            try {
                $historyPath = "$env:WINDIR\SoftwareDistribution\DataStore"
                if (Test-Path $historyPath) {
                    $sizeBefore = (Get-ChildItem $historyPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    Remove-Item "$historyPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $sizeBefore
                    Write-Log "Update history cleared" -Level "SUCCESS"
                }
            }
            catch {
                Write-Log "Could not clear update history: $($_.Exception.Message)" -Level "WARN"
            }
        }
        
        # Clear CBS logs (Component Based Servicing)
        $cbsLogs = "$env:WINDIR\Logs\CBS\*"
        if (Test-Path $cbsLogs) {
            try {
                $sizeBefore = (Get-ChildItem $cbsLogs -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                Get-ChildItem $cbsLogs -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue
                $sizeAfter = (Get-ChildItem $cbsLogs -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                $totalCleaned += ($sizeBefore - $sizeAfter)
            }
            catch { }
        }
        
        # Restart Windows Update service if it was running
        if ($wasRunning) {
            Start-Service "wuauserv" -ErrorAction SilentlyContinue
        }
        
        Write-Log "Windows Update cache cleanup completed: $([math]::Round($totalCleaned / 1MB, 2)) MB freed" -Level "SUCCESS"
        return $totalCleaned
    }
    catch {
        Write-Log "Error clearing Windows Update cache: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Fix-WindowsUpdateErrors {
    Write-Log "Running Windows Update troubleshooter and fixes..." -Level "INFO"
    
    try {
        # Run System File Checker
        Write-Log "Running System File Checker (SFC)..." -Level "INFO"
        try {
            $sfcResult = sfc /scannow
            if ($sfcResult -match "found corrupt files and successfully repaired them") {
                Write-Log "SFC found and repaired corrupt system files" -Level "SUCCESS"
            } elseif ($sfcResult -match "found corrupt files but was unable to fix some of them") {
                Write-Log "SFC found corrupt files but couldn't repair all - DISM may be needed" -Level "WARN"
            } else {
                Write-Log "SFC scan completed - no integrity violations found" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Could not run SFC scan: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Run DISM to repair Windows image
        Write-Log "Running DISM to check Windows image health..." -Level "INFO"
        try {
            # Check image health
            $dismCheck = DISM /Online /Cleanup-Image /CheckHealth
            
            # Scan image health
            Write-Log "Scanning Windows image health (this may take several minutes)..." -Level "INFO"
            $dismScan = DISM /Online /Cleanup-Image /ScanHealth
            
            if ($dismScan -match "corrupt") {
                Write-Log "DISM found corruption - attempting repair..." -Level "WARN"
                $dismRestore = DISM /Online /Cleanup-Image /RestoreHealth
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "DISM repair completed successfully" -Level "SUCCESS"
                } else {
                    Write-Log "DISM repair may have failed - manual intervention may be required" -Level "ERROR"
                }
            } else {
                Write-Log "DISM scan completed - Windows image is healthy" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Could not run DISM repair: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Reset Windows Update components
        Reset-WindowsUpdateComponents
        
        # Clear Windows Update cache
        Clear-WindowsUpdateCache -IncludeHistory
        
        # Run Windows Update troubleshooter if available
        Write-Log "Attempting to run Windows Update troubleshooter..." -Level "INFO"
        try {
            # Try to run the built-in troubleshooter
            $troubleshooter = Get-TroubleshootingPack -Path "$env:WINDIR\diagnostics\system\WindowsUpdate" -ErrorAction SilentlyContinue
            if ($troubleshooter) {
                Invoke-TroubleshootingPack -Pack $troubleshooter -Unattended -ErrorAction SilentlyContinue
                Write-Log "Windows Update troubleshooter completed" -Level "SUCCESS"
            } else {
                Write-Log "Built-in troubleshooter not available" -Level "INFO"
            }
        }
        catch {
            Write-Log "Could not run Windows Update troubleshooter: $($_.Exception.Message)" -Level "WARN"
        }
        
        Write-Log "Windows Update error fixing completed!" -Level "SUCCESS"
        Write-Log "RECOMMENDATION: Restart your computer and then try Windows Update again" -Level "INFO"
        
        return $true
    }
    catch {
        Write-Log "Error fixing Windows Update: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-WindowsUpdateReport {
    Write-Log "Generating comprehensive Windows Update report..." -Level "INFO"
    
    try {
        $report = @{
            SystemInfo = @{}
            UpdateStatus = @{}
            RecentUpdates = @()
            PendingUpdates = @()
            Errors = @()
            Services = @{}
            Recommendations = @()
        }
        
        # System information
        $os = Get-CimInstance Win32_OperatingSystem
        $report.SystemInfo = @{
            OSVersion = $os.Version
            OSBuild = $os.BuildNumber
            OSName = $os.Caption
            LastBootTime = $os.LastBootUpTime
            InstallDate = $os.InstallDate
        }
        
        # Get Windows Update status
        $updateStatus = Get-WindowsUpdateStatus
        $report.UpdateStatus = $updateStatus
        
        # Get recent update history
        try {
            $updateHistory = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10
            foreach ($update in $updateHistory) {
                $report.RecentUpdates += @{
                    HotFixID = $update.HotFixID
                    Description = $update.Description
                    InstalledOn = $update.InstalledOn
                    InstalledBy = $update.InstalledBy
                }
            }
        }
        catch {
            Write-Log "Could not retrieve update history" -Level "WARN"
        }
        
        # Generate recommendations
        if ($updateStatus.PendingUpdates.Count -gt 0) {
            $report.Recommendations += "Install $($updateStatus.PendingUpdates.Count) pending updates"
        }
        
        if ($updateStatus.Service.Status -ne "Running") {
            $report.Recommendations += "Start Windows Update service"
        }
        
        if ($updateStatus.CacheSize -gt 1GB) {
            $report.Recommendations += "Clear Windows Update cache to free $([math]::Round($updateStatus.CacheSize / 1GB, 2)) GB"
        }
        
        if ($updateStatus.Errors.Count -gt 0) {
            $report.Recommendations += "Investigate $($updateStatus.Errors.Count) recent Windows Update errors"
        }
        
        # Display report summary
        Write-Log "=== WINDOWS UPDATE REPORT ===" -Level "SUCCESS"
        Write-Log "OS Version: $($report.SystemInfo.OSName) Build $($report.SystemInfo.OSBuild)" -Level "INFO"
        Write-Log "Windows Update Service: $($report.UpdateStatus.Service.Status)" -Level "INFO"
        Write-Log "Pending Updates: $($report.UpdateStatus.PendingUpdates.Count)" -Level "INFO"
        Write-Log "Recent Updates: $($report.RecentUpdates.Count)" -Level "INFO"
        Write-Log "Cache Size: $([math]::Round($report.UpdateStatus.CacheSize / 1MB, 2)) MB" -Level "INFO"
        Write-Log "Recent Errors: $($report.UpdateStatus.Errors.Count)" -Level "INFO"
        
        if ($report.Recommendations.Count -gt 0) {
            Write-Log "Recommendations:" -Level "WARN"
            foreach ($rec in $report.Recommendations) {
                Write-Log "  - $rec" -Level "WARN"
            }
        }
        
        return $report
    }
    catch {
        Write-Log "Error generating Windows Update report: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}
