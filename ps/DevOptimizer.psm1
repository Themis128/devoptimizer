# DevOptimizer PowerShell Module
# Core automation functions for Windows optimization

using module Microsoft.PowerShell.SecretManagement

# Import required modules
Import-Module Microsoft.PowerShell.SecretManagement -Force
Import-Module Microsoft.PowerShell.SecretStore -Force
Import-Module Microsoft.WinGet.Client -Force

# Module variables
$script:DevOptimizerRoot = "D:\DevOptimizer"
$script:VaultName = 'DevOptimizerVault'

function Initialize-DevOptimizer {
    <#
    .SYNOPSIS
    Initialize DevOptimizer environment and verify prerequisites
    #>
    [CmdletBinding()]
    param()

    Write-Host "Initializing DevOptimizer..." -ForegroundColor Green

    # Verify PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Warning "PowerShell 7+ recommended for best performance. Current version: $($PSVersionTable.PSVersion)"
    }

    # Verify required modules
    $RequiredModules = @('Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore', 'Microsoft.WinGet.Client')
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -Name $Module -ListAvailable)) {
            throw "Required module $Module not found. Run Install-Modules.ps1 first."
        }
    }

    # Verify directories
    $RequiredDirs = @('bin', 'ps', 'py', 'tasks', 'configs', '.env', 'metrics', 'traces', 'logs', 'ai-analysis')
    foreach ($Dir in $RequiredDirs) {
        $DirPath = Join-Path $script:DevOptimizerRoot $Dir
        if (-not (Test-Path $DirPath)) {
            Write-Warning "Directory $DirPath not found. Creating..."
            New-Item -ItemType Directory -Path $DirPath -Force | Out-Null
        }
    }

    # Verify vault
    try {
        $Vaults = Get-SecretVault
        if ($Vaults.Name -notcontains $script:VaultName) {
            Write-Warning "SecretManagement vault '$script:VaultName' not found. Run Install-Modules.ps1 first."
        }
    }
    catch {
        Write-Warning "SecretManagement not configured properly: $_"
    }

    Write-Host "✓ DevOptimizer initialized successfully" -ForegroundColor Green
}

function Start-PerformanceCollection {
    <#
    .SYNOPSIS
    Start performance counter collection using logman
    .PARAMETER Duration
    Duration in seconds (0 = continuous until stopped)
    .PARAMETER Counters
    Custom counter set (default: comprehensive set)
    #>
    [CmdletBinding()]
    param(
        [int]$Duration = 0,
        [string[]]$Counters = @()
    )

    if (-not $Counters) {
        $Counters = @(
            "\\Processor(_Total)\\% Processor Time",
            "\\Memory\\Available MBytes",
            "\\Memory\\Committed Bytes",
            "\\PhysicalDisk(_Total)\\Disk Read Bytes/sec",
            "\\PhysicalDisk(_Total)\\Disk Write Bytes/sec",
            "\\Network Interface(*)\\Bytes Total/sec",
            "\\Process(*)\\Working Set",
            "\\System\\Processor Queue Length"
        )
    }

    $SessionName = "DevOptimizer-Counters"
    $OutputPath = Join-Path $script:DevOptimizerRoot "metrics\counters_$(Get-Date -Format 'yyyyMMdd_HHmmss').blg"

    try {
        # Stop existing session if running
        logman stop $SessionName -ets 2>$null

        # Create and start new session
        $CounterString = $Counters -join " "
        $LogmanArgs = @(
            "create", "counter", $SessionName,
            "-cf", "-",  # Counter file from stdin
            "-f", "bin",
            "-o", $OutputPath
        )

        if ($Duration -gt 0) {
            $LogmanArgs += @("-d", $Duration)
        }

        # Create counter file
        $CounterFile = Join-Path $script:DevOptimizerRoot "metrics\counters.txt"
        $Counters | Out-File -FilePath $CounterFile -Encoding UTF8

        # Start collection
        logman create counter $SessionName -cf $CounterFile -f bin -o $OutputPath -ets

        if ($Duration -gt 0) {
            Write-Host "✓ Performance collection started for $Duration seconds" -ForegroundColor Green
        } else {
            Write-Host "✓ Performance collection started (continuous)" -ForegroundColor Green
        }

        return @{
            SessionName = $SessionName
            OutputPath = $OutputPath
            Status = 'Running'
        }
    }
    catch {
        Write-Error "Failed to start performance collection: $_"
    }
}

function Stop-PerformanceCollection {
    <#
    .SYNOPSIS
    Stop performance counter collection
    #>
    [CmdletBinding()]
    param(
        [string]$SessionName = "DevOptimizer-Counters"
    )

    try {
        logman stop $SessionName -ets
        Write-Host "✓ Performance collection stopped" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to stop performance collection: $_"
    }
}

