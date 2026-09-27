# =====================================================
# WINDOWS INSIDER AUTOMATION POWERSHELL MODULE v4.0
# Advanced automation functionality for Windows Insider
# =====================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Operation,

    [Parameter(Mandatory=$false)]
    [hashtable]$Parameters = @{},

    [Parameter(Mandatory=$false)]
    [switch]$Silent,

    [Parameter(Mandatory=$false)]
    [switch]$DebugMode
)

# Import core module
$coreModule = "$PSScriptRoot\DevOptimizer-Core.ps1"
if (Test-Path $coreModule) {
    . $coreModule
}

# =====================================================
# INSIDER AUTOMATION FUNCTIONS
# =====================================================

function Invoke-AutoSetupInsider {
    param([hashtable]$Options = @{})

    Write-Log "INFO" "Starting automated Insider setup"

    try {
        $tasks = @(
            @{ Name = "System Check"; Action = { Test-InsiderCompatibility } },
            @{ Name = "Backup Creation"; Action = { Create-SystemBackup } },
            @{ Name = "Channel Configuration"; Action = { Set-DefaultInsiderChannel } },
            @{ Name = "Privacy Settings"; Action = { Configure-InsiderPrivacy } },
            @{ Name = "Update Configuration"; Action = { Configure-WindowsUpdate } },
            @{ Name = "Diagnostic Setup"; Action = { Setup-DiagnosticCollection } }
        )

        $results = @()
        $completed = 0

        foreach ($task in $tasks) {
            Write-Log "INFO" "Executing automated task: $($task.Name)"
            Write-Progress -Activity "Insider Auto-Setup" -Status $task.Name -PercentComplete (($completed / $tasks.Count) * 100)

            $result = & $task.Action
            $results += @{
                Task = $task.Name
                Success = $result
                Timestamp = Get-Date
            }

            $completed++
            Start-Sleep -Seconds 1
        }

        Write-Progress -Activity "Insider Auto-Setup" -Completed

        # Generate report
        $reportPath = "$script:HubPath\reports\insider-autosetup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $results | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Encoding UTF8

        Write-Log "SUCCESS" "Automated Insider setup completed. Report: $reportPath"
        return $true
    }
    catch {
        Write-Log "ERROR" "Automated setup failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-DailyHealthCheck {
    param([hashtable]$Options = @{})

    Write-Log "INFO" "Starting daily health check"

    try {
        $healthReport = @{
            Timestamp = Get-Date
            SystemInfo = Get-SystemInfo
            InsiderStatus = Get-InsiderStatus
            UpdateStatus = Get-WindowsUpdateStatus
            DiskSpace = Get-DiskSpaceInfo
            Services = Get-CriticalServicesStatus
            EventLogs = Get-RecentCriticalEvents
        }

        # Check for issues
        $issues = @()

        # Check disk space
        if ($healthReport.DiskSpace.FreeSpaceGB -lt 10) {
            $issues += "Low disk space: $($healthReport.DiskSpace.FreeSpaceGB)GB free"
        }

        # Check critical services
        $downServices = $healthReport.Services | Where-Object { $_.Status -ne "Running" }
        if ($downServices) {
            $issues += "Critical services down: $($downServices.Name -join ', ')"
        }

        # Check for critical events
        if ($healthReport.EventLogs.Count -gt 0) {
            $issues += "Critical events found: $($healthReport.EventLogs.Count) events"
        }

        $healthReport.Issues = $issues
        $healthReport.HealthScore = if ($issues.Count -eq 0) { 100 } else { [math]::Max(0, 100 - ($issues.Count * 20)) }

        # Save report
        $reportPath = "$script:HubPath\reports\daily-health_$(Get-Date -Format 'yyyyMMdd').json"
        $healthReport | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Encoding UTF8

        Write-Log "INFO" "Daily health check completed. Score: $($healthReport.HealthScore)/100"
        return $healthReport
    }
    catch {
        Write-Log "ERROR" "Daily health check failed: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-WeeklyDeepScan {
    param([hashtable]$Options = @{})

    Write-Log "INFO" "Starting weekly deep scan"

    try {
        $scanReport = @{
            Timestamp = Get-Date
            SystemFileCheck = Invoke-SystemFileCheck
            RegistryCheck = Invoke-RegistryHealthCheck
            DriverAnalysis = Get-DriverAnalysis
            SecurityScan = Invoke-SecurityScan
            PerformanceAnalysis = Get-PerformanceAnalysis
            InsiderBuildHistory = Get-InsiderBuildHistory
        }

        # Calculate overall health
        $healthMetrics = @(
            $scanReport.SystemFileCheck.HealthScore,
            $scanReport.RegistryCheck.HealthScore,
            $scanReport.DriverAnalysis.HealthScore,
            $scanReport.SecurityScan.HealthScore,
            $scanReport.PerformanceAnalysis.HealthScore
        )

        $scanReport.OverallHealth = ($healthMetrics | Measure-Object -Average).Average

        # Save comprehensive report
        $reportPath = "$script:HubPath\reports\weekly-deepscan_$(Get-Date -Format 'yyyyMMdd').json"
        $scanReport | ConvertTo-Json -Depth 4 | Out-File -FilePath $reportPath -Encoding UTF8

        Write-Log "SUCCESS" "Weekly deep scan completed. Overall health: $([math]::Round($scanReport.OverallHealth, 2))/100"
        return $scanReport
    }
    catch {
        Write-Log "ERROR" "Weekly deep scan failed: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-PreUpdatePreparation {
    param([hashtable]$Options = @{})

    Write-Log "INFO" "Starting pre-update preparation"

    try {
        $tasks = @(
            @{ Name = "System Backup"; Action = { Create-PreUpdateBackup } },
            @{ Name = "Disk Cleanup"; Action = { Invoke-ComprehensiveDiskCleanup } },
            @{ Name = "Service Optimization"; Action = { Optimize-ServicesForUpdate } },
            @{ Name = "Registry Cleanup"; Action = { Clean-UpdateRegistry } },
            @{ Name = "Driver Preparation"; Action = { Prepare-DriversForUpdate } }
        )

        $results = @()
        $completed = 0

        foreach ($task in $tasks) {
            Write-Log "INFO" "Pre-update task: $($task.Name)"
            Write-Progress -Activity "Pre-Update Preparation" -Status $task.Name -PercentComplete (($completed / $tasks.Count) * 100)

            $result = & $task.Action
            $results += @{
                Task = $task.Name
                Success = $result
                Timestamp = Get-Date
            }

            $completed++
        }

        Write-Progress -Activity "Pre-Update Preparation" -Completed

        # Save preparation report
        $reportPath = "$script:HubPath\reports\pre-update-prep_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $results | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Encoding UTF8

        Write-Log "SUCCESS" "Pre-update preparation completed"
        return $true
    }
    catch {
        Write-Log "ERROR" "Pre-update preparation failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-PostUpdateValidation {
    param([hashtable]$Options = @{})

    Write-Log "INFO" "Starting post-update validation"

    try {
        $validation = @{
            Timestamp = Get-Date
            BuildInfo = Get-CurrentBuildInfo
            SystemStability = Test-SystemStability
            FeatureValidation = Test-InsiderFeatures
            PerformanceCheck = Test-PostUpdatePerformance
            DriverStatus = Get-PostUpdateDriverStatus
            ServiceStatus = Get-PostUpdateServiceStatus
        }

        # Calculate validation score
        $validationMetrics = @(
            $validation.SystemStability.Score,
            $validation.FeatureValidation.Score,
            $validation.PerformanceCheck.Score,
            $validation.DriverStatus.Score,
            $validation.ServiceStatus.Score
        )

        $validation.OverallScore = ($validationMetrics | Measure-Object -Average).Average

        # Save validation report
        $reportPath = "$script:HubPath\reports\post-update-validation_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $validation | ConvertTo-Json -Depth 4 | Out-File -FilePath $reportPath -Encoding UTF8

        Write-Log "SUCCESS" "Post-update validation completed. Score: $([math]::Round($validation.OverallScore, 2))/100"
        return $validation
    }
    catch {
        Write-Log "ERROR" "Post-update validation failed: $($_.Exception.Message)"
        return $null
    }
}

# =====================================================
# SCHEDULED TASK FUNCTIONS
# =====================================================

function Install-ScheduledHealthCheck {
    param(
        [string]$Time = "09:00",
        [switch]$Force
    )

    try {
        $taskName = "DevOptimizer-DailyHealthCheck"

        # Remove existing task if Force is specified
        if ($Force) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }

        # Create scheduled task action
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$script:ScriptsPath\Insider-Automation.ps1`" -Operation dailyhealth -Silent"

        # Create trigger for daily execution
        $trigger = New-ScheduledTaskTrigger -Daily -At $Time

        # Create task settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        # Create principal (run as SYSTEM)
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        # Register the task
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "DevOptimizer Daily Health Check"

        Write-Log "SUCCESS" "Daily health check scheduled for $Time"
        return $true
    }
    catch {
        Write-Log "ERROR" "Failed to install scheduled health check: $($_.Exception.Message)"
        return $false
    }
}

function Install-ScheduledWeeklyScan {
    param(
        [ValidateSet("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")]
        [string]$Day = "Sunday",
        [string]$Time = "02:00",
        [switch]$Force
    )

    try {
        $taskName = "DevOptimizer-WeeklyDeepScan"

        # Remove existing task if Force is specified
        if ($Force) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }

        # Create scheduled task action
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$script:ScriptsPath\Insider-Automation.ps1`" -Operation weeklyscan -Silent"

        # Create trigger for weekly execution
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Day -At $Time

        # Create task settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        # Create principal (run as SYSTEM)
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        # Register the task
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "DevOptimizer Weekly Deep Scan"

        Write-Log "SUCCESS" "Weekly deep scan scheduled for $Day at $Time"
        return $true
    }
    catch {
        Write-Log "ERROR" "Failed to install scheduled weekly scan: $($_.Exception.Message)"
        return $false
    }
}

function Remove-ScheduledTasks {
    try {
        $taskNames = @("DevOptimizer-DailyHealthCheck", "DevOptimizer-WeeklyDeepScan")

        foreach ($taskName in $taskNames) {
            if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-Log "INFO" "Removed scheduled task: $taskName"
            }
        }

        Write-Log "SUCCESS" "All DevOptimizer scheduled tasks removed"
        return $true
    }
    catch {
        Write-Log "ERROR" "Failed to remove scheduled tasks: $($_.Exception.Message)"
        return $false
    }
}

# =====================================================
# HELPER FUNCTIONS
# =====================================================

function Test-InsiderCompatibility {
    try {
        $osVersion = [System.Environment]::OSVersion.Version
        $isWindows10Plus = $osVersion.Major -ge 10

        $hasTPM = Get-WmiObject -Class Win32_Tpm -ErrorAction SilentlyContinue
        $hasSecureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue

        $compatibility = @{
            OSCompatible = $isWindows10Plus
            HasTPM = $hasTPM -ne $null
            SecureBootEnabled = $hasSecureBoot -eq $true
            Timestamp = Get-Date
        }

        Write-Log "INFO" "Compatibility check: OS=$($compatibility.OSCompatible), TPM=$($compatibility.HasTPM), SecureBoot=$($compatibility.SecureBootEnabled)"
        return $compatibility.OSCompatible
    }
    catch {
        Write-Log "ERROR" "Compatibility check failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-WindowsUpdateStatus {
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0")

        $status = @{
            PendingUpdates = $searchResult.Updates.Count
            LastCheckTime = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Detect" -Name LastSuccessTime -ErrorAction SilentlyContinue).LastSuccessTime
            Timestamp = Get-Date
        }

        return $status
    }
    catch {
        Write-Log "ERROR" "Failed to get update status: $($_.Exception.Message)"
        return @{ PendingUpdates = -1; LastCheckTime = $null; Timestamp = Get-Date }
    }
}

function Get-DiskSpaceInfo {
    try {
        $systemDrive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }

        $info = @{
            TotalSpaceGB = [math]::Round($systemDrive.Size / 1GB, 2)
            FreeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
            UsedSpaceGB = [math]::Round(($systemDrive.Size - $systemDrive.FreeSpace) / 1GB, 2)
            FreeSpacePercent = [math]::Round(($systemDrive.FreeSpace / $systemDrive.Size) * 100, 2)
        }

        return $info
    }
    catch {
        Write-Log "ERROR" "Failed to get disk space info: $($_.Exception.Message)"
        return $null
    }
}

function Get-CriticalServicesStatus {
    $criticalServices = @("wuauserv", "cryptSvc", "bits", "msiserver", "Themes", "AudioSrv")
    $serviceStatus = @()

    foreach ($serviceName in $criticalServices) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $serviceStatus += @{
                    Name = $service.Name
                    DisplayName = $service.DisplayName
                    Status = $service.Status.ToString()
                    StartType = $service.StartType.ToString()
                }
            }
        }
        catch {
            Write-Log "WARNING" "Could not get status for service: $serviceName"
        }
    }

    return $serviceStatus
}

