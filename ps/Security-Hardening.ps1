# DevOptimizer Security Hardening Script
# Run with: pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Security-Hardening.ps1"

param(
    [string]$SysinternalsDir = "D:\DevOptimizer\bin\sysinternals",
    [string]$OutputDir = "D:\DevOptimizer\security",
    [switch]$DownloadSysinternals = $true,
    [switch]$RunSecurityAudit = $true,
    [switch]$ApplyHardening = $false,
    [switch]$ScanMalware = $false,
    [switch]$ConfigureDefender = $true,
    [switch]$SetFirewallRules = $true,
    [switch]$DisableUnnecessaryServices = $true
)

$ErrorActionPreference = 'Stop'

Write-Host "Starting DevOptimizer Security Hardening..." -ForegroundColor Green
Write-Host "Sysinternals Directory: $SysinternalsDir" -ForegroundColor Yellow
Write-Host "Output Directory: $OutputDir" -ForegroundColor Yellow

try {
    # Create output directory
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Download Sysinternals Suite
    if ($DownloadSysinternals) {
        Write-Host "`nDownloading Sysinternals Suite..." -ForegroundColor Blue

        if (-not (Test-Path $SysinternalsDir)) {
            New-Item -ItemType Directory -Path $SysinternalsDir -Force | Out-Null
        }

        # List of Sysinternals tools to download
        $SysinternalsTools = @(
            "Autoruns",
            "ProcessExplorer",
            "ProcessMonitor",
            "SigCheck",
            "Handle",
            "TcpView",
            "ProcDump",
            "VMMap",
            "RAMMap",
            "DiskMon",
            "FileMon",
            "RegMon"
        )

        $DownloadResults = @{
            timestamp = Get-Date
            tools_downloaded = @()
            errors = @()
        }

        foreach ($Tool in $SysinternalsTools) {
            try {
                $ToolUrl = "https://download.sysinternals.com/files/$Tool.zip"
                $ZipFile = Join-Path $SysinternalsDir "$Tool.zip"

                Write-Host "Downloading $Tool..." -ForegroundColor Yellow

                # Download using Invoke-WebRequest
                Invoke-WebRequest -Uri $ToolUrl -OutFile $ZipFile -UseBasicParsing

                if (Test-Path $ZipFile) {
                    # Extract ZIP file
                    $ExtractPath = Join-Path $SysinternalsDir $Tool
                    if (-not (Test-Path $ExtractPath)) {
                        New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
                    }

                    # Extract using .NET
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $ExtractPath)

                    # Remove ZIP file
                    Remove-Item $ZipFile -Force

                    $DownloadResults.tools_downloaded += @{
                        name = $Tool
                        path = $ExtractPath
                        status = "success"
                    }

                    Write-Host "✓ Downloaded and extracted $Tool" -ForegroundColor Green
                } else {
                    throw "Download failed"
                }

            } catch {
                $DownloadResults.errors += @{
                    tool = $Tool
                    error = $_.Exception.Message
                }
                Write-Warning "Failed to download $Tool`: $($_.Exception.Message)"
            }
        }

        # Save download results
        $DownloadResultsFile = Join-Path $OutputDir "sysinternals_download_results.json"
        $DownloadResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $DownloadResultsFile -Encoding UTF8
        Write-Host "✓ Download results saved to: $DownloadResultsFile" -ForegroundColor Green
    }

    # Security Audit
    if ($RunSecurityAudit) {
        Write-Host "`nRunning security audit..." -ForegroundColor Blue

        $AuditResults = @{
            timestamp = Get-Date
            system_info = @{}
            processes = @()
            services = @()
            startup_programs = @()
            defender_status = @{}
            network_connections = @()
            file_permissions = @()
            recommendations = @()
            errors = @()
        }

        # System Information
        try {
            $AuditResults.system_info = @{
                hostname = $env:COMPUTERNAME
                domain = $env:USERDOMAIN
                username = $env:USERNAME
                os_version = (Get-WmiObject Win32_OperatingSystem).Caption
                architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
                install_date = (Get-WmiObject Win32_OperatingSystem).InstallDate
                last_boot = (Get-WmiObject Win32_OperatingSystem).LastBootUpTime
                total_memory = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
                cpu_info = (Get-WmiObject Win32_Processor).Name
            }
        } catch {
            $AuditResults.errors += @{
                action = "system_info"
                error = $_.Exception.Message
            }
        }

        # Process Analysis
        try {
            $Processes = Get-Process | Select-Object Id, Name, Path, CPU, WorkingSet, StartTime | Sort-Object CPU -Descending | Select-Object -First 50

            foreach ($Process in $Processes) {
                $AuditResults.processes += @{
                    id = $Process.Id
                    name = $Process.Name
                    path = $Process.Path
                    cpu = $Process.CPU
                    memory_mb = [math]::Round($Process.WorkingSet / 1MB, 2)
                    start_time = $Process.StartTime
                }
            }
        } catch {
            $AuditResults.errors += @{
                action = "process_analysis"
                error = $_.Exception.Message
            }
        }

        # Service Analysis
        try {
            $Services = Get-Service | Select-Object Name, Status, StartType, DisplayName | Sort-Object Name

            foreach ($Service in $Services) {
                if ($Service.StartType -eq "Automatic" -and $Service.Status -eq "Running") {
                    $AuditResults.services += @{
                        name = $Service.Name
                        display_name = $Service.DisplayName
                        status = $Service.Status.ToString()
                        start_type = $Service.StartType.ToString()
                    }
                }
            }
        } catch {
            $AuditResults.errors += @{
                action = "service_analysis"
                error = $_.Exception.Message
            }
        }

        # Startup Program Analysis
        try {
            $StartupPrograms = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User

            foreach ($Program in $StartupPrograms) {
                $AuditResults.startup_programs += @{
                    name = $Program.Name
                    command = $Program.Command
                    location = $Program.Location
                    user = $Program.User
                }
            }
        } catch {
            $AuditResults.errors += @{
                action = "startup_analysis"
                error = $_.Exception.Message
            }
        }

        # Windows Defender Status
        try {
            $DefenderStatus = Get-MpComputerStatus
            $AuditResults.defender_status = @{
                real_time_protection = $DefenderStatus.RealTimeProtectionEnabled
                cloud_protection = $DefenderStatus.CloudProtectionEnabled
                antivirus_enabled = $DefenderStatus.AntivirusEnabled
                firewall_enabled = $DefenderStatus.FirewallEnabled
                last_scan = $DefenderStatus.QuickScanStartTime
                definition_version = $DefenderStatus.AntivirusSignatureVersion
            }
        } catch {
            $AuditResults.errors += @{
                action = "defender_status"
                error = $_.Exception.Message
            }
        }

        # Network Connections
        try {
            $NetworkConnections = Get-NetTCPConnection | Where-Object {$_.State -eq "Established"} | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess | Sort-Object LocalPort

            foreach ($Connection in $NetworkConnections) {
                $AuditResults.network_connections += @{
                    local_address = $Connection.LocalAddress
                    local_port = $Connection.LocalPort
                    remote_address = $Connection.RemoteAddress
                    remote_port = $Connection.RemotePort
                    process_id = $Connection.OwningProcess
                }
            }
        } catch {
            $AuditResults.errors += @{
                action = "network_analysis"
                error = $_.Exception.Message
            }
        }

        # Generate Security Recommendations
        $Recommendations = @()

        # Check for suspicious processes
        $SuspiciousProcesses = $AuditResults.processes | Where-Object {
            $_.name -match "(miner|crypto|bitcoin|coin)" -or
            $_.path -like "*temp*" -or
            $_.path -like "*appdata*"
        }

        if ($SuspiciousProcesses) {
            $Recommendations += @{
                category = "Processes"
                severity = "High"
                issue = "Suspicious processes detected"
                details = $SuspiciousProcesses
                action = "Investigate and remove if malicious"
            }
        }

        # Check for unnecessary services
        $UnnecessaryServices = $AuditResults.services | Where-Object {
            $_.name -match "(fax|xbox|tablet|game)" -or
            $_.display_name -match "(Fax|Xbox|Tablet|Game)"
        }

        if ($UnnecessaryServices) {
            $Recommendations += @{
                category = "Services"
                severity = "Medium"
                issue = "Unnecessary services running"
                details = $UnnecessaryServices
                action = "Consider disabling unused services"
            }
        }

        # Check startup programs
        if ($AuditResults.startup_programs.Count -gt 10) {
            $Recommendations += @{
                category = "Startup"
                severity = "Medium"
                issue = "Too many startup programs"
                details = "$($AuditResults.startup_programs.Count) startup programs found"
                action = "Review and disable unnecessary startup programs"
            }
        }

        # Check Windows Defender
        if (-not $AuditResults.defender_status.real_time_protection) {
            $Recommendations += @{
                category = "Defender"
                severity = "High"
                issue = "Real-time protection disabled"
                details = "Windows Defender real-time protection is not enabled"
                action = "Enable real-time protection in Windows Defender"
            }
        }

        $AuditResults.recommendations = $Recommendations

        # Save audit results
        $AuditResultsFile = Join-Path $OutputDir "security_audit_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $AuditResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $AuditResultsFile -Encoding UTF8
        Write-Host "✓ Security audit saved to: $AuditResultsFile" -ForegroundColor Green

        # Display audit summary
        Write-Host "`nSecurity Audit Summary:" -ForegroundColor Blue
        Write-Host "Processes analyzed: $($AuditResults.processes.Count)" -ForegroundColor White
        Write-Host "Services analyzed: $($AuditResults.services.Count)" -ForegroundColor White
        Write-Host "Startup programs: $($AuditResults.startup_programs.Count)" -ForegroundColor White
        Write-Host "Network connections: $($AuditResults.network_connections.Count)" -ForegroundColor White
        Write-Host "Recommendations: $($AuditResults.recommendations.Count)" -ForegroundColor White

        # Show high priority recommendations
        $HighPriority = $AuditResults.recommendations | Where-Object {$_.severity -eq "High"}
        if ($HighPriority) {
            Write-Host "`nHigh Priority Issues:" -ForegroundColor Red
            foreach ($Rec in $HighPriority) {
                Write-Host "- $($Rec.issue)" -ForegroundColor Red
            }
        }
    }

    # Apply Security Hardening
    if ($ApplyHardening) {
        Write-Host "`nApplying security hardening..." -ForegroundColor Blue

        $HardeningResults = @{
            timestamp = Get-Date
            actions = @()
            errors = @()
        }

        # Disable unnecessary services
        if ($DisableUnnecessaryServices) {
            Write-Host "Disabling unnecessary services..." -ForegroundColor Yellow

            $ServicesToDisable = @(
                "Fax",
                "TabletInputService",
                "XblAuthManager",
                "XblGameSave",
                "XboxNetApiSvc",
                "XboxGipSvc",
                "XboxLiveAuthManager"
            )

            foreach ($Service in $ServicesToDisable) {
                try {
                    $ServiceObj = Get-Service -Name $Service -ErrorAction SilentlyContinue
                    if ($ServiceObj -and $ServiceObj.Status -eq "Running") {
                        Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
                        Set-Service -Name $Service -StartupType Disabled -ErrorAction SilentlyContinue

                        $HardeningResults.actions += @{
                            action = "disable_service"
                            service = $Service
                            status = "success"
                        }

                        Write-Host "✓ Disabled service: $Service" -ForegroundColor Green
                    }
                } catch {
                    $HardeningResults.errors += @{
                        action = "disable_service"
                        service = $Service
                        error = $_.Exception.Message
                    }
                }
            }
        }

        # Configure Windows Defender
        if ($ConfigureDefender) {
            Write-Host "Configuring Windows Defender..." -ForegroundColor Yellow

            $DefenderCommands = @(
                "Set-MpPreference -DisableRealtimeMonitoring `$false",
                "Set-MpPreference -EnableCloudProtection `$true",
                "Set-MpPreference -ScanScheduleDay 1",
                "Set-MpPreference -DisableBehaviorMonitoring `$false",
                "Set-MpPreference -DisableIntrusionPreventionSystem `$false"
            )

            foreach ($Cmd in $DefenderCommands) {
                try {
                    Invoke-Expression $Cmd

                    $HardeningResults.actions += @{
                        action = "defender_config"
                        command = $Cmd
                        status = "success"
                    }

                } catch {
                    $HardeningResults.errors += @{
                        action = "defender_config"
                        command = $Cmd
                        error = $_.Exception.Message
                    }
                }
            }

            Write-Host "✓ Windows Defender configured" -ForegroundColor Green
        }

        # Configure firewall
        if ($SetFirewallRules) {
            Write-Host "Configuring firewall..." -ForegroundColor Yellow

            $FirewallCommands = @(
                "netsh advfirewall set allprofiles state on",
                "netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound",
                "netsh advfirewall set allprofiles logging filename %systemroot%\system32\logfiles\firewall\pfirewall.log",
                "netsh advfirewall set allprofiles logging maxfilesize 4096",
                "netsh advfirewall set allprofiles logging droppedconnections enable"
            )

            foreach ($Cmd in $FirewallCommands) {
                try {
                    Invoke-Expression $Cmd

                    $HardeningResults.actions += @{
                        action = "firewall_config"
                        command = $Cmd
                        status = "success"
                    }

                } catch {
                    $HardeningResults.errors += @{
                        action = "firewall_config"
                        command = $Cmd
                        error = $_.Exception.Message
                    }
                }
            }

            Write-Host "✓ Firewall configured" -ForegroundColor Green
        }

        # Save hardening results
        $HardeningResultsFile = Join-Path $OutputDir "hardening_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $HardeningResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $HardeningResultsFile -Encoding UTF8
        Write-Host "✓ Hardening results saved to: $HardeningResultsFile" -ForegroundColor Green
    }

    # Malware Scan
    if ($ScanMalware) {
        Write-Host "`nRunning malware scan..." -ForegroundColor Blue

        $ScanResults = @{
            timestamp = Get-Date
            scan_type = "quick"
            threats_found = @()
            scan_summary = @{}
            errors = @()
        }

        try {
            # Run quick scan
            $ScanOutput = & "MpCmdRun.exe" -Scan -ScanType 1

            $ScanResults.scan_summary.raw_output = $ScanOutput

            # Parse scan results
            if ($ScanOutput -match "Threats found: (\d+)") {
                $ScanResults.scan_summary.threats_found = [int]$matches[1]
            }

            if ($ScanResults.scan_summary.threats_found -gt 0) {
                # Get detailed threat information
                try {
                    $ThreatOutput = & "MpCmdRun.exe" -GetFiles
                    $ScanResults.threats_found = $ThreatOutput -split "`n"
                } catch {
                    $ScanResults.errors += @{
                        action = "get_threats"
                        error = $_.Exception.Message
                    }
                }
            }

            Write-Host "✓ Malware scan completed" -ForegroundColor Green

        } catch {
            $ScanResults.errors += @{
                action = "malware_scan"
                error = $_.Exception.Message
            }
            Write-Warning "Malware scan failed: $($_.Exception.Message)"
        }

        # Save scan results
        $ScanResultsFile = Join-Path $OutputDir "malware_scan_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $ScanResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $ScanResultsFile -Encoding UTF8
        Write-Host "✓ Scan results saved to: $ScanResultsFile" -ForegroundColor Green
    }

    # Generate final summary
    Write-Host "`nGenerating security summary..." -ForegroundColor Blue
    $Summary = @{
        timestamp = Get-Date
        sysinternals_downloaded = $DownloadSysinternals
        security_audit_completed = $RunSecurityAudit
        hardening_applied = $ApplyHardening
        malware_scan_completed = $ScanMalware
        output_directory = $OutputDir
        status = "Completed"
    }

    $SummaryFile = Join-Path $OutputDir "security_summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $Summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $SummaryFile -Encoding UTF8
    Write-Host "✓ Security summary saved to: $SummaryFile" -ForegroundColor Green

    # Display final summary
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "SECURITY HARDENING COMPLETED" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green
    Write-Host "Sysinternals Downloaded: $DownloadSysinternals" -ForegroundColor White
    Write-Host "Security Audit: $RunSecurityAudit" -ForegroundColor White
    Write-Host "Hardening Applied: $ApplyHardening" -ForegroundColor White
    Write-Host "Malware Scan: $ScanMalware" -ForegroundColor White
    Write-Host "Output Directory: $OutputDir" -ForegroundColor White
    Write-Host "Summary: $SummaryFile" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Green

} catch {
    Write-Error "Security hardening failed: $_"
    exit 1
}