function Start-ETWTrace {
    <#
    .SYNOPSIS
    Start ETW tracing using WPR
    .PARAMETER Profile
    WPR profile (CPU, DiskIO, Network, etc.)
    .PARAMETER Duration
    Duration in seconds
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('CPU', 'DiskIO', 'Network', 'SystemActivity')]
        [string]$Profile = 'CPU',
        [int]$Duration = 60
    )

    $OutputPath = Join-Path $script:DevOptimizerRoot "traces\trace_$Profile`_$(Get-Date -Format 'yyyyMMdd_HHmmss').etl"

    try {
        # Start trace
        wpr -start $Profile -filemode
        Write-Host "✓ ETW trace started with $Profile profile" -ForegroundColor Green

        if ($Duration -gt 0) {
            Start-Sleep -Seconds $Duration
            Stop-ETWTrace -OutputPath $OutputPath
        }

        return @{
            Profile = $Profile
            OutputPath = $OutputPath
            Status = 'Running'
        }
    }
    catch {
        Write-Error "Failed to start ETW trace: $_"
    }
}

function Stop-ETWTrace {
    <#
    .SYNOPSIS
    Stop ETW tracing and save to file
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath
    )

    if (-not $OutputPath) {
        $OutputPath = Join-Path $script:DevOptimizerRoot "traces\trace_$(Get-Date -Format 'yyyyMMdd_HHmmss').etl"
    }

    try {
        wpr -stop $OutputPath
        Write-Host "✓ ETW trace saved to: $OutputPath" -ForegroundColor Green
        return $OutputPath
    }
    catch {
        Write-Error "Failed to stop ETW trace: $_"
    }
}

function Export-EventLogs {
    <#
    .SYNOPSIS
    Export relevant event logs to files
    #>
    [CmdletBinding()]
    param(
        [string[]]$LogNames = @('System', 'Application', 'Microsoft-Windows-Diagnostics-Performance/Operational'),
        [datetime]$StartTime = (Get-Date).AddDays(-1)
    )

    $OutputDir = Join-Path $script:DevOptimizerRoot "logs\eventlogs"
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    foreach ($LogName in $LogNames) {
        try {
            $OutputFile = Join-Path $OutputDir "$LogName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').evtx"

            # Export log
            wevtutil epl $LogName $OutputFile "/q:*[System[TimeCreated[@SystemTime>='$($StartTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))']]]"

            Write-Host "✓ Exported $LogName to: $OutputFile" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to export $LogName`: $_"
        }
    }
}

function Install-DevTools {
    <#
    .SYNOPSIS
    Install development tools using winget
    .PARAMETER PackageFile
    Path to JSON file containing package list
    #>
    [CmdletBinding()]
    param(
        [string]$PackageFile = (Join-Path $script:DevOptimizerRoot "configs\winget-packages.json")
    )

    if (-not (Test-Path $PackageFile)) {
        Write-Warning "Package file not found: $PackageFile"
        return
    }

    try {
        $Packages = Get-Content $PackageFile | ConvertFrom-Json

        foreach ($Package in $Packages.packages) {
            try {
                Write-Host "Installing $($Package.name)..." -ForegroundColor Yellow
                Install-WinGetPackage -Id $Package.id -Scope Machine -AcceptSourceAgreements -AcceptPackageAgreements
                Write-Host "✓ Installed $($Package.name)" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to install $($Package.name): $_"
            }
        }
    }
    catch {
        Write-Error "Failed to process package file: $_"
    }
}

function Get-SystemMetrics {
    <#
    .SYNOPSIS
    Get current system metrics snapshot
    #>
    [CmdletBinding()]
    param()

    try {
        $Metrics = @{
            Timestamp = Get-Date
            CPU = @{
                Usage = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
                Processes = (Get-Process).Count
            }
            Memory = @{
                TotalGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
                AvailableGB = [math]::Round((Get-Counter '\Memory\Available MBytes' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue / 1024, 2)
                CommittedGB = [math]::Round((Get-Counter '\Memory\Committed Bytes' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue / 1GB, 2)
            }
            Disk = @{
                ReadBytesPerSec = (Get-Counter '\PhysicalDisk(_Total)\Disk Read Bytes/sec' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
                WriteBytesPerSec = (Get-Counter '\PhysicalDisk(_Total)\Disk Write Bytes/sec' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
            }
            Network = @{}
        }

        # Get network interface metrics
        $NetworkCounters = Get-Counter '\Network Interface(*)\Bytes Total/sec' -SampleInterval 1 -MaxSamples 1
        foreach ($Counter in $NetworkCounters.CounterSamples) {
            if ($Counter.CookedValue -gt 0) {
                $InterfaceName = ($Counter.Path -split '\\')[3] -replace '[{}]', ''
                $Metrics.Network[$InterfaceName] = $Counter.CookedValue
            }
        }

        return $Metrics
    }
    catch {
        Write-Error "Failed to get system metrics: $_"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-DevOptimizer',
    'Start-PerformanceCollection',
    'Stop-PerformanceCollection',
    'Start-ETWTrace',
    'Stop-ETWTrace',
    'Export-EventLogs',
    'Install-DevTools',
    'Get-SystemMetrics'
)