function Get-RecentCriticalEvents {
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='System','Application'; Level=1,2; StartTime=(Get-Date).AddDays(-1)} -MaxEvents 50 -ErrorAction SilentlyContinue

        $criticalEvents = $events | ForEach-Object {
            @{
                TimeCreated = $_.TimeCreated
                Id = $_.Id
                LevelDisplayName = $_.LevelDisplayName
                LogName = $_.LogName
                Message = $_.Message.Substring(0, [math]::Min(200, $_.Message.Length))
            }
        }

        return $criticalEvents
    }
    catch {
        Write-Log "ERROR" "Failed to get recent critical events: $($_.Exception.Message)"
        return @()
    }
}

# =====================================================
# MAIN EXECUTION LOGIC
# =====================================================

if ($Operation) {
    switch ($Operation.ToLower()) {
        "autosetup" {
            Invoke-AutoSetupInsider -Options $Parameters
        }
        "dailyhealth" {
            Invoke-DailyHealthCheck -Options $Parameters
        }
        "weeklyscan" {
            Invoke-WeeklyDeepScan -Options $Parameters
        }
        "preupdate" {
            Invoke-PreUpdatePreparation -Options $Parameters
        }
        "postupdate" {
            Invoke-PostUpdateValidation -Options $Parameters
        }
        "scheduledaily" {
            Install-ScheduledHealthCheck @Parameters
        }
        "scheduleweekly" {
            Install-ScheduledWeeklyScan @Parameters
        }
        "removeschedules" {
            Remove-ScheduledTasks
        }
        default {
            Write-Log "ERROR" "Unknown operation: $Operation"
            return $false
        }
    }
}
