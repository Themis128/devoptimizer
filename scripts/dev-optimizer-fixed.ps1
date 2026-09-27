# UTF-8 with BOM encoding for proper character display
#Requires -RunAsAdministrator

<#+
.SYNOPSIS
Runs DevOptimizer end-to-end optimization workflows with selectable modes.

.DESCRIPTION
Applies curated system tweaks, development environment configuration, cleanup operations, and optional deep maintenance depending on the chosen mode. Supports forceful execution, verbose logging, and workspace targeting.

.PARAMETER Mode
Specifies which optimization preset to execute (for example Menu, Full, CursorOnly, DeepClean). Defaults to Menu.

.PARAMETER Force
Bypasses confirmation prompts when executing potentially disruptive changes.

.PARAMETER Help
Displays usage guidance and exits.

.PARAMETER Verbose
Enables verbose diagnostic output throughout the run.

.PARAMETER WorkspacePath
Overrides the default workspace root used for development tooling tasks.

.PARAMETER NoPause
Skips pause prompts at the end of operations, useful for automation.

.EXAMPLE
PS> .\dev-optimizer-fixed.ps1 -Mode Full -Force -Verbose
Runs the full optimization routine with elevated logging and without prompting for confirmation.

.EXAMPLE
PS> .\dev-optimizer-fixed.ps1 -Mode CursorAI -WorkspacePath D:\Projects
Optimizes Cursor AI features for the specified workspace.

.NOTES
Author: DevOptimizer automation tools
#>

param(
    [ValidateSet("Menu", "Basic", "Full", "Custom", "CursorOnly", "Clean", "Smart", "Docker", "DeepClean", "Network", "CursorAI", "VSCode", "GPU")]
    [string]$Mode = "Menu",
    [switch]$Force,
    [switch]$Help,
    [switch]$Verbose,
    [string]$WorkspacePath,
    [switch]$NoPause
)

# Global configuration
$script:Config = @{
    Version = "3.1-Fixed"
    Paths = @{
        DevRoot = "$env:USERPROFILE\Dev"
        LogFile = "$env:TEMP\dev-optimizer-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        BackupPath = "$env:USERPROFILE\DevOptimizerBackup"
        CursorConfig = "$env:APPDATA\Cursor\User"
        CursorExtensions = "$env:USERPROFILE\.cursor\extensions"
    }
    Performance = @{
        MaxMemoryUsage = [math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB)
        CPUCores = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
        IsNVMe = $false # Will be determined at runtime
        HasDedicatedGPU = $false # Will be determined at runtime
    }
    Features = @{
        EnableTelemetryOptimization = $true
        EnableGameMode = $true
        EnableUltimatePerformance = $true
        EnableMemoryCompression = $true
        EnablePrefetch = $true
        EnableSuperfetch = $true
    }
}

# Enhanced logging with levels
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $script:Config.Paths.LogFile -Value $logMessage -ErrorAction SilentlyContinue
    
    # Console output with colors
    if (!$NoConsole) {
        $color = switch ($Level) {
            "INFO" { "White" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            "SUCCESS" { "Green" }
            "DEBUG" { "Cyan" }
        }
        Write-Host $logMessage -ForegroundColor $color
    }
}

