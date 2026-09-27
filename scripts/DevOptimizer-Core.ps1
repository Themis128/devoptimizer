# =====================================================
# DEVOPTIMIZER CORE POWERSHELL MODULE v4.0
# Centralized PowerShell functionality for all BAT files
# =====================================================

<#+
.SYNOPSIS
Provides shared logging, configuration, and helper functions for DevOptimizer automation scripts.

.DESCRIPTION
Acts as the central PowerShell module loaded by BAT files and supporting scripts, initializing global context, handling logging, resource detection, notification utilities, and error management.

.PARAMETER Operation
Optional command specifying a core operation to execute on import.

.PARAMETER Parameters
Hashtable of arguments supplied to the requested core operation.

.PARAMETER Silent
Suppresses non-essential logging from the core module.

.PARAMETER DebugMode
Enables verbose debugging information for troubleshooting.

.EXAMPLE
PS> .\DevOptimizer-Core.ps1 -Operation Initialize -Parameters @{ HubPath = "D:\DevOptimizer" }
Initializes the core module using a custom hub path.

.NOTES
Author: DevOptimizer automation tools
#>

[CmdletBinding()]
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

$script:IsDebugMode = $false
if ($PSBoundParameters.ContainsKey('Debug') -or $DebugMode) {
    $script:IsDebugMode = $true
    $DebugPreference = 'Continue'
    Write-Debug "Debug mode enabled for DevOptimizer Core script."
} else {
    $DebugPreference = 'SilentlyContinue'
}

# Global Variables
$script:Version = "4.0.0"
$script:DefaultHubPath = "D:\DevOptimizer"

function Update-HubContext {
    param([string]$HubPath)

    if ([string]::IsNullOrWhiteSpace($HubPath)) {
        $HubPath = $script:DefaultHubPath
    }

    try {
        if (Test-Path $HubPath) {
            $resolvedPath = (Resolve-Path -Path $HubPath -ErrorAction Stop).ProviderPath
        } else {
            $resolvedPath = $HubPath
        }
    } catch {
        $resolvedPath = $HubPath
        if ($script:IsDebugMode) {
            Write-Debug ("Failed to resolve hub path '{0}': {1}" -f $HubPath, $_.Exception.Message)
        }
    }

    $normalizedPath = $resolvedPath.TrimEnd('\\')
    if ([string]::IsNullOrWhiteSpace($normalizedPath)) {
        $normalizedPath = $script:DefaultHubPath
    }

    $script:HubPath = $normalizedPath
    $script:LogPath = Join-Path $script:HubPath "logs"
    $script:ConfigPath = Join-Path $script:HubPath "config"
    $script:BackupPath = Join-Path $script:HubPath "backups"
    $script:ScriptsPath = Join-Path $script:HubPath "scripts"

    if ($script:IsDebugMode) {
        Write-Debug "Hub context updated. HubPath='$($script:HubPath)'"
    }
}

Update-HubContext -HubPath $script:DefaultHubPath

# Ensure UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =====================================================
# CORE FUNCTIONS
# =====================================================

function Initialize-DevOptimizerHub {
    param([switch]$Force)

    Write-Log "INFO" "Initializing DevOptimizer Hub v$script:Version"

    # Create directory structure
    $directories = @(
        $script:LogPath,
        $script:ConfigPath,
        $script:BackupPath,
        $script:ScriptsPath,
        "$script:HubPath\templates",
        "$script:HubPath\tools",
        "$script:HubPath\reports",
        "$script:HubPath\exports"
    )

    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Log "INFO" "Created directory: $dir"
        }
    }

    # Register hub in registry
    Set-HubRegistry

    # Create default configuration
    Initialize-Configuration

    Write-Log "INFO" "DevOptimizer Hub initialized successfully"
    return $true
}

