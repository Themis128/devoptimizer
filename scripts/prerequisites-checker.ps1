<#
.SYNOPSIS
    DevOptimizer automation script: prerequisites-checker.
.DESCRIPTION
    DevOptimizer automation script: prerequisites-checker.
#>

#Requires -RunAsAdministrator

# Prerequisites Checker and Installer Script
# Comprehensive system for checking and installing required tools and dependencies

param(
    [switch]$CheckOnly,
    [switch]$InstallAll,
    [switch]$FixIssues,
    [switch]$Verbose,
    [switch]$Force
)

# Global variables
$Global:PrerequisitesStatus = @{}
$Global:InstallationResults = @{}
$Global:ErrorCount = 0
$Global:SuccessCount = 0
$Global:StartTime = Get-Date

# Enhanced logging
function Write-Log {
    param(
        [string]$Message, 
        [string]$Level = "INFO",
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "INFO" { "White" }
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "DEBUG" { "Cyan" }
            "CRITICAL" { "Magenta" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}

# Check if a command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Get command version
function Get-CommandVersion {
    param([string]$Command)
    try {
        $version = & $Command --version 2>$null
        if (-not $version) {
            $version = & $Command -v 2>$null
        }
        if (-not $version) {
            $version = & $Command version 2>$null
        }
        return $version
    }
    catch {
        return "Unknown"
    }
}

# Check PowerShell version
function Test-PowerShellVersion {
    Write-Log "Checking PowerShell version..." -Level "INFO"
    
    $psVersion = $PSVersionTable.PSVersion
    $minVersion = [Version]"5.1"
    
    if ($psVersion -ge $minVersion) {
        $Global:PrerequisitesStatus["PowerShell"] = @{
            Status = "OK"
            Version = $psVersion.ToString()
            Message = "PowerShell $psVersion is compatible"
        }
        Write-Log "PowerShell version: $psVersion " -Level "SUCCESS"
        return $true
    } else {
        $Global:PrerequisitesStatus["PowerShell"] = @{
            Status = "ERROR"
            Version = $psVersion.ToString()
            Message = "PowerShell $minVersion or higher required"
        }
        Write-Log "PowerShell version: $psVersion  (Requires $minVersion+)" -Level "ERROR"
        return $false
    }
}

# Check .NET Framework
function Test-DotNetFramework {
    Write-Log "Checking .NET Framework..." -Level "INFO"
    
    try {
        $dotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Release
        if ($dotNetVersion -ge 394802) { # .NET 4.6.2
            $Global:PrerequisitesStatus[".NET Framework"] = @{
                Status = "OK"
                Version = "4.6.2+"
                Message = ".NET Framework is available"
            }
            Write-Log ".NET Framework: Available " -Level "SUCCESS"
            return $true
        } else {
            $Global:PrerequisitesStatus[".NET Framework"] = @{
                Status = "WARNING"
                Version = "Unknown"
                Message = ".NET Framework 4.6.2+ recommended"
            }
            Write-Log ".NET Framework: Version check failed " -Level "WARNING"
            return $false
        }
    }
    catch {
        $Global:PrerequisitesStatus[".NET Framework"] = @{
            Status = "ERROR"
            Version = "Unknown"
            Message = ".NET Framework not found"
        }
        Write-Log ".NET Framework: Not found " -Level "ERROR"
        return $false
    }
}

# Check Windows version
function Test-WindowsVersion {
    Write-Log "Checking Windows version..." -Level "INFO"
    
    $osInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, WindowsBuildLabEx
    $winVersion = $osInfo.WindowsVersion
    
    if ($winVersion -ge "10.0") {
        $Global:PrerequisitesStatus["Windows"] = @{
            Status = "OK"
            Version = $winVersion
            Message = "Windows $winVersion is supported"
        }
        Write-Log "Windows version: $winVersion " -Level "SUCCESS"
        return $true
    } else {
        $Global:PrerequisitesStatus["Windows"] = @{
            Status = "WARNING"
            Version = $winVersion
            Message = "Windows 10+ recommended"
        }
        Write-Log "Windows version: $winVersion  (Windows 10+ recommended)" -Level "WARNING"
        return $false
    }
}

# Check Node.js
function Test-NodeJS {
    Write-Log "Checking Node.js..." -Level "INFO"
    
    if (Test-Command "node") {
        $version = Get-CommandVersion "node"
        $Global:PrerequisitesStatus["Node.js"] = @{
            Status = "OK"
            Version = $version
            Message = "Node.js is installed"
        }
                  Write-Log "Node.js: $version [OK]" -Level "SUCCESS"
        return $true
    } else {
        $Global:PrerequisitesStatus["Node.js"] = @{
            Status = "MISSING"
            Version = "Not installed"
            Message = "Node.js is required for npm/yarn operations"
        }
                  Write-Log "Node.js: Not installed [ERROR]" -Level "ERROR"
        return $false
    }
}

# Check Python
function Test-Python {
    Write-Log "Checking Python..." -Level "INFO"
    
    if (Test-Command "python") {
        $version = Get-CommandVersion "python"
        $Global:PrerequisitesStatus["Python"] = @{
            Status = "OK"
            Version = $version
            Message = "Python is installed"
        }
        Write-Log "Python: $version " -Level "SUCCESS"
        return $true
    } elseif (Test-Command "python3") {
        $version = Get-CommandVersion "python3"
        $Global:PrerequisitesStatus["Python"] = @{
            Status = "OK"
            Version = $version
            Message = "Python3 is installed"
        }
        Write-Log "Python3: $version " -Level "SUCCESS"
        return $true
    } else {
        $Global:PrerequisitesStatus["Python"] = @{
            Status = "MISSING"
            Version = "Not installed"
            Message = "Python is required for pip/conda operations"
        }
        Write-Log "Python: Not installed " -Level "ERROR"
        return $false
    }
}

# Check Git
function Test-Git {
    Write-Log "Checking Git..." -Level "INFO"
    
    if (Test-Command "git") {
        $version = Get-CommandVersion "git"
        $Global:PrerequisitesStatus["Git"] = @{
            Status = "OK"
            Version = $version
            Message = "Git is installed"
        }
        Write-Log "Git: $version " -Level "SUCCESS"
        return $true
    } else {
        $Global:PrerequisitesStatus["Git"] = @{
            Status = "MISSING"
            Version = "Not installed"
            Message = "Git is required for repository operations"
        }
        Write-Log "Git: Not installed " -Level "ERROR"
        return $false
    }
}

# Check Docker
function Test-Docker {
    Write-Log "Checking Docker..." -Level "INFO"
    
    if (Test-Command "docker") {
        $version = Get-CommandVersion "docker"
        $Global:PrerequisitesStatus["Docker"] = @{
            Status = "OK"
            Version = $version
            Message = "Docker is installed"
        }
        Write-Log "Docker: $version " -Level "SUCCESS"
        return $true
    } else {
        $Global:PrerequisitesStatus["Docker"] = @{
            Status = "OPTIONAL"
            Version = "Not installed"
            Message = "Docker is optional for container cache cleaning"
        }
        Write-Log "Docker: Not installed (optional) " -Level "WARNING"
        return $false
    }
}

# Check package managers
function Test-PackageManagers {
    Write-Log "Checking package managers..." -Level "INFO"
    
    # npm
    if (Test-Command "npm") {
        $version = Get-CommandVersion "npm"
        $Global:PrerequisitesStatus["npm"] = @{
            Status = "OK"
            Version = $version
            Message = "npm is available"
        }
        Write-Log "npm: $version " -Level "SUCCESS"
    } else {
        $Global:PrerequisitesStatus["npm"] = @{
            Status = "MISSING"
            Version = "Not installed"
            Message = "npm comes with Node.js"
        }
                  Write-Log "npm: Not installed [ERROR]" -Level "ERROR"
    }
    
    # pnpm
    if (Test-Command "pnpm") {
        $version = Get-CommandVersion "pnpm"
        $Global:PrerequisitesStatus["pnpm"] = @{
            Status = "OK"
            Version = $version
            Message = "pnpm is available"
        }
        Write-Log "pnpm: $version " -Level "SUCCESS"
    } else {
        $Global:PrerequisitesStatus["pnpm"] = @{
            Status = "OPTIONAL"
            Version = "Not installed"
            Message = "pnpm is optional"
        }
        Write-Log "pnpm: Not installed (optional) " -Level "WARNING"
    }
    
    # yarn
    if (Test-Command "yarn") {
        $version = Get-CommandVersion "yarn"
        $Global:PrerequisitesStatus["yarn"] = @{
            Status = "OK"
            Version = $version
            Message = "yarn is available"
        }
        Write-Log "yarn: $version " -Level "SUCCESS"
    } else {
        $Global:PrerequisitesStatus["yarn"] = @{
            Status = "OPTIONAL"
            Version = "Not installed"
            Message = "yarn is optional"
        }
        Write-Log "yarn: Not installed (optional) " -Level "WARNING"
    }
    
    # pip
    if (Test-Command "pip") {
        $version = Get-CommandVersion "pip"
        $Global:PrerequisitesStatus["pip"] = @{
            Status = "OK"
            Version = $version
            Message = "pip is available"
        }
        Write-Log "pip: $version " -Level "SUCCESS"
    } else {
        $Global:PrerequisitesStatus["pip"] = @{
            Status = "MISSING"
            Version = "Not installed"
            Message = "pip comes with Python"
        }
        Write-Log "pip: Not installed " -Level "ERROR"
    }
    
    # conda
    if (Test-Command "conda") {
        $version = Get-CommandVersion "conda"
        $Global:PrerequisitesStatus["conda"] = @{
            Status = "OK"
            Version = $version
            Message = "conda is available"
        }
        Write-Log "conda: $version " -Level "SUCCESS"
    } else {
        $Global:PrerequisitesStatus["conda"] = @{
            Status = "OPTIONAL"
            Version = "Not installed"
            Message = "conda is optional"
        }
        Write-Log "conda: Not installed (optional) " -Level "WARNING"
    }
}

# Check development tools
function Test-DevelopmentTools {
    Write-Log "Checking development tools..." -Level "INFO"
    
    # VS Code
    $vscodePath = "${env:ProgramFiles}\Microsoft VS Code\Code.exe"
    if (Test-Path $vscodePath) {
        $Global:PrerequisitesStatus["VS Code"] = @{
            Status = "OK"
            Version = "Installed"
            Message = "VS Code is installed"
        }
        Write-Log "VS Code: Installed " -Level "SUCCESS"
    } else {
        $Global:PrerequisitesStatus["VS Code"] = @{
            Status = "OPTIONAL"
            Version = "Not installed"
            Message = "VS Code is optional"
        }
        Write-Log "VS Code: Not installed (optional) " -Level "WARNING"
    }
    
    # Cursor
    $cursorPath = "${env:LocalAppData}\Programs\Cursor\Cursor.exe"
    if (Test-Path $cursorPath) {
        $Global:PrerequisitesStatus["Cursor"] = @{
            Status = "OK"
            Version = "Installed"
            Message = "Cursor is installed"
        }
        Write-Log "Cursor: Installed " -Level "SUCCESS"
    } else {
        $Global:PrerequisitesStatus["Cursor"] = @{
            Status = "OPTIONAL"
            Version = "Not installed"
            Message = "Cursor is optional"
        }
        Write-Log "Cursor: Not installed (optional) " -Level "WARNING"
    }
}

# Check system requirements
function Test-SystemRequirements {
    Write-Log "Checking system requirements..." -Level "INFO"
    
    # Disk space
    $systemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
    $totalSpaceGB = [math]::Round($systemDrive.Size / 1GB, 2)
    
    if ($freeSpaceGB -ge 5) {
        $Global:PrerequisitesStatus["Disk Space"] = @{
            Status = "OK"
            Version = "${freeSpaceGB}GB free"
            Message = "Sufficient disk space available"
        }
        Write-Log "Disk Space: ${freeSpaceGB}GB free / ${totalSpaceGB}GB total [OK]" -Level "SUCCESS"
    } else {
        $Global:PrerequisitesStatus["Disk Space"] = @{
            Status = "WARNING"
            Version = "${freeSpaceGB}GB free"
            Message = "Low disk space - 5GB+ recommended"
        }
        Write-Log "Disk Space: ${freeSpaceGB}GB free / ${totalSpaceGB}GB total [WARNING]" -Level "WARNING"
    }
    
    # RAM
    $ram = Get-WmiObject -Class Win32_ComputerSystem
    $ramGB = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
    
    if ($ramGB -ge 4) {
        $Global:PrerequisitesStatus["RAM"] = @{
            Status = "OK"
            Version = "${ramGB}GB"
            Message = "Sufficient RAM available"
        }
        Write-Log "RAM: ${ramGB}GB [OK]" -Level "SUCCESS"
    } else {
        $Global:PrerequisitesStatus["RAM"] = @{
            Status = "WARNING"
            Version = "${ramGB}GB"
            Message = "Low RAM - 4GB+ recommended"
        }
        Write-Log "RAM: ${ramGB}GB [WARNING]" -Level "WARNING"
    }
}

# Install Node.js
function Install-NodeJS {
    Write-Log "Installing Node.js..." -Level "INFO"
    
    try {
        $nodeUrl = "https://nodejs.org/dist/v20.10.0/node-v20.10.0-x64.msi"
        $nodeInstaller = "$env:TEMP\nodejs-installer.msi"
        
        Write-Log "Downloading Node.js installer..." -Level "INFO"
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeInstaller -UseBasicParsing
        
        Write-Log "Installing Node.js..." -Level "INFO"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$nodeInstaller`" /quiet /norestart" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        if (Test-Command "node") {
            $version = Get-CommandVersion "node"
            $Global:InstallationResults["Node.js"] = @{
                Status = "SUCCESS"
                Version = $version
                Message = "Node.js installed successfully"
            }
            Write-Log "Node.js installed successfully: $version [SUCCESS]" -Level "SUCCESS"
            $Global:SuccessCount++
            return $true
        } else {
            throw "Node.js installation verification failed"
        }
    }
    catch {
        $Global:InstallationResults["Node.js"] = @{
            Status = "FAILED"
            Version = "Unknown"
            Message = "Node.js installation failed: $($_.Exception.Message)"
        }
        Write-Log "Node.js installation failed: $($_.Exception.Message) [ERROR]" -Level "ERROR"
        $Global:ErrorCount++
        return $false
    }
    finally {
        if (Test-Path $nodeInstaller) {
            Remove-Item $nodeInstaller -Force
        }
    }
}

# Install Python
function Install-Python {
    Write-Log "Installing Python..." -Level "INFO"
    
    try {
        $pythonUrl = "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe"
        $pythonInstaller = "$env:TEMP\python-installer.exe"
        
        Write-Log "Downloading Python installer..." -Level "INFO"
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
        
        Write-Log "Installing Python..." -Level "INFO"
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        if (Test-Command "python") {
            $version = Get-CommandVersion "python"
            $Global:InstallationResults["Python"] = @{
                Status = "SUCCESS"
                Version = $version
                Message = "Python installed successfully"
            }
            Write-Log "Python installed successfully: $version " -Level "SUCCESS"
            $Global:SuccessCount++
            return $true
        } else {
            throw "Python installation verification failed"
        }
    }
    catch {
        $Global:InstallationResults["Python"] = @{
            Status = "FAILED"
            Version = "Unknown"
            Message = "Python installation failed: $($_.Exception.Message)"
        }
        Write-Log "Python installation failed: $($_.Exception.Message) " -Level "ERROR"
        $Global:ErrorCount++
        return $false
    }
    finally {
        if (Test-Path $pythonInstaller) {
            Remove-Item $pythonInstaller -Force
        }
    }
}

# Install Git
function Install-Git {
    Write-Log "Installing Git..." -Level "INFO"
    
    try {
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"
        $gitInstaller = "$env:TEMP\git-installer.exe"
        
        Write-Log "Downloading Git installer..." -Level "INFO"
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
        
        Write-Log "Installing Git..." -Level "INFO"
        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        if (Test-Command "git") {
            $version = Get-CommandVersion "git"
            $Global:InstallationResults["Git"] = @{
                Status = "SUCCESS"
                Version = $version
                Message = "Git installed successfully"
            }
            Write-Log "Git installed successfully: $version " -Level "SUCCESS"
            $Global:SuccessCount++
            return $true
        } else {
            throw "Git installation verification failed"
        }
    }
    catch {
        $Global:InstallationResults["Git"] = @{
            Status = "FAILED"
            Version = "Unknown"
            Message = "Git installation failed: $($_.Exception.Message)"
        }
        Write-Log "Git installation failed: $($_.Exception.Message) " -Level "ERROR"
        $Global:ErrorCount++
        return $false
    }
    finally {
        if (Test-Path $gitInstaller) {
            Remove-Item $gitInstaller -Force
        }
    }
}

# Install optional tools
function Install-OptionalTools {
    Write-Log "Installing optional tools..." -Level "INFO"
    
    # Install pnpm
    if (-not (Test-Command "pnpm")) {
        try {
            Write-Log "Installing pnpm..." -Level "INFO"
            npm install -g pnpm
            
            if (Test-Command "pnpm") {
                $version = Get-CommandVersion "pnpm"
                $Global:InstallationResults["pnpm"] = @{
                    Status = "SUCCESS"
                    Version = $version
                    Message = "pnpm installed successfully"
                }
                Write-Log "pnpm installed successfully: $version " -Level "SUCCESS"
                $Global:SuccessCount++
            }
        }
        catch {
            Write-Log "pnpm installation failed: $($_.Exception.Message) " -Level "WARNING"
        }
    }
    
    # Install yarn
    if (-not (Test-Command "yarn")) {
        try {
            Write-Log "Installing yarn..." -Level "INFO"
            npm install -g yarn
            
            if (Test-Command "yarn") {
                $version = Get-CommandVersion "yarn"
                $Global:InstallationResults["yarn"] = @{
                    Status = "SUCCESS"
                    Version = $version
                    Message = "yarn installed successfully"
                }
                Write-Log "yarn installed successfully: $version " -Level "SUCCESS"
                $Global:SuccessCount++
            }
        }
        catch {
            Write-Log "yarn installation failed: $($_.Exception.Message) " -Level "WARNING"
        }
    }
}

# Generate summary report
function Write-SummaryReport {
    $endTime = Get-Date
    $duration = $endTime - $Global:StartTime
    
    Write-Log "====================" -Level "INFO"
    Write-Log "PREREQUISITES SUMMARY" -Level "INFO"
    Write-Log "====================" -Level "INFO"
    Write-Log "Start Time: $($Global:StartTime)" -Level "INFO"
    Write-Log "End Time: $endTime" -Level "INFO"
    Write-Log "Duration: $($duration.Minutes)m $($duration.Seconds)s" -Level "INFO"
    
    Write-Log "`nPREREQUISITES STATUS:" -Level "INFO"
    foreach ($prereq in $Global:PrerequisitesStatus.GetEnumerator()) {
        $status = $prereq.Value.Status
        $version = $prereq.Value.Version
        $message = $prereq.Value.Message
        
        $color = switch ($status) {
            "OK" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "MISSING" { "Red" }
            "OPTIONAL" { "Cyan" }
        }
        
        Write-Host "  $($prereq.Key): $status ($version) - $message" -ForegroundColor $color
    }
    
    if ($Global:InstallationResults.Count -gt 0) {
        Write-Log "`nINSTALLATION RESULTS:" -Level "INFO"
        foreach ($install in $Global:InstallationResults.GetEnumerator()) {
            $status = $install.Value.Status
            $version = $install.Value.Version
            $message = $install.Value.Message
            
            $color = switch ($status) {
                "SUCCESS" { "Green" }
                "FAILED" { "Red" }
            }
            
            Write-Host "  $($install.Key): $status ($version) - $message" -ForegroundColor $color
        }
    }
    
    Write-Log "`nOverall Status:" -Level "INFO"
    Write-Log "Successful Installations: $($Global:SuccessCount)" -Level "SUCCESS"
    Write-Log "Failed Installations: $($Global:ErrorCount)" -Level "ERROR"
    
    # Check if system is ready
    $criticalMissing = $Global:PrerequisitesStatus.GetEnumerator() | Where-Object { $_.Value.Status -eq "MISSING" }
    if ($criticalMissing.Count -eq 0) {
        Write-Log "`n System is ready for cache cleaning operations!" -Level "SUCCESS"
    } else {
        Write-Log "`n Some critical prerequisites are missing. Run with -InstallAll to install them." -Level "WARNING"
    }
}

# Main execution
try {
    Write-Log "Starting Prerequisites Checker and Installer..." -Level "INFO"
    
    # Check all prerequisites
    Write-Log "Checking system prerequisites..." -Level "INFO"
    Test-PowerShellVersion
    Test-DotNetFramework
    Test-WindowsVersion
    Test-NodeJS
    Test-Python
    Test-Git
    Test-Docker
    Test-PackageManagers
    Test-DevelopmentTools
    Test-SystemRequirements
    
    # Install missing prerequisites if requested
    if ($InstallAll -or $FixIssues) {
        Write-Log "`nInstalling missing prerequisites..." -Level "INFO"
        
        if (-not (Test-Command "node")) {
            Install-NodeJS
        }
        
        if (-not (Test-Command "python") -and -not (Test-Command "python3")) {
            Install-Python
        }
        
        if (-not (Test-Command "git")) {
            Install-Git
        }
        
        Install-OptionalTools
        
        # Re-check after installation
        Write-Log "`nRe-checking prerequisites after installation..." -Level "INFO"
        Test-NodeJS
        Test-Python
        Test-Git
        Test-PackageManagers
    }
    
    # Generate summary report
    Write-SummaryReport
    
    Write-Log "Prerequisites checker completed!" -Level "SUCCESS"
}
catch {
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)" -Level "CRITICAL"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    Write-SummaryReport
    exit 1
}