# FIXED: Safe registry value setting
function Set-RegistryValueSafe {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$PropertyType = "DWord"
    )
    
    try {
        # Check if we have admin rights
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Log "Skipping registry setting $Path\$Name - requires admin privileges" -Level "WARN"
            return $false
        }
        
        # Ensure the registry path exists
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        
        # Try to set the value with error handling
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $PropertyType -Force -ErrorAction Stop
        Write-Log "Set $Path\$Name = $Value" -Level "DEBUG"
        return $true
    }
    catch [System.UnauthorizedAccessException] {
        Write-Log "Access denied setting $Path\$Name - may require ownership change" -Level "WARN"
        return $false
    }
    catch [System.Security.SecurityException] {
        Write-Log "Security exception setting $Path\$Name - insufficient privileges" -Level "WARN"
        return $false
    }
    catch {
        Write-Log "Failed to set registry value $Path\$Name : $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# FIXED: Improved winget package installation
function Install-PackageWithWinget {
    param(
        [string]$PackageName,
        [string]$WingetId,
        [switch]$AllowUpgrade
    )
    
    Write-Log "Installing/checking $PackageName via winget..." -Level "INFO"
    
    try {
        # First check if package is already installed
        $listResult = winget list --id $WingetId --exact 2>&1
        $isInstalled = $LASTEXITCODE -eq 0 -and ($listResult -match $WingetId)
        
        if ($isInstalled) {
            Write-Log "$PackageName is already installed" -Level "INFO"
            
            if ($AllowUpgrade) {
                # Try to upgrade if available
                $upgradeResult = winget upgrade --id $WingetId --silent --accept-package-agreements --accept-source-agreements 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Successfully upgraded: $PackageName" -Level "SUCCESS"
                    return $true
                } elseif ($upgradeResult -match "No available upgrade found" -or $upgradeResult -match "No newer package versions are available") {
                    Write-Log "$PackageName is already up to date" -Level "SUCCESS"
                    return $true
                } else {
                    Write-Log "Upgrade failed for $PackageName, but package is installed" -Level "WARN"
                    return $true  # Still consider this a success since package exists
                }
            } else {
                return $true  # Package exists, no upgrade requested
            }
        } else {
            # Package not installed, try to install
            $installResult = winget install --id $WingetId --silent --accept-package-agreements --accept-source-agreements 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully installed: $PackageName" -Level "SUCCESS"
                return $true
            } else {
                Write-Log "Failed to install $PackageName : $installResult" -Level "ERROR"
                return $false
            }
        }
    }
    catch {
        Write-Log "Error with winget operation for $PackageName : $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Reload environment variables for the current session
function RefreshEnv {
    try {
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ($machinePath -and $userPath) {
            $env:Path = "$machinePath;$userPath"
        } elseif ($machinePath) {
            $env:Path = $machinePath
        } elseif ($userPath) {
            $env:Path = $userPath
        }

        foreach ($scope in "Machine", "User") {
            $regRoot = if ($scope -eq "Machine") { "HKLM" } else { "HKCU" }
            $envKeyPath = "Registry::$regRoot\\System\\CurrentControlSet\\Control\\Session Manager\\Environment"
            if (Test-Path $envKeyPath) {
                Get-Item $envKeyPath | Get-ItemProperty | ForEach-Object {
                    $_.PSObject.Properties | Where-Object { $_.Name -notin 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider' } | ForEach-Object {
                        $name = $_.Name
                        $value = [string]([System.Environment]::GetEnvironmentVariable($name, $scope))
                        if ($null -ne $value) { Set-Item -Path Env:$name -Value $value -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
        Write-Log "Environment variables refreshed for current session" -Level "DEBUG"
    }
    catch {
        Write-Log "Failed to refresh environment variables: $($_.Exception.Message)" -Level "WARN"
    }
}

# System information gathering
function Get-EnhancedSystemInfo {
    Write-Log "Gathering enhanced system information..." -Level "INFO"
    
    $system = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" -and $_.Name -notlike "*Microsoft*" }
    $storage = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    # Memory info used for system info calculation
    # $memoryInfo = Get-CimInstance Win32_PhysicalMemory  # Commented out as not currently used
    
    # Detect NVMe drives
    $nvmeDetected = Get-PhysicalDisk | Where-Object { $_.BusType -eq "NVMe" }
    $script:Config.Performance.IsNVMe = $nvmeDetected.Count -gt 0
    
    # Detect dedicated GPU
    $script:Config.Performance.HasDedicatedGPU = $gpu.Count -gt 0 -and $gpu[0].AdapterRAM -gt 1GB
    
    $sysInfo = @{
        Computer = $system.Name
        OS = "$($os.Caption) ($($os.Version))"
        CPU = "$($cpu.Name) - $($cpu.NumberOfLogicalProcessors) cores"
        RAM = "$([math]::Round($system.TotalPhysicalMemory / 1GB, 2)) GB"
        GPU = if ($gpu) { $gpu[0].Name } else { "Integrated Graphics" }
        Storage = ($storage | ForEach-Object { "$($_.DeviceID) $([math]::Round($_.Size / 1GB, 2)) GB" }) -join ", "
        NVMe = $script:Config.Performance.IsNVMe
        DedicatedGPU = $script:Config.Performance.HasDedicatedGPU
    }
    
    Write-Log "System Info: $($sysInfo | ConvertTo-Json -Compress)" -Level "DEBUG"
    return $sysInfo
}

# FIXED: Advanced Windows optimization with safe registry handling
function Optimize-WindowsAdvanced {
    param(
        [ValidateSet("Conservative", "Balanced", "Aggressive", "Ultra")]
        [string]$Level = "Balanced"
    )
    
    Write-Log "Applying advanced Windows optimization (Level: $Level)..." -Level "INFO"
    
    try {
        # Create system restore point
        if ($Level -in @("Aggressive", "Ultra")) {
            Write-Log "Creating system restore point..." -Level "INFO"
            Checkpoint-Computer -Description "DevOptimizer-v3.1-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -RestorePointType "MODIFY_SETTINGS"
        }
        
        # Registry optimizations based on level using safe method
        $registryOptimizations = @{
            Conservative = @{
                "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" = @{ "Win32PrioritySeparation" = 38 }
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" = @{ "SystemResponsiveness" = 10 }
            }
            Balanced = @{
                "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" = @{ "Win32PrioritySeparation" = 38 }
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" = @{ "SystemResponsiveness" = 5 }
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" = @{
                    "ClearPageFileAtShutdown" = 0
                    "DisablePagingExecutive" = 1
                    "LargeSystemCache" = if ($script:Config.Performance.MaxMemoryUsage -ge 16) { 1 } else { 0 }
                }
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" = @{ "StartupDelayInMSec" = 0 }
            }
            Aggressive = @{
                "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" = @{ "Win32PrioritySeparation" = 24 }
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" = @{ "SystemResponsiveness" = 1 }
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" = @{
                    "ClearPageFileAtShutdown" = 0
                    "DisablePagingExecutive" = 1
                    "LargeSystemCache" = 1
                    "SecondLevelDataCache" = 1024
                    "ThirdLevelDataCache" = 8192
                }
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" = @{ "StartupDelayInMSec" = 0 }
            }
            Ultra = @{
                "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" = @{ "Win32PrioritySeparation" = 24 }
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" = @{ "SystemResponsiveness" = 0 }
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" = @{
                    "ClearPageFileAtShutdown" = 0
                    "DisablePagingExecutive" = 1
                    "LargeSystemCache" = 1
                    "SecondLevelDataCache" = 1024
                    "ThirdLevelDataCache" = 12288
                    "PoolUsageMaximum" = 60
                }
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" = @{ "StartupDelayInMSec" = 0 }
            }
        }
        
        # Apply registry changes using safe method
        foreach ($regPath in $registryOptimizations[$Level].Keys) {
            foreach ($valueName in $registryOptimizations[$Level][$regPath].Keys) {
                $value = $registryOptimizations[$Level][$regPath][$valueName]
                Set-RegistryValueSafe -Path $regPath -Name $valueName -Value $value
            }
        }
        
        # Enable Ultimate Performance power plan if available
        if ($Level -in @("Aggressive", "Ultra")) {
            Write-Log "Enabling Ultimate Performance power plan..." -Level "INFO"
            $ultimatePlan = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
            if ($ultimatePlan -match "([0-9a-f-]{36})") {
                $planGuid = $matches[1]
                powercfg /setactive $planGuid
                Write-Log "Ultimate Performance plan activated: $planGuid" -Level "SUCCESS"
            }
        }
        
        # Network optimizations
        Write-Log "Applying network optimizations..." -Level "INFO"
        $netshCommands = @(
            'netsh int tcp set global rss=enabled',
            'netsh int tcp set global autotuninglevel=normal',
            'netsh int tcp set global ecncapability=enabled'
        )
        foreach ($cmd in $netshCommands) {
            try { Invoke-Expression "$cmd > `$null 2>&1" } catch { Write-Log "Network setting failed for: $cmd" -Level "DEBUG" }
        }
        
        # Storage optimizations for NVMe
        if ($script:Config.Performance.IsNVMe) {
            Write-Log "Applying NVMe-specific optimizations..." -Level "INFO"
            try { fsutil behavior set DisableDeleteNotify 0 | Out-Null } catch {}
            try { fsutil behavior set EncryptPagingFile 0 | Out-Null } catch {}
        }

        # FIXED: Safe Windows Search disable
        if ($Level -eq 'Ultra') {
            try {
                $searchService = Get-Service "WSearch" -ErrorAction SilentlyContinue
                if ($searchService -and $searchService.Status -eq "Running") {
                    Stop-Service "WSearch" -Force -ErrorAction SilentlyContinue
                    Set-Service "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Log "Windows Search service disabled" -Level "SUCCESS"
                }
            } catch { Write-Log "Could not disable Windows Search: $($_.Exception.Message)" -Level "WARN" }
        }
        
        Write-Log "Advanced Windows optimization completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error in Windows optimization: $($_.Exception.Message)" -Level "ERROR"
    }
}

# FIXED: Enhanced development tools installation
function Install-DevelopmentToolsAdvanced {
    param(
        [string[]]$Categories = @("Essential"),
        [switch]$UseWinget,
        [switch]$UseChocolatey
    )
    
    Write-Log "Installing development tools (Categories: $($Categories -join ', '))..." -Level "INFO"
    
    $toolCategories = @{
        Essential = @(
            @{ Name = "Git"; WingetId = "Git.Git"; ChocoId = "git" },
            @{ Name = "Node.js"; WingetId = "OpenJS.NodeJS"; ChocoId = "nodejs" },
            @{ Name = "Visual Studio Code"; WingetId = "Microsoft.VisualStudioCode"; ChocoId = "vscode" },
            @{ Name = "Windows Terminal"; WingetId = "Microsoft.WindowsTerminal"; ChocoId = "microsoft-windows-terminal" }
        )
        NodeJS = @(
            @{ Name = "pnpm"; Command = "npm install -g pnpm" },
            @{ Name = "Yarn"; WingetId = "Yarn.Yarn"; ChocoId = "yarn" }
        )
        Utilities = @(
            @{ Name = "7-Zip"; WingetId = "7zip.7zip"; ChocoId = "7zip" },
            @{ Name = "PowerToys"; WingetId = "Microsoft.PowerToys"; ChocoId = "powertoys" }
        )
    }
    
    # Determine package manager
    $packageManager = "None"
    if ($UseWinget -or (Get-Command winget -ErrorAction SilentlyContinue)) {
        $packageManager = "Winget"
        Write-Log "Using Windows Package Manager (winget)" -Level "INFO"
    } elseif ($UseChocolatey -or (Get-Command choco -ErrorAction SilentlyContinue)) {
        $packageManager = "Chocolatey"
        Write-Log "Using Chocolatey package manager" -Level "INFO"
    }
    
    $successCount = 0
    $totalCount = 0
    
    # Install tools by category
    foreach ($category in $Categories) {
        if ($toolCategories.ContainsKey($category)) {
            Write-Log "Installing $category tools..." -Level "INFO"
            
            foreach ($tool in $toolCategories[$category]) {
                $totalCount++
                $installed = $false
                
                try {
                    if ($tool.Command) {
                        Write-Log "Installing $($tool.Name) via command..." -Level "INFO"
                        Invoke-Expression $tool.Command
                        $installed = $LASTEXITCODE -eq 0
                    } elseif ($packageManager -eq "Winget" -and $tool.WingetId) {
                        $installed = Install-PackageWithWinget -PackageName $tool.Name -WingetId $tool.WingetId
                    } elseif ($packageManager -eq "Chocolatey" -and $tool.ChocoId) {
                        $chocoList = choco list --local-only $tool.ChocoId --exact 2>&1
                        if ($chocoList -match $tool.ChocoId) {
                            Write-Log "$($tool.Name) is already installed via Chocolatey" -Level "SUCCESS"
                            $installed = $true
                        } else {
                            Write-Log "Installing $($tool.Name) via chocolatey..." -Level "INFO"
                            choco install $tool.ChocoId -y
                            $installed = $LASTEXITCODE -eq 0
                        }
                    }
                    
                    if ($installed) {
                        $successCount++
                    }
                }
                catch {
                    Write-Log "Error installing $($tool.Name): $($_.Exception.Message)" -Level "ERROR"
                }
            }
        }
    }
    
    Write-Log "Development tools installation completed: $successCount/$totalCount successful" -Level "SUCCESS"
    RefreshEnv
}

# Docker optimization functions
function Optimize-Docker {
    param(
        [switch]$CleanupContainers,
        [switch]$CleanupImages,
        [switch]$CleanupVolumes,
        [switch]$OptimizeSettings,
        [switch]$All
    )
    
    Write-Log "Starting Docker optimization..." -Level "INFO"
    
    # Check if Docker is installed and running
    $dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerInstalled) {
        Write-Log "Docker is not installed or not in PATH" -Level "ERROR"
        return $false
    }
    
    # Check if Docker daemon is running
    try {
        $null = docker info 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Docker daemon is not running. Starting Docker Desktop..." -Level "WARN"
            Start-Process "Docker Desktop" -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 10
            
            # Try again
            $null = docker info 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Could not start Docker daemon. Please start Docker Desktop manually." -Level "ERROR"
                return $false
            }
        }
    }
    catch {
        Write-Log "Error checking Docker status: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    
    # Track total space cleaned for reporting
    # $spaceCleaned = 0  # Commented out as not currently used
    
    if ($All -or $CleanupContainers) {
        Write-Log "Cleaning up stopped containers..." -Level "INFO"
        try {
            $containerCleanup = docker container prune -f 2>&1
            if ($LASTEXITCODE -eq 0) {
                if ($containerCleanup -match "Total reclaimed space: (.+)") {
                    Write-Log "Containers cleaned: $($matches[1])" -Level "SUCCESS"
                } else {
                    Write-Log "Container cleanup completed" -Level "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Error cleaning containers: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    if ($All -or $CleanupImages) {
        Write-Log "Cleaning up unused images..." -Level "INFO"
        try {
            $imageCleanup = docker image prune -a -f 2>&1
            if ($LASTEXITCODE -eq 0) {
                if ($imageCleanup -match "Total reclaimed space: (.+)") {
                    Write-Log "Images cleaned: $($matches[1])" -Level "SUCCESS"
                } else {
                    Write-Log "Image cleanup completed" -Level "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Error cleaning images: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    if ($All -or $CleanupVolumes) {
        Write-Log "Cleaning up unused volumes..." -Level "INFO"
        try {
            $volumeCleanup = docker volume prune -f 2>&1
            if ($LASTEXITCODE -eq 0) {
                if ($volumeCleanup -match "Total reclaimed space: (.+)") {
                    Write-Log "Volumes cleaned: $($matches[1])" -Level "SUCCESS"
                } else {
                    Write-Log "Volume cleanup completed" -Level "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Error cleaning volumes: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    # System-wide cleanup
    Write-Log "Running system-wide Docker cleanup..." -Level "INFO"
    try {
        $systemCleanup = docker system prune -a -f --volumes 2>&1
        if ($LASTEXITCODE -eq 0) {
            if ($systemCleanup -match "Total reclaimed space: (.+)") {
                Write-Log "System cleanup reclaimed: $($matches[1])" -Level "SUCCESS"
            } else {
                Write-Log "System cleanup completed" -Level "SUCCESS"
            }
        }
    }
    catch {
        Write-Log "Error in system cleanup: $($_.Exception.Message)" -Level "ERROR"
    }
    
    if ($All -or $OptimizeSettings) {
        Write-Log "Optimizing Docker Desktop settings..." -Level "INFO"
        
        # Docker Desktop settings optimization
        $dockerConfigPath = "$env:APPDATA\Docker\settings.json"
        if (Test-Path $dockerConfigPath) {
            try {
                $dockerConfig = Get-Content $dockerConfigPath | ConvertFrom-Json
                
                # Optimize memory and CPU settings based on system specs
                $ramGB = $script:Config.Performance.MaxMemoryUsage
                $cpuCores = $script:Config.Performance.CPUCores
                
                # Set memory limit (leave 25% for system)
                $dockerMemoryMB = [math]::Floor($ramGB * 1024 * 0.75)
                $dockerConfig.memoryMiB = $dockerMemoryMB
                
                # Set CPU limit (use 75% of cores)
                $dockerCPUs = [math]::Max(1, [math]::Floor($cpuCores * 0.75))
                $dockerConfig.cpus = $dockerCPUs
                
                # Enable experimental features for better performance
                $dockerConfig.experimental = $true
                $dockerConfig.useVirtualizationFramework = $true
                $dockerConfig.useVirtualizationFrameworkVirtioFS = $true
                
                # Optimize disk usage
                $dockerConfig.diskTrim = $true
                
                # Save optimized config
                $dockerConfig | ConvertTo-Json -Depth 10 | Set-Content $dockerConfigPath
                Write-Log "Docker Desktop settings optimized: ${dockerMemoryMB}MB RAM, ${dockerCPUs} CPUs" -Level "SUCCESS"
                Write-Log "Please restart Docker Desktop to apply settings" -Level "INFO"
            }
            catch {
                Write-Log "Error optimizing Docker settings: $($_.Exception.Message)" -Level "ERROR"
            }
        } else {
            Write-Log "Docker Desktop settings file not found. Using default optimizations." -Level "WARN"
        }
        
        # WSL2 optimization for Docker (if using WSL2 backend)
        try {
            $wslConfig = "$env:USERPROFILE\.wslconfig"
            $wslConfigExists = Test-Path $wslConfig
            
            $ramGB = $script:Config.Performance.MaxMemoryUsage
            $cpuCores = $script:Config.Performance.CPUCores
            
            # Create or update .wslconfig for Docker optimization
            $wslMemoryGB = [math]::Floor($ramGB * 0.75)
            $wslCPUs = [math]::Max(1, [math]::Floor($cpuCores * 0.75))
            
            $wslConfigContent = @"
[wsl2]
memory=${wslMemoryGB}GB
processors=$wslCPUs
localhostForwarding=true
nestedVirtualization=true
pageReporting=true
guiApplications=true
debugConsole=false
"@
            
            if ($wslConfigExists) {
                $backup = "${wslConfig}.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $wslConfig $backup
                Write-Log "Backed up existing .wslconfig to $backup" -Level "INFO"
            }
            
            $wslConfigContent | Set-Content $wslConfig
            Write-Log "WSL2 configuration optimized for Docker: ${wslMemoryGB}GB RAM, ${wslCPUs} CPUs" -Level "SUCCESS"
            Write-Log "Restart WSL to apply: wsl --shutdown" -Level "INFO"
        }
        catch {
            Write-Log "Error optimizing WSL2 for Docker: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    Write-Log "Docker optimization completed!" -Level "SUCCESS"
    return $true
}

function Get-DockerSystemInfo {
    Write-Log "Gathering Docker system information..." -Level "INFO"
    
    $dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerInstalled) {
        Write-Log "Docker is not installed" -Level "WARN"
        return @{ Installed = $false }
    }
    
    try {
        # Docker version
        $dockerVersion = docker --version 2>&1
        
        # Docker system info
        $dockerInfo = docker system df 2>&1
        $dockerSystemInfo = docker info --format "{{.ServerVersion}}" 2>&1
        
        # Running containers
        $runningContainers = docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>&1
        
        # Images
        $images = docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>&1
        
        return @{
            Installed = $true
            Version = $dockerVersion
            SystemInfo = $dockerInfo
            ServerVersion = $dockerSystemInfo
            RunningContainers = $runningContainers
            Images = $images
        }
    }
    catch {
        Write-Log "Error gathering Docker info: $($_.Exception.Message)" -Level "ERROR"
        return @{ Installed = $true; Error = $_.Exception.Message }
    }
}

# Quick optimization functions for bat files
function Optimize-Quick {
    Write-Log "Running Quick Optimization..." -Level "INFO"
    Optimize-WindowsAdvanced -Level "Balanced"
    Write-Log "Quick optimization completed!" -Level "SUCCESS"
}

function Optimize-Ultra {
    Write-Log "Running Ultra Performance Optimization..." -Level "INFO"
    Optimize-WindowsAdvanced -Level "Ultra"
    Write-Log "Ultra performance optimization completed!" -Level "SUCCESS"
}

function Install-DevTools {
    Write-Log "Installing Development Tools..." -Level "INFO"
    Install-DevelopmentToolsAdvanced -Categories @("Essential", "NodeJS", "Utilities")
    Write-Log "Development tools installation completed!" -Level "SUCCESS"
}

function Clear-AllCaches {
    Write-Log "Clearing all caches..." -Level "INFO"
    # Basic cache cleanup
    $tempPaths = @($env:TEMP, "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Log "Cache cleanup completed!" -Level "SUCCESS"
}

function Optimize-DockerComplete {
    Write-Log "Running Complete Docker Optimization..." -Level "INFO"
    $result = Optimize-Docker -All -OptimizeSettings
    if ($result) {
        Write-Log "Complete Docker optimization finished!" -Level "SUCCESS"
    } else {
        Write-Log "Docker optimization encountered issues. Check the log for details." -Level "WARN"
    }
}

function Optimize-NetworkComplete {
    Write-Log "Running Complete Network Optimization..." -Level "INFO"
    Test-NetworkConnectivity
    Optimize-NetworkSettings -All
    Write-Log "Complete network optimization finished!" -Level "SUCCESS"
}

function Optimize-SecurityComplete {
    Write-Log "Running Complete Security Hardening..." -Level "INFO"
    $vulnerabilities = Test-SystemVulnerabilities
    Test-SystemSecurity
    Set-SecurityHardening -All
    Write-Log "Complete security hardening finished!" -Level "SUCCESS"
    if ($vulnerabilities -and $vulnerabilities.Count -gt 0) {
        Write-Log "RECOMMENDATION: Review the $($vulnerabilities.Count) security issues found and restart the system." -Level "WARN"
    }
}

function Clear-SystemComprehensive {
    Write-Log "Starting comprehensive system cleanup..." -Level "INFO"
    
    $totalCleaned = 0
    $startTime = Get-Date
    
    # Function to get folder size
    function Get-FolderSize {
        param([string]$Path)
        if (!(Test-Path $Path)) { return 0 }
        try {
            return (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        } catch { return 0 }
    }
    
    # Function to clear folder contents safely
    function Clear-FolderContents {
        param([string]$Path, [int]$KeepRecent = 0)
        if (!(Test-Path $Path)) { return 0 }
        
        $before = Get-FolderSize $Path
        try {
            if ($KeepRecent -gt 0) {
                Get-ChildItem $Path -ErrorAction SilentlyContinue | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -Skip $KeepRecent | 
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Get-ChildItem $Path -ErrorAction SilentlyContinue | 
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Log "Error clearing folder $Path : $($_.Exception.Message)" -Level "WARN"
        }
        
        $after = Get-FolderSize $Path
        return ($before - $after)
    }
    
    Write-Log "Step 1/10: Emptying Recycle Bin..." -Level "INFO"
    try {
        # Method 1: PowerShell cmdlet (Windows 10+)
        if (Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue) {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Log "Recycle Bin emptied via PowerShell cmdlet" -Level "SUCCESS"
        } else {
            # Method 2: COM object method
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(10)
            if ($recycleBin) {
                $recycleBin.Items() | ForEach-Object { $_.InvokeVerb("delete") }
                Write-Log "Recycle Bin emptied via COM object" -Level "SUCCESS"
            }
        }
    } catch {
        Write-Log "Error emptying Recycle Bin: $($_.Exception.Message)" -Level "WARN"
    }
    
    Write-Log "Step 2/10: Clearing Windows Temp folders..." -Level "INFO"
    $tempPaths = @(
        $env:TEMP,
        "$env:WINDIR\Temp",
        "$env:LOCALAPPDATA\Temp",
        "$env:WINDIR\SoftwareDistribution\Download",
        "$env:WINDIR\Logs",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"
    )
    
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            $cleaned = Clear-FolderContents $path
            $totalCleaned += $cleaned
            if ($cleaned -gt 0) {
                Write-Log "Cleaned $path : $([math]::Round($cleaned / 1MB, 2)) MB" -Level "SUCCESS"
            }
        }
    }
    
    Write-Log "Step 3/10: Clearing Browser Caches..." -Level "INFO"
    # Chrome caches
    $chromePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Media Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Storage\ext"
    )
    
    foreach ($path in $chromePaths) {
        if (Test-Path $path) {
            $cleaned = Clear-FolderContents $path
            $totalCleaned += $cleaned
            if ($cleaned -gt 0) {
                Write-Log "Cleaned Chrome cache: $([math]::Round($cleaned / 1MB, 2)) MB" -Level "SUCCESS"
            }
        }
    }
    
    # Edge caches
    $edgePaths = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"
    )
    
    foreach ($path in $edgePaths) {
        if (Test-Path $path) {
            $cleaned = Clear-FolderContents $path
            $totalCleaned += $cleaned
            if ($cleaned -gt 0) {
                Write-Log "Cleaned Edge cache: $([math]::Round($cleaned / 1MB, 2)) MB" -Level "SUCCESS"
            }
        }
    }
    
    # Firefox cache
    $firefoxProfile = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($firefoxProfile) {
        $firefoxCaches = @(
            "$($firefoxProfile.FullName)\cache2",
            "$($firefoxProfile.FullName)\startupCache",
            "$($firefoxProfile.FullName)\thumbnails"
        )
        foreach ($path in $firefoxCaches) {
            if (Test-Path $path) {
                $cleaned = Clear-FolderContents $path
                $totalCleaned += $cleaned
                if ($cleaned -gt 0) {
                    Write-Log "Cleaned Firefox cache: $([math]::Round($cleaned / 1MB, 2)) MB" -Level "SUCCESS"
                }
            }
        }
    }
    
    Write-Log "Step 4/10: Clearing Development Caches..." -Level "INFO"
    # Node.js caches
    $devCaches = @(
        "$env:APPDATA\npm-cache",
        "$env:LOCALAPPDATA\npm-cache",
        "$env:USERPROFILE\.npm",
        "$env:USERPROFILE\.pnpm-cache",
        "$env:USERPROFILE\.pnpm-store",
        "$env:LOCALAPPDATA\Yarn\Cache",
        "$env:APPDATA\Code\User\workspaceStorage",
        "$env:APPDATA\Cursor\User\workspaceStorage",
        "$env:LOCALAPPDATA\Microsoft\TypeScript"
    )
    
    foreach ($path in $devCaches) {
        if (Test-Path $path) {
            $cleaned = Clear-FolderContents $path
            $totalCleaned += $cleaned
            if ($cleaned -gt 0) {
                Write-Log "Cleaned dev cache: $([math]::Round($cleaned / 1MB, 2)) MB" -Level "SUCCESS"
            }
        }
    }
    
    Write-Log "Step 5/10: Clearing Windows Error Reporting..." -Level "INFO"
    $werPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
        "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportQueue",
        "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportArchive"
    )
    
    foreach ($path in $werPaths) {
        if (Test-Path $path) {
            $cleaned = Clear-FolderContents $path
            $totalCleaned += $cleaned
            if ($cleaned -gt 0) {
                Write-Log "Cleaned WER reports: $([math]::Round($cleaned / 1MB, 2)) MB" -Level "SUCCESS"
            }
        }
    }
    
    Write-Log "Step 6/10: Clearing Thumbnail Cache..." -Level "INFO"
    $thumbPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer"
    )
    
    foreach ($path in $thumbPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -Filter "thumbcache_*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Get-ChildItem $path -Filter "iconcache_*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Log "Cleared thumbnail cache in $path" -Level "SUCCESS"
        }
    }
    
    Write-Log "Step 7/10: Clearing Windows Update Cache..." -Level "INFO"
    try {
        $wuCachePath = "$env:WINDIR\SoftwareDistribution\Download"
        if (Test-Path $wuCachePath) {
            # Stop Windows Update service temporarily
            $wuService = Get-Service "wuauserv" -ErrorAction SilentlyContinue
            if ($wuService -and $wuService.Status -eq "Running") {
                Stop-Service "wuauserv" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            
            $cleaned = Clear-FolderContents $wuCachePath
            $totalCleaned += $cleaned
            
            # Restart Windows Update service
            if ($wuService) {
                Start-Service "wuauserv" -ErrorAction SilentlyContinue
            }
            
            if ($cleaned -gt 0) {
                Write-Log "Cleaned Windows Update cache: $([math]::Round($cleaned / 1MB, 2)) MB" -Level "SUCCESS"
            }
        }
    } catch {
        Write-Log "Error cleaning Windows Update cache: $($_.Exception.Message)" -Level "WARN"
    }
    
    Write-Log "Step 8/10: Clearing Prefetch (keeping recent)..." -Level "INFO"
    $prefetchPath = "$env:WINDIR\Prefetch"
    if (Test-Path $prefetchPath) {
        $cleaned = Clear-FolderContents $prefetchPath -KeepRecent 50
        $totalCleaned += $cleaned
        if ($cleaned -gt 0) {
            Write-Log "Cleaned old prefetch files: $([math]::Round($cleaned / 1MB, 2)) MB" -Level "SUCCESS"
        }
    }
    
    Write-Log "Step 9/10: Clearing System Event Logs..." -Level "INFO"
    try {
        $eventLogs = @("Application", "System", "Security")
        foreach ($log in $eventLogs) {
            try {
                wevtutil cl $log
                Write-Log "Cleared $log event log" -Level "SUCCESS"
            } catch {
                Write-Log "Could not clear $log event log: $($_.Exception.Message)" -Level "WARN"
            }
        }
    } catch {
        Write-Log "Error clearing event logs: $($_.Exception.Message)" -Level "WARN"
    }
    
    Write-Log "Step 10/10: Running Disk Cleanup..." -Level "INFO"
    try {
        # Run built-in disk cleanup for system drive
        $systemDrive = $env:SystemDrive
        Start-Process "cleanmgr" -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        Write-Log "Windows Disk Cleanup completed" -Level "SUCCESS"
    } catch {
        Write-Log "Could not run Windows Disk Cleanup: $($_.Exception.Message)" -Level "WARN"
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Log "=== COMPREHENSIVE CLEANUP COMPLETED ===" -Level "SUCCESS"
    Write-Log "Total space cleaned: $([math]::Round($totalCleaned / 1MB, 2)) MB" -Level "SUCCESS"
    Write-Log "Cleanup duration: $($duration.TotalMinutes.ToString('F2')) minutes" -Level "INFO"
    Write-Log "=== CLEANUP SUMMARY ===" -Level "INFO"
    Write-Log " Recycle Bin emptied" -Level "INFO"
    Write-Log " Temporary files cleared" -Level "INFO"
    Write-Log " Browser caches cleared" -Level "INFO"
    Write-Log " Development caches cleared" -Level "INFO"
    Write-Log " Error reports cleared" -Level "INFO"
    Write-Log " Thumbnail cache cleared" -Level "INFO"
    Write-Log " Windows Update cache cleared" -Level "INFO"
    Write-Log " Old prefetch files cleared" -Level "INFO"
    Write-Log " Event logs cleared" -Level "INFO"
    Write-Log " Disk cleanup completed" -Level "INFO"
}

# Network Diagnostics and Optimization Functions
function Test-NetworkPerformance {
    Write-Log "Starting network performance analysis..." -Level "INFO"
    
    try {
        # Network adapter information
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        Write-Log "Active Network Adapters:" -Level "INFO"
        foreach ($adapter in $adapters) {
            Write-Log "  - $($adapter.Name): $($adapter.LinkSpeed) ($($adapter.MediaType))" -Level "INFO"
        }
        
        # DNS resolution test
        Write-Log "Testing DNS resolution..." -Level "INFO"
        $dnsServers = @("8.8.8.8", "1.1.1.1", "208.67.222.222")
        $dnsResults = @()
        
        foreach ($dns in $dnsServers) {
            try {
                $result = Measure-Command { nslookup google.com $dns | Out-Null }
                $dnsResults += [PSCustomObject]@{
                    Server = $dns
                    ResponseTime = [math]::Round($result.TotalMilliseconds, 2)
                    Name = switch ($dns) {
                        "8.8.8.8" { "Google DNS" }
                        "1.1.1.1" { "Cloudflare DNS" }
                        "208.67.222.222" { "OpenDNS" }
                    }
                }
            } catch {
                Write-Log "DNS test failed for $dns" -Level "WARN"
            }
        }
        
        $fastestDNS = $dnsResults | Sort-Object ResponseTime | Select-Object -First 1
        Write-Log "Fastest DNS: $($fastestDNS.Name) ($($fastestDNS.Server)) - $($fastestDNS.ResponseTime)ms" -Level "SUCCESS"
        
        # Internet connectivity test
        Write-Log "Testing internet connectivity..." -Level "INFO"
        $connectivityTests = @(
            @{ Host = "google.com"; Port = 80 },
            @{ Host = "github.com"; Port = 443 },
            @{ Host = "microsoft.com"; Port = 443 }
        )
        
        foreach ($test in $connectivityTests) {
            try {
                $connection = Test-NetConnection -ComputerName $test.Host -Port $test.Port -InformationLevel Quiet
                $status = if ($connection) { " Success" } else { " Failed" }
                Write-Log "  $($test.Host):$($test.Port) - $status" -Level "INFO"
            } catch {
                Write-Log "  $($test.Host):$($test.Port) -  Failed" -Level "WARN"
            }
        }
        
        # Network latency test
        Write-Log "Testing network latency..." -Level "INFO"
        $pingResults = Test-Connection -ComputerName "8.8.8.8" -Count 4 -ErrorAction SilentlyContinue
        if ($pingResults) {
            $avgLatency = ($pingResults | Measure-Object -Property ResponseTime -Average).Average
            Write-Log "Average latency to 8.8.8.8: $([math]::Round($avgLatency, 2))ms" -Level "SUCCESS"
        }
        
        return $dnsResults
    }
    catch {
        Write-Log "Error in network performance test: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Optimize-NetworkSettings {
    param(
        [switch]$OptimizeDNS,
        [switch]$OptimizeTCP,
        [switch]$OptimizeWiFi,
        [switch]$All
    )
    
    Write-Log "Starting network optimization..." -Level "INFO"
    
    if ($All -or $OptimizeDNS) {
        Write-Log "Optimizing DNS settings..." -Level "INFO"
        try {
            # Test and set fastest DNS
            $dnsResults = Test-NetworkPerformance
            if ($dnsResults) {
                $fastestDNS = $dnsResults | Sort-Object ResponseTime | Select-Object -First 1
                $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
                
                foreach ($adapter in $adapters) {
                    try {
                        # Set primary and secondary DNS
                        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @($fastestDNS.Server, "8.8.4.4") -ErrorAction SilentlyContinue
                        Write-Log "Set DNS for $($adapter.Name) to $($fastestDNS.Name)" -Level "SUCCESS"
                    } catch {
                        Write-Log "Failed to set DNS for $($adapter.Name)" -Level "WARN"
                    }
                }
            }
            
            # Clear DNS cache
            Clear-DnsClientCache
            Write-Log "DNS cache cleared" -Level "SUCCESS"
        }
        catch {
            Write-Log "Error optimizing DNS: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    if ($All -or $OptimizeTCP) {
        Write-Log "Optimizing TCP/IP settings..." -Level "INFO"
        try {
            # Advanced TCP settings
            $tcpSettings = @{
                "netsh int tcp set global rss=enabled" = "RSS (Receive Side Scaling)"
                "netsh int tcp set global chimney=enabled" = "TCP Chimney Offload"
                "netsh int tcp set global rsc=enabled" = "Receive Segment Coalescing"
                "netsh int tcp set global dca=enabled" = "Direct Cache Access"
                "netsh int tcp set global netdma=enabled" = "NetDMA"
                "netsh int tcp set global ecncapability=enabled" = "ECN Capability"
                "netsh int tcp set global timestamps=enabled" = "TCP Timestamps"
                "netsh int tcp set global initialrto=2000" = "Initial RTO"
                "netsh int tcp set global nonsackrttresiliency=disabled" = "Non-SACK RTT Resiliency"
            }
            
            foreach ($command in $tcpSettings.Keys) {
                try {
                    Invoke-Expression "$command > `$null 2>&1"
                    Write-Log "Enabled: $($tcpSettings[$command])" -Level "SUCCESS"
                } catch {
                    Write-Log "Failed to configure: $($tcpSettings[$command])" -Level "WARN"
                }
            }
        }
        catch {
            Write-Log "Error optimizing TCP settings: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    if ($All -or $OptimizeWiFi) {
        Write-Log "Optimizing WiFi settings..." -Level "INFO"
        try {
            # WiFi power management
            $wifiAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Wireless*" -or $_.InterfaceDescription -like "*WiFi*" -or $_.InterfaceDescription -like "*802.11*" }
            
            foreach ($adapter in $wifiAdapters) {
                try {
                    # Disable power saving on WiFi adapters
                    $powerMgmt = Get-NetAdapterPowerManagement -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue
                    if ($powerMgmt) {
                        Set-NetAdapterPowerManagement -InterfaceIndex $adapter.InterfaceIndex -AllowComputerToTurnOffDevice Disabled -ErrorAction SilentlyContinue
                        Write-Log "Disabled power saving for WiFi adapter: $($adapter.Name)" -Level "SUCCESS"
                    }
                } catch {
                    Write-Log "Could not modify power settings for $($adapter.Name)" -Level "WARN"
                }
            }
            
            # Clean up old WiFi profiles
            $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[1].Trim() }
            $activeProfile = (netsh wlan show interfaces | Select-String "Profile" | ForEach-Object { ($_ -split ":")[1].Trim() })
            
            $removedCount = 0
            foreach ($wifiProfile in $profiles) {
                if ($wifiProfile -ne $activeProfile -and $wifiProfile -ne "") {
                    try {
                        netsh wlan delete profile name="$wifiProfile" > $null 2>&1
                        $removedCount++
                    } catch {}
                }
            }
            
            if ($removedCount -gt 0) {
                Write-Log "Removed $removedCount old WiFi profiles" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Error optimizing WiFi: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    Write-Log "Network optimization completed" -Level "SUCCESS"
}

function Test-NetworkConnectivity {
    Write-Log "Running comprehensive network connectivity test..." -Level "INFO"
    
    $results = @{
        DNS = @()
        Connectivity = @()
        Speed = @{}
        Latency = @{}
    }
    
    try {
        # DNS resolution tests
        $dnsTests = @(
            @{ Server = "8.8.8.8"; Name = "Google DNS" },
            @{ Server = "1.1.1.1"; Name = "Cloudflare DNS" },
            @{ Server = "208.67.222.222"; Name = "OpenDNS" }
        )
        
        foreach ($dns in $dnsTests) {
            try {
                $time = Measure-Command { nslookup google.com $dns.Server | Out-Null }
                $results.DNS += [PSCustomObject]@{
                    Server = $dns.Server
                    Name = $dns.Name
                    ResponseTime = [math]::Round($time.TotalMilliseconds, 2)
                    Status = "Success"
                }
            } catch {
                $results.DNS += [PSCustomObject]@{
                    Server = $dns.Server
                    Name = $dns.Name
                    ResponseTime = -1
                    Status = "Failed"
                }
            }
        }
        
        # Connectivity tests
        $connectivityTests = @(
            @{ Host = "google.com"; Port = 80; Service = "HTTP" },
            @{ Host = "google.com"; Port = 443; Service = "HTTPS" },
            @{ Host = "github.com"; Port = 443; Service = "GitHub HTTPS" },
            @{ Host = "registry.npmjs.org"; Port = 443; Service = "NPM Registry" },
            @{ Host = "api.nuget.org"; Port = 443; Service = "NuGet API" }
        )
        
        foreach ($test in $connectivityTests) {
            try {
                $connection = Test-NetConnection -ComputerName $test.Host -Port $test.Port -InformationLevel Quiet -WarningAction SilentlyContinue
                $results.Connectivity += [PSCustomObject]@{
                    Host = $test.Host
                    Port = $test.Port
                    Service = $test.Service
                    Status = if ($connection) { "Success" } else { "Failed" }
                }
            } catch {
                $results.Connectivity += [PSCustomObject]@{
                    Host = $test.Host
                    Port = $test.Port
                    Service = $test.Service
                    Status = "Error"
                }
            }
        }
        
        # Latency tests
        $latencyTests = @("8.8.8.8", "1.1.1.1", "google.com")
        foreach ($testHost in $latencyTests) {
            try {
                $ping = Test-Connection -ComputerName $testHost -Count 4 -ErrorAction SilentlyContinue
                if ($ping) {
                    $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
                    $results.Latency[$testHost] = [math]::Round($avgLatency, 2)
                } else {
                    $results.Latency[$testHost] = -1
                }
            } catch {
                $results.Latency[$testHost] = -1
            }
        }
        
        # Display results
        Write-Log "=== NETWORK CONNECTIVITY RESULTS ===" -Level "SUCCESS"
        
        Write-Log "DNS Resolution Tests:" -Level "INFO"
        $results.DNS | ForEach-Object {
            $status = if ($_.Status -eq "Success") { "" } else { "" }
            Write-Log "  $status $($_.Name): $($_.ResponseTime)ms" -Level "INFO"
        }
        
        Write-Log "Service Connectivity Tests:" -Level "INFO"
        $results.Connectivity | ForEach-Object {
            $status = if ($_.Status -eq "Success") { "" } else { "" }
            Write-Log "  $status $($_.Service): $($_.Host):$($_.Port)" -Level "INFO"
        }
        
        Write-Log "Latency Tests:" -Level "INFO"
        $results.Latency.GetEnumerator() | ForEach-Object {
            $status = if ($_.Value -gt 0) { "" } else { "" }
            Write-Log "  $status $($_.Key): $($_.Value)ms" -Level "INFO"
        }
        
        return $results
    }
    catch {
        Write-Log "Error in network connectivity test: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Main menu function
function Show-OptimizationMenu {
    Clear-Host
    Write-Host "" -ForegroundColor Cyan
    Write-Host "     ENHANCED WINDOWS 11 DEVELOPMENT OPTIMIZER v3.1        " -ForegroundColor Cyan
    Write-Host "                          FIXED VERSION                      " -ForegroundColor Green
    Write-Host "" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1) Quick Optimization (Balanced)" -ForegroundColor Yellow
    Write-Host "2) Ultra Performance" -ForegroundColor Red
    Write-Host "3) Install Dev Tools" -ForegroundColor Green
    Write-Host "4) Clear Caches (Basic)" -ForegroundColor Blue
    Write-Host "5) Docker Optimization" -ForegroundColor Magenta
    Write-Host "6) System Deep Clean" -ForegroundColor DarkYellow
    Write-Host "7) Network Optimization" -ForegroundColor Cyan
    Write-Host "8) Exit" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-8)"
    
    switch ($choice) {
        "1" { Optimize-Quick }
        "2" { Optimize-Ultra }
        "3" { Install-DevTools }
        "4" { Clear-AllCaches }
        "5" { Optimize-DockerComplete }
        "6" { Clear-SystemComprehensive }
        "7" { Optimize-NetworkComplete }
        "8" { exit }
        default { Write-Host "Invalid choice!" -ForegroundColor Red }
    }
    
    if ($choice -ne "8") {
        Write-Host ""
        Write-Host "Press any key to return to menu..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Show-OptimizationMenu
    }
}

# Entry point
try {
    Get-EnhancedSystemInfo | Out-Null
    
    if ($Mode -eq "Menu") {
        Show-OptimizationMenu
    } else {
        switch ($Mode) {
            "Basic" { Optimize-Quick }
            "Full" { Optimize-Ultra }
            "Custom" { Install-DevTools }
            "Clean" { Clear-AllCaches }
            "Docker" { Optimize-DockerComplete }
            "DeepClean" { Clear-SystemComprehensive }
            "Network" { Optimize-NetworkComplete }
            "CursorAI" { 
                . "$PSScriptRoot\cursor-ai-optimization.ps1"
                Optimize-CursorAIComplete -Profile "AI-Focused"
            }
            "VSCode" {
                . "$PSScriptRoot\vscode-optimization.ps1"
                Optimize-VSCodeComplete -Profile "Development" -BothEditions
            }
            "GPU" {
                . "$PSScriptRoot\gpu-nvidia-broadcast-optimization.ps1"
                Optimize-GPUComplete
            }
            default { Show-OptimizationMenu }
        }
    }
}
catch {
    Write-Log "Unhandled error: $($_.Exception.Message)" -Level "ERROR"
    Write-Host "Press any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