function Set-HubRegistry {
    try {
        $regPath = "HKLM:\SOFTWARE\DevOptimizer"

        # Create registry key if it doesn't exist
        if (!(Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        # Set hub path
        Set-ItemProperty -Path $regPath -Name "HubPath" -Value $script:HubPath
        Set-ItemProperty -Path $regPath -Name "Version" -Value $script:Version
        Set-ItemProperty -Path $regPath -Name "LastUpdate" -Value (Get-Date).ToString()

        # Set environment variable for current session
        [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $script:HubPath, "Process")

        Write-Log "INFO" "Hub registry entries created"
        return $true
    }
    catch {
        Write-Log "ERROR" ("Failed to set registry entries: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Get-HubPath {
    # Try environment variable first
    $envPath = [Environment]::GetEnvironmentVariable("DEVOPTIMIZER_HUB", "Process")
    if ($envPath -and (Test-Path $envPath)) {
        return $envPath
    }

    # Try registry
    try {
        $regPath = "HKLM:\SOFTWARE\DevOptimizer"
        if (Test-Path $regPath) {
            $hubPath = Get-ItemProperty -Path $regPath -Name "HubPath" -ErrorAction SilentlyContinue
            if ($hubPath -and (Test-Path $hubPath.HubPath)) {
                return $hubPath.HubPath
            }
        }
    }
    catch {
        Write-Log "WARNING" ("Could not read registry: {0}" -f $_.Exception.Message)
    }

    # Default fallback
    return "D:\DevOptimizer"
}

function Initialize-Configuration {
    $configFile = "$script:ConfigPath\devoptimizer.json"

    $defaultConfig = @{
        Version = $script:Version
        HubPath = $script:HubPath
        Settings = @{
            LogLevel = "INFO"
            MaxLogFiles = 10
            AutoBackup = $true
            BackupRetention = 30
            SilentMode = $false
            DebugMode = $false
        }
        Modules = @{
            SystemOptimization = $true
            CursorAI = $true
            WindowsInsider = $true
            DevelopmentTools = $true
        }
        LastUpdate = (Get-Date).ToString()
    }

    if (!(Test-Path $configFile)) {
        $defaultConfig | ConvertTo-Json -Depth 3 | Out-File -FilePath $configFile -Encoding UTF8
        Write-Log "INFO" "Default configuration created"
    }
}

function Write-Log {
    param(
        [string]$Level,
        [string]$Message,
        [string]$LogFile = $null
    )

    if (!$LogFile) {
        $LogFile = "$script:LogPath\devoptimizer-core_$(Get-Date -Format 'yyyyMMdd').log"
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - [$Level] $Message"

    # Ensure log directory exists
    $logDir = Split-Path $LogFile -Parent
    if (!(Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Write to log file
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8

    if ($script:IsDebugMode) {
        Write-Debug $logEntry
    }

    # Write to console if not silent
    if (!$Silent) {
        switch ($Level) {
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
            "INFO" { Write-Host $logEntry -ForegroundColor Cyan }
            default { Write-Host $logEntry }
        }
    }
}

# Load auxiliary modules
$cursorModulePath = Join-Path $script:ScriptsPath "Cursor-AI-Module.ps1"
if (Test-Path $cursorModulePath) {
    . $cursorModulePath
    if ($script:IsDebugMode) {
        Write-Debug "Loaded Cursor AI module from '$cursorModulePath'"
    }
} else {
    Write-Log "WARNING" "Cursor-AI-Module.ps1 not found at $cursorModulePath; cursor operations may be limited."
}

# =====================================================
# SYSTEM OPTIMIZATION FUNCTIONS
# =====================================================

function Invoke-QuickOptimization {
    param([hashtable]$Options = @{})

    Write-Log "INFO" "Starting quick system optimization"

    try {
        # Check admin privileges
        if (!(Test-Administrator)) {
            Write-Log "ERROR" "Administrator privileges required"
            return $false
        }

        $skipTasks = @()
        if ($Options.ContainsKey('SkipTasks')) {
            $skipTasks = @($Options.SkipTasks) | ForEach-Object { $_.ToString().ToLowerInvariant() }
        }

        $serviceAction = {
            $invokeParams = @{ Options = $Options }
            if ($Options.ContainsKey('WhatIf')) {
                $invokeParams['WhatIf'] = [bool]$Options.WhatIf
            }
            if ($Options.ContainsKey('Confirm')) {
                $invokeParams['Confirm'] = [bool]$Options.Confirm
            }
            Optimize-SystemServices @invokeParams
        }

        $registryAction = {
            $invokeParams = @{ Options = $Options }
            if ($Options.ContainsKey('WhatIf')) {
                $invokeParams['WhatIf'] = [bool]$Options.WhatIf
            }
            if ($Options.ContainsKey('Confirm')) {
                $invokeParams['Confirm'] = [bool]$Options.Confirm
            }
            Optimize-Registry @invokeParams
        }

        $tasks = @(
            @{ Name = "Power Plan"; Key = "powerplan"; Action = { Set-OptimalPowerPlan } },
            @{ Name = "Temp Files"; Key = "tempfiles"; Action = { Clear-SystemTempFiles } },
            @{ Name = "Services"; Key = "services"; Action = $serviceAction },
            @{ Name = "Registry"; Key = "registry"; Action = $registryAction }
        )

        $activeTasks = $tasks | Where-Object { $skipTasks -notcontains $_.Key }
        if ($activeTasks.Count -eq 0) {
            Write-Log "WARNING" "No optimization tasks selected. Check SkipTasks option."
            return $true
        }

        $completed = 0
        foreach ($task in $activeTasks) {
            Write-Log "INFO" "Executing: $($task.Name)"
            $result = & $task.Action
            $completed++
            $progress = [math]::Round(($completed / $activeTasks.Count) * 100)
            Write-Progress -Activity "Quick Optimization" -Status "$($task.Name)" -PercentComplete $progress

            if (-not $result) {
                Write-Log "WARNING" "Task $($task.Name) reported issues or returned no status."
            }
        }

        Write-Progress -Activity "Quick Optimization" -Completed
        Write-Log "SUCCESS" "Quick optimization completed successfully"
        return $true
    }
    catch {
        Write-Log "ERROR" ("Quick optimization failed: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Set-OptimalPowerPlan {
    try {
        # Set balanced power plan
        $balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
        powercfg.exe /s $balancedGuid
        Write-Log "INFO" "Power plan set to Balanced"
        return $true
    }
    catch {
        Write-Log "ERROR" ("Failed to set power plan: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Clear-SystemTempFiles {
    try {
        $tempPaths = @(
            $env:TEMP,
            "$env:LOCALAPPDATA\Temp",
            "$env:WINDIR\Temp"
        )

        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Log "INFO" "Cleaned temp path: $path"
            }
        }

        return $true
    }
    catch {
        Write-Log "ERROR" ("Failed to clear temp files: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Optimize-SystemServices {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([hashtable]$Options = @{})

    $plan = @()
    if ($Options.ContainsKey('Services') -and $Options.Services) {
        $plan = @($Options.Services)
    }

    if (-not $plan) {
        $plan = @(
            @{ Name = 'DiagTrack'; DesiredStartupType = 'Manual'; EnsureStopped = $true; Description = 'Connected User Experiences and Telemetry service' },
            @{ Name = 'SysMain'; DesiredStartupType = 'Manual'; EnsureStopped = $true; Description = 'SysMain (Superfetch) service' },
            @{ Name = 'WSearch'; DesiredStartupType = 'Manual'; EnsureStopped = $false; Description = 'Windows Search indexing service' }
        )
    }

    $encounteredError = $false

    foreach ($definition in $plan) {
        try {
            $serviceName = $definition.Name
            if ([string]::IsNullOrWhiteSpace($serviceName)) {
                continue
            }

            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Log "WARNING" "Service '$serviceName' not found. Skipping."
                continue
            }

            $serviceDetails = $null
            try {
                $serviceDetails = Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'" -ErrorAction Stop
            } catch {
                if ($script:IsDebugMode) {
                    Write-Debug ("Failed to retrieve CIM details for '{0}': {1}" -f $serviceName, $_.Exception.Message)
                }
            }

            if ($definition.ContainsKey('DesiredStartupType') -and $serviceDetails) {
                $desired = $definition.DesiredStartupType
                $current = $serviceDetails.StartMode
                if (-not [string]::IsNullOrWhiteSpace($desired)) {
                    $requiresChange = [string]::IsNullOrWhiteSpace($current) -or (-not $current.Equals($desired, [System.StringComparison]::InvariantCultureIgnoreCase))
                    if ($requiresChange) {
                        $message = "Set startup type for $serviceName to $desired"
                        if ($PSCmdlet.ShouldProcess($serviceName, $message)) {
                            try {
                                Set-Service -Name $serviceName -StartupType $desired -ErrorAction Stop
                                Write-Log "INFO" $message
                            } catch {
                                $encounteredError = $true
                                Write-Log "ERROR" ("Failed to set startup type for {0}: {1}" -f $serviceName, $_.Exception.Message)
                            }
                        }
                    }
                }
            }

            if ($definition.ContainsKey('EnsureStopped') -and [bool]$definition.EnsureStopped -and $service.Status -ne 'Stopped') {
                if ($PSCmdlet.ShouldProcess($serviceName, 'Stop service')) {
                    try {
                        Stop-Service -Name $serviceName -Force -ErrorAction Stop
                        Write-Log "INFO" "Stopped service: $serviceName"
                    } catch {
                        $encounteredError = $true
                        Write-Log "ERROR" ("Failed to stop {0}: {1}" -f $serviceName, $_.Exception.Message)
                    }
                }
            }

            if ($definition.ContainsKey('EnsureRunning') -and [bool]$definition.EnsureRunning -and $service.Status -ne 'Running') {
                if ($PSCmdlet.ShouldProcess($serviceName, 'Start service')) {
                    try {
                        Start-Service -Name $serviceName -ErrorAction Stop
                        Write-Log "INFO" "Started service: $serviceName"
                    } catch {
                        $encounteredError = $true
                        Write-Log "ERROR" ("Failed to start {0}: {1}" -f $serviceName, $_.Exception.Message)
                    }
                }
            }
        } catch {
            $encounteredError = $true
            Write-Log "ERROR" ("Unexpected issue while processing service definition '{0}': {1}" -f $definition.Name, $_.Exception.Message)
        }
    }

    if ($encounteredError) {
        Write-Log "WARNING" "System services optimization completed with warnings"
        return $false
    }

    Write-Log "SUCCESS" "System services optimization completed"
    return $true
}

function Optimize-Registry {
    [CmdletBinding()]
    param([hashtable]$Options = @{})

    try {
        Write-Log "INFO" "Starting registry optimization tasks"

        $backupEnabled = $true
        if ($Options.ContainsKey('SkipBackup')) {
            $backupEnabled = -not [bool]$Options.SkipBackup
        }

        if ($backupEnabled) {
            $registryBackupDir = Join-Path $script:BackupPath "registry"
            if (-not (Test-Path $registryBackupDir)) {
                New-Item -Path $registryBackupDir -ItemType Directory -Force | Out-Null
            }

            $backupFile = Join-Path $registryBackupDir ("devoptimizer-registry_{0}.reg" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
            if (Test-Path "HKLM:\SOFTWARE\DevOptimizer") {
                & reg.exe export "HKLM\SOFTWARE\DevOptimizer" $backupFile /y | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "INFO" "Registry backup created at $backupFile"
                } else {
                    Write-Log "WARNING" "Failed to export DevOptimizer registry key (exit code $LASTEXITCODE)"
                }
            } else {
                Write-Log "WARNING" "DevOptimizer registry key not found. Backup skipped."
            }
        }

        if (-not (Set-HubRegistry)) {
            Write-Log "ERROR" "Unable to refresh DevOptimizer registry settings"
            return $false
        }

        try {
            [Environment]::SetEnvironmentVariable('DEVOPTIMIZER_HUB', $script:HubPath, 'Process')
            if (Test-Administrator) {
                [Environment]::SetEnvironmentVariable('DEVOPTIMIZER_HUB', $script:HubPath, 'Machine')
            } else {
                [Environment]::SetEnvironmentVariable('DEVOPTIMIZER_HUB', $script:HubPath, 'User')
            }
            Write-Log "INFO" "Environment variable DEVOPTIMIZER_HUB synchronized"
        } catch {
            Write-Log "WARNING" ("Unable to update environment variable: {0}" -f $_.Exception.Message)
        }

        if ($Options.ContainsKey('CleanUserSettings') -and [bool]$Options.CleanUserSettings) {
            $userSettingsPath = "HKCU:\Software\DevOptimizer"
            if (Test-Path $userSettingsPath) {
                Remove-Item -Path $userSettingsPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "INFO" "Removed cached user-specific DevOptimizer settings"
            }
        }

        Write-Log "SUCCESS" "Registry optimization completed"
        return $true
    }
    catch {
        Write-Log "ERROR" ("Registry optimization failed: {0}" -f $_.Exception.Message)
        return $false
    }
}

# =====================================================
# CURSOR AI FUNCTIONS
# =====================================================

function Invoke-CursorOptimization {
    param([hashtable]$Options = @{})

    Write-Log "INFO" "Starting Cursor AI optimization"

    try {
        # Check if Cursor is installed
        $cursorPath = Get-Command "cursor" -ErrorAction SilentlyContinue
        if (!$cursorPath) {
            Write-Log "ERROR" "Cursor AI not found in PATH"
            return $false
        }

        # Backup current settings
        Backup-CursorSettings

        # Apply AI-focused configuration
        Apply-CursorAIConfiguration

        # Install essential extensions
        Install-CursorExtensions

        # Configure keybindings
        Configure-CursorKeybindings

        Write-Log "SUCCESS" "Cursor AI optimization completed"
        return $true
    }
    catch {
        Write-Log "ERROR" ("Cursor optimization failed: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Backup-CursorSettings {
    try {
        $cursorUserPath = "$env:APPDATA\Cursor\User"
        $backupPath = "$script:BackupPath\cursor_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

        if (Test-Path $cursorUserPath) {
            New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
            $excludePatterns = @('state.vscdb', 'state.vscdb.backup')
            Copy-Item -Path "$cursorUserPath\*" -Destination $backupPath -Recurse -Force -Exclude $excludePatterns

            $skippedFiles = @()
            foreach ($pattern in $excludePatterns) {
                $skippedFiles += Get-ChildItem -Path $cursorUserPath -Filter $pattern -Recurse -ErrorAction SilentlyContinue
            }

            $uniqueSkipped = $skippedFiles | Where-Object { $_ } | Select-Object -ExpandProperty FullName -Unique
            foreach ($filePath in $uniqueSkipped) {
                Write-Log "INFO" "Skipped backup of large file: $filePath"
            }
            Write-Log "INFO" "Cursor settings backed up to: $backupPath"
        }

        return $true
    }
    catch {
        Write-Log "ERROR" ("Failed to backup Cursor settings: {0}" -f $_.Exception.Message)
        return $false
    }
}

# =====================================================
# WINDOWS INSIDER FUNCTIONS
# =====================================================

function Get-InsiderStatus {
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection"

        if (Test-Path $regPath) {
            $ring = Get-ItemProperty -Path $regPath -Name "Ring" -ErrorAction SilentlyContinue
            $flighting = Get-ItemProperty -Path $regPath -Name "IsFlightingEnabled" -ErrorAction SilentlyContinue

            $status = @{
                Enrolled = $flighting.IsFlightingEnabled -eq 1
                Channel = switch ($ring.Ring) {
                    2 { "Dev" }
                    4 { "Beta" }
                    8 { "Release Preview" }
                    default { "Unknown" }
                }
            }

            Write-Log "INFO" "Insider Status: Enrolled=$($status.Enrolled), Channel=$($status.Channel)"
            return $status
        }
        else {
            Write-Log "INFO" "Not enrolled in Windows Insider Program"
            return @{ Enrolled = $false; Channel = "None" }
        }
    }
    catch {
        Write-Log "ERROR" ("Failed to get Insider status: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Set-InsiderChannel {
    param(
        [ValidateSet("Dev", "Beta", "ReleasePreview")]
        [string]$Channel
    )

    try {
        if (!(Test-Administrator)) {
            Write-Log "ERROR" "Administrator privileges required"
            return $false
        }

        $regPath = "HKLM:\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection"

        $ringValue = switch ($Channel) {
            "Dev" { 2 }
            "Beta" { 4 }
            "ReleasePreview" { 8 }
        }

        Set-ItemProperty -Path $regPath -Name "Ring" -Value $ringValue
        Set-ItemProperty -Path $regPath -Name "IsFlightingEnabled" -Value 1

        Write-Log "SUCCESS" "Insider channel set to: $Channel"
        return $true
    }
    catch {
        Write-Log "ERROR" ("Failed to set Insider channel: {0}" -f $_.Exception.Message)
        return $false
    }
}

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SystemInfo {
    try {
        $info = @{
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            OSVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption
            OSBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            HubPath = $script:HubPath
            HubVersion = $script:Version
        }

        return $info
    }
    catch {
        Write-Log "ERROR" ("Failed to get system info: {0}" -f $_.Exception.Message)
        return $null
    }
}

# =====================================================
# MAIN EXECUTION LOGIC
# =====================================================

$resolvedHubPath = Get-HubPath
Update-HubContext -HubPath $resolvedHubPath

# Initialize hub if not already done
if (!(Test-Path "$script:HubPath\config\devoptimizer.json")) {
    if (Initialize-DevOptimizerHub) {
        Update-HubContext -HubPath (Get-HubPath)
    }
}

# Process operation parameter
if ($Operation) {
    switch ($Operation.ToLower()) {
        "init" {
            Initialize-DevOptimizerHub -Force:$Parameters.ContainsKey("Force")
        }
        "quickopt" {
            Invoke-QuickOptimization -Options $Parameters
        }
        "cursorai" {
            Invoke-CursorOptimization -Options $Parameters
        }
        "insiderstatus" {
            Get-InsiderStatus
        }
        "setchannel" {
            if ($Parameters.ContainsKey("Channel")) {
                Set-InsiderChannel -Channel $Parameters["Channel"]
            }
        }
        "systeminfo" {
            Get-SystemInfo
        }
        default {
            Write-Log "ERROR" "Unknown operation: $Operation"
            return $false
        }
    }
}

# Export functions when the script is imported as a module
if ($null -ne $MyInvocation.MyCommand.Module) {
    Export-ModuleMember -Function *
}
