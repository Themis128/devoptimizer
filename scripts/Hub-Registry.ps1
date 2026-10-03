<#
.SYNOPSIS
    DevOptimizer automation script: Hub-Registry.
.DESCRIPTION
    DevOptimizer automation script: Hub-Registry.
#>

# =====================================================
# DEVOPTIMIZER HUB REGISTRY MANAGEMENT v4.0
# Centralized registry management for hub discovery
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

# Global Variables
$script:HubRegistryPath = "HKLM:\SOFTWARE\DevOptimizer"
$script:UserRegistryPath = "HKCU:\SOFTWARE\DevOptimizer"
$script:DefaultHubPath = "D:\DevOptimizer"

# =====================================================
# REGISTRY MANAGEMENT FUNCTIONS
# =====================================================

function Initialize-HubRegistry {
    param(
        [string]$HubPath = $script:DefaultHubPath,
        [switch]$Force
    )

    try {
        Write-Host "Initializing DevOptimizer Hub Registry..." -ForegroundColor Cyan

        # Create system-wide registry entries (requires admin)
        if (Test-Administrator) {
            if (!(Test-Path $script:HubRegistryPath) -or $Force) {
                New-Item -Path $script:HubRegistryPath -Force | Out-Null
                Write-Host "Created system registry key" -ForegroundColor Green
            }

            Set-ItemProperty -Path $script:HubRegistryPath -Name "HubPath" -Value $HubPath
            Set-ItemProperty -Path $script:HubRegistryPath -Name "Version" -Value "4.0.0"
            Set-ItemProperty -Path $script:HubRegistryPath -Name "InstallDate" -Value (Get-Date).ToString()
            Set-ItemProperty -Path $script:HubRegistryPath -Name "LastUpdate" -Value (Get-Date).ToString()

            Write-Host "System registry entries created successfully" -ForegroundColor Green
        }
        else {
            Write-Host "No admin privileges - skipping system registry" -ForegroundColor Yellow
        }

        # Create user-specific registry entries
        if (!(Test-Path $script:UserRegistryPath) -or $Force) {
            New-Item -Path $script:UserRegistryPath -Force | Out-Null
            Write-Host "Created user registry key" -ForegroundColor Green
        }

        Set-ItemProperty -Path $script:UserRegistryPath -Name "HubPath" -Value $HubPath
        Set-ItemProperty -Path $script:UserRegistryPath -Name "UserPreferences" -Value "Default"
        Set-ItemProperty -Path $script:UserRegistryPath -Name "LastAccessed" -Value (Get-Date).ToString()

        Write-Host "User registry entries created successfully" -ForegroundColor Green

        # Set environment variables
        [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $HubPath, "Process")
        [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $HubPath, "User")

        Write-Host "Environment variables set" -ForegroundColor Green

        return $true
    }
    catch {
        Write-Host "Failed to initialize hub registry: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-HubPath {
    param([switch]$Verbose)

    try {
        # Priority order:
        # 1. Environment variable (current session)
        # 2. User environment variable
        # 3. System registry
        # 4. User registry
        # 5. Default path

        # Check current session environment variable
        $envPath = [Environment]::GetEnvironmentVariable("DEVOPTIMIZER_HUB", "Process")
        if ($envPath -and (Test-Path $envPath)) {
            if ($Verbose) { Write-Host "Hub found via process environment: $envPath" -ForegroundColor Green }
            return $envPath
        }

        # Check user environment variable
        $userEnvPath = [Environment]::GetEnvironmentVariable("DEVOPTIMIZER_HUB", "User")
        if ($userEnvPath -and (Test-Path $userEnvPath)) {
            if ($Verbose) { Write-Host "Hub found via user environment: $userEnvPath" -ForegroundColor Green }
            [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $userEnvPath, "Process")
            return $userEnvPath
        }

        # Check system registry
        if (Test-Path $script:HubRegistryPath) {
            try {
                $regPath = Get-ItemProperty -Path $script:HubRegistryPath -Name "HubPath" -ErrorAction SilentlyContinue
                if ($regPath -and (Test-Path $regPath.HubPath)) {
                    if ($Verbose) { Write-Host "Hub found via system registry: $($regPath.HubPath)" -ForegroundColor Green }
                    [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $regPath.HubPath, "Process")
                    return $regPath.HubPath
                }
            }
            catch {
                if ($Verbose) { Write-Host "Could not read system registry: $($_.Exception.Message)" -ForegroundColor Yellow }
            }
        }

        # Check user registry
        if (Test-Path $script:UserRegistryPath) {
            try {
                $userRegPath = Get-ItemProperty -Path $script:UserRegistryPath -Name "HubPath" -ErrorAction SilentlyContinue
                if ($userRegPath -and (Test-Path $userRegPath.HubPath)) {
                    if ($Verbose) { Write-Host "Hub found via user registry: $($userRegPath.HubPath)" -ForegroundColor Green }
                    [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $userRegPath.HubPath, "Process")
                    return $userRegPath.HubPath
                }
            }
            catch {
                if ($Verbose) { Write-Host "Could not read user registry: $($_.Exception.Message)" -ForegroundColor Yellow }
            }
        }

        # Default path fallback
        if (Test-Path $script:DefaultHubPath) {
            if ($Verbose) { Write-Host "Using default hub path: $script:DefaultHubPath" -ForegroundColor Yellow }
            [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $script:DefaultHubPath, "Process")
            return $script:DefaultHubPath
        }

        # No hub found
        if ($Verbose) { Write-Host "No DevOptimizer hub found!" -ForegroundColor Red }
        return $null
    }
    catch {
        Write-Host "Error finding hub path: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Set-HubPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$HubPath,
        [switch]$CreateIfNotExists
    )

    try {
        # Validate path
        if (!(Test-Path $HubPath)) {
            if ($CreateIfNotExists) {
                New-Item -Path $HubPath -ItemType Directory -Force | Out-Null
                Write-Host "Created hub directory: $HubPath" -ForegroundColor Green
            }
            else {
                Write-Host "Hub path does not exist: $HubPath" -ForegroundColor Red
                return $false
            }
        }

        # Update registry entries
        if (Test-Administrator) {
            if (Test-Path $script:HubRegistryPath) {
                Set-ItemProperty -Path $script:HubRegistryPath -Name "HubPath" -Value $HubPath
                Set-ItemProperty -Path $script:HubRegistryPath -Name "LastUpdate" -Value (Get-Date).ToString()
                Write-Host "Updated system registry" -ForegroundColor Green
            }
        }

        if (Test-Path $script:UserRegistryPath) {
            Set-ItemProperty -Path $script:UserRegistryPath -Name "HubPath" -Value $HubPath
            Set-ItemProperty -Path $script:UserRegistryPath -Name "LastAccessed" -Value (Get-Date).ToString()
            Write-Host "Updated user registry" -ForegroundColor Green
        }

        # Update environment variables
        [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $HubPath, "Process")
        [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $HubPath, "User")

        Write-Host "Hub path updated successfully: $HubPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to set hub path: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-HubInfo {
    try {
        $hubPath = Get-HubPath -Verbose

        if (!$hubPath) {
            return @{
                Found = $false
                Path = $null
                Version = $null
                InstallDate = $null
                LastUpdate = $null
                Structure = @{}
            }
        }

        # Get registry information
        $systemInfo = $null
        $userInfo = $null

        if (Test-Path $script:HubRegistryPath) {
            try {
                $systemInfo = Get-ItemProperty -Path $script:HubRegistryPath -ErrorAction SilentlyContinue
            }
            catch { }
        }

        if (Test-Path $script:UserRegistryPath) {
            try {
                $userInfo = Get-ItemProperty -Path $script:UserRegistryPath -ErrorAction SilentlyContinue
            }
            catch { }
        }

        # Analyze directory structure
        $structure = @{}
        $expectedDirs = @("scripts", "logs", "config", "backups", "templates", "tools", "reports", "exports")

        foreach ($dir in $expectedDirs) {
            $dirPath = Join-Path $hubPath $dir
            $structure[$dir] = @{
                Exists = Test-Path $dirPath
                Path = $dirPath
                ItemCount = if (Test-Path $dirPath) { (Get-ChildItem $dirPath -Force | Measure-Object).Count } else { 0 }
            }
        }

        return @{
            Found = $true
            Path = $hubPath
            Version = $systemInfo.Version
            InstallDate = $systemInfo.InstallDate
            LastUpdate = $systemInfo.LastUpdate
            LastAccessed = $userInfo.LastAccessed
            Structure = $structure
            SystemRegistry = $systemInfo -ne $null
            UserRegistry = $userInfo -ne $null
        }
    }
    catch {
        Write-Host "Error getting hub info: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Remove-HubRegistry {
    param([switch]$Force)

    try {
        if (!$Force) {
            $confirm = Read-Host "Are you sure you want to remove all DevOptimizer registry entries? (y/N)"
            if ($confirm -ne "y" -and $confirm -ne "Y") {
                Write-Host "Operation cancelled" -ForegroundColor Yellow
                return $false
            }
        }

        # Remove system registry
        if (Test-Administrator -and (Test-Path $script:HubRegistryPath)) {
            Remove-Item -Path $script:HubRegistryPath -Recurse -Force
            Write-Host "Removed system registry entries" -ForegroundColor Green
        }

        # Remove user registry
        if (Test-Path $script:UserRegistryPath) {
            Remove-Item -Path $script:UserRegistryPath -Recurse -Force
            Write-Host "Removed user registry entries" -ForegroundColor Green
        }

        # Remove environment variables
        [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $null, "Process")
        [Environment]::SetEnvironmentVariable("DEVOPTIMIZER_HUB", $null, "User")

        Write-Host "DevOptimizer registry entries removed successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to remove registry entries: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-HubConnectivity {
    param([string]$HubPath = $null)

    try {
        if (!$HubPath) {
            $HubPath = Get-HubPath
        }

        if (!$HubPath) {
            return @{
                Connected = $false
                Error = "Hub path not found"
                Tests = @{}
            }
        }

        $tests = @{}

        # Test directory access
        $tests["DirectoryAccess"] = @{
            Success = Test-Path $HubPath
            Error = if (!(Test-Path $HubPath)) { "Directory not accessible" } else { $null }
        }

        # Test write permissions
        $testFile = Join-Path $HubPath "connectivity_test.tmp"
        try {
            "test" | Out-File -FilePath $testFile -Force
            Remove-Item $testFile -Force
            $tests["WritePermissions"] = @{ Success = $true; Error = $null }
        }
        catch {
            $tests["WritePermissions"] = @{ Success = $false; Error = $_.Exception.Message }
        }

        # Test core directories
        $coreDirs = @("scripts", "logs", "config")
        foreach ($dir in $coreDirs) {
            $dirPath = Join-Path $HubPath $dir
            $tests["Directory_$dir"] = @{
                Success = Test-Path $dirPath
                Error = if (!(Test-Path $dirPath)) { "Directory missing: $dirPath" } else { $null }
            }
        }

        # Test core PowerShell module
        $coreModule = Join-Path $HubPath "scripts\DevOptimizer-Core.ps1"
        $tests["CoreModule"] = @{
            Success = Test-Path $coreModule
            Error = if (!(Test-Path $coreModule)) { "Core module missing: $coreModule" } else { $null }
        }

        $allSuccess = ($tests.Values | Where-Object { !$_.Success }).Count -eq 0

        return @{
            Connected = $allSuccess
            HubPath = $HubPath
            Tests = $tests
            Error = if (!$allSuccess) { "One or more connectivity tests failed" } else { $null }
        }
    }
    catch {
        return @{
            Connected = $false
            Error = "Connectivity test failed: $($_.Exception.Message)"
            Tests = @{}
        }
    }
}

function Register-BATFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BATFilePath,
        [string]$Description = "",
        [string]$Category = "General"
    )

    try {
        $hubPath = Get-HubPath
        if (!$hubPath) {
            Write-Host "Hub not found - cannot register BAT file" -ForegroundColor Red
            return $false
        }

        $registryFile = Join-Path $hubPath "config\bat-registry.json"

        # Load existing registry
        $registry = @{}
        if (Test-Path $registryFile) {
            $registry = Get-Content $registryFile -Raw | ConvertFrom-Json -AsHashtable
        }

        # Add or update entry
        $fileName = [System.IO.Path]::GetFileName($BATFilePath)
        $registry[$fileName] = @{
            Path = $BATFilePath
            Description = $Description
            Category = $Category
            RegisteredDate = (Get-Date).ToString()
            LastModified = (Get-Item $BATFilePath -ErrorAction SilentlyContinue).LastWriteTime.ToString()
        }

        # Save registry
        $registry | ConvertTo-Json -Depth 3 | Out-File -FilePath $registryFile -Encoding UTF8

        Write-Host "BAT file registered: $fileName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to register BAT file: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-RegisteredBATFiles {
    try {
        $hubPath = Get-HubPath
        if (!$hubPath) {
            return @{}
        }

        $registryFile = Join-Path $hubPath "config\bat-registry.json"

        if (Test-Path $registryFile) {
            return Get-Content $registryFile -Raw | ConvertFrom-Json -AsHashtable
        }
        else {
            return @{}
        }
    }
    catch {
        Write-Host "Failed to get registered BAT files: $($_.Exception.Message)" -ForegroundColor Red
        return @{}
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

# =====================================================
# MAIN EXECUTION LOGIC
# =====================================================

if ($Operation) {
    switch ($Operation.ToLower()) {
        "init" {
            $hubPath = if ($Parameters.ContainsKey("HubPath")) { $Parameters["HubPath"] } else { $script:DefaultHubPath }
            $force = $Parameters.ContainsKey("Force")
            Initialize-HubRegistry -HubPath $hubPath -Force:$force
        }
        "get" {
            $verbose = $Parameters.ContainsKey("Verbose")
            Get-HubPath -Verbose:$verbose
        }
        "set" {
            if ($Parameters.ContainsKey("HubPath")) {
                $create = $Parameters.ContainsKey("CreateIfNotExists")
                Set-HubPath -HubPath $Parameters["HubPath"] -CreateIfNotExists:$create
            }
        }
        "info" {
            Get-HubInfo
        }
        "remove" {
            $force = $Parameters.ContainsKey("Force")
            Remove-HubRegistry -Force:$force
        }
        "test" {
            $hubPath = if ($Parameters.ContainsKey("HubPath")) { $Parameters["HubPath"] } else { $null }
            Test-HubConnectivity -HubPath $hubPath
        }
        "register" {
            if ($Parameters.ContainsKey("BATFilePath")) {
                $desc = if ($Parameters.ContainsKey("Description")) { $Parameters["Description"] } else { "" }
                $cat = if ($Parameters.ContainsKey("Category")) { $Parameters["Category"] } else { "General" }
                Register-BATFile -BATFilePath $Parameters["BATFilePath"] -Description $desc -Category $cat
            }
        }
        "list" {
            Get-RegisteredBATFiles
        }
        default {
            Write-Host "Unknown operation: $Operation" -ForegroundColor Red
            return $false
        }
    }
}
