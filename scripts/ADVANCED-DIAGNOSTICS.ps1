# =====================================================
# DEVOPTIMIZER ADVANCED DIAGNOSTIC SUITE v4.0
# PowerShell-based comprehensive system analysis
# =====================================================

<#+
.SYNOPSIS
Runs the DevOptimizer advanced diagnostics suite to collect detailed system health information.

.DESCRIPTION
Performs comprehensive environment checks, gathers resource metrics, and writes results to structured log and JSON outputs. Optional switches enable deep inspections and export control.

.PARAMETER Detailed
Expands diagnostics to include extended resource and process analysis.

.PARAMETER ExportResults
Exports the collected diagnostic data to the specified output directory.

.PARAMETER OutputPath
Overrides the default destination folder used when -ExportResults is supplied. Defaults to .\diagnostics.

.EXAMPLE
PS> .\ADVANCED-DIAGNOSTICS.ps1 -Detailed -ExportResults
Runs the full diagnostics workflow and stores logs and JSON output in the default diagnostics folder.

.EXAMPLE
PS> .\ADVANCED-DIAGNOSTICS.ps1 -ExportResults -OutputPath D:\Reports
Generates diagnostics with the standard level of detail and saves artifacts to D:\Reports.

.NOTES
Author: DevOptimizer automation tools
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportResults,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\diagnostics"
)

# Set up logging and output
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = ".\logs\advanced-diagnostics_$timestamp.log"
$resultsPath = ".\diagnostics\diagnostic-results_$timestamp.json"

# Ensure directories exist
@("logs", "diagnostics") | ForEach-Object {
    if (!(Test-Path $_)) { New-Item -Path $_ -ItemType Directory -Force | Out-Null }
}

function Write-DiagnosticLog {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $logPath -Value $logEntry
    
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "INFO" { Write-Host $logEntry -ForegroundColor Cyan }
        default { Write-Host $logEntry }
    }
}

function Test-FileAccess {
    param([string]$FilePath)
    try {
        $file = Get-Item $FilePath -ErrorAction Stop
        $testPath = "$FilePath.accesstest"
        Copy-Item $FilePath $testPath -ErrorAction Stop
        Remove-Item $testPath -ErrorAction Stop
        return @{ Success = $true; Error = $null; Locked = $false }
    }
    catch {
        $isLocked = $_.Exception.Message -match "being used by another process"
        return @{ Success = $false; Error = $_.Exception.Message; Locked = $isLocked }
    }
}

function Get-ProcessLocks {
    param([string]$Directory = ".")
    
    Write-DiagnosticLog "Analyzing process locks in directory: $Directory"
    
    try {
        # Get all handles for the directory (requires handle.exe or similar)
        # For now, we'll check common processes that might lock files
        $suspiciousProcesses = Get-Process | Where-Object { 
            $_.ProcessName -match "cmd|powershell|conhost|explorer|notepad|code|cursor" 
        } | Select-Object ProcessName, Id, @{Name="CPU";Expression={$_.CPU}}, @{Name="Memory";Expression={[math]::Round($_.WorkingSet/1MB,2)}}
        
        return $suspiciousProcesses
    }
    catch {
        Write-DiagnosticLog "Failed to analyze process locks: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Test-PowerShellIntegration {
    Write-DiagnosticLog "Testing PowerShell integration capabilities"
    
    $results = @{}
    
    # Test execution policy
    try {
        $executionPolicy = Get-ExecutionPolicy
        $results.ExecutionPolicy = @{ Value = $executionPolicy; Success = $true }
        Write-DiagnosticLog "Execution Policy: $executionPolicy" "SUCCESS"
    }
    catch {
        $results.ExecutionPolicy = @{ Value = $null; Success = $false; Error = $_.Exception.Message }
        Write-DiagnosticLog "Failed to get execution policy: $($_.Exception.Message)" "ERROR"
    }
    
    # Test module loading
    try {
        $modules = Get-Module -ListAvailable | Where-Object { $_.Name -match "Microsoft|Windows" } | Measure-Object
        $results.AvailableModules = @{ Count = $modules.Count; Success = $true }
        Write-DiagnosticLog "Available PowerShell modules: $($modules.Count)" "SUCCESS"
    }
    catch {
        $results.AvailableModules = @{ Count = 0; Success = $false; Error = $_.Exception.Message }
        Write-DiagnosticLog "Failed to enumerate modules: $($_.Exception.Message)" "ERROR"
    }
    
    # Test .NET Framework version
    try {
        $dotnetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        $results.DotNetVersion = @{ Value = $dotnetVersion; Success = $true }
        Write-DiagnosticLog ".NET Version: $dotnetVersion" "SUCCESS"
    }
    catch {
        $results.DotNetVersion = @{ Value = $null; Success = $false; Error = $_.Exception.Message }
        Write-DiagnosticLog "Failed to get .NET version: $($_.Exception.Message)" "ERROR"
    }
    
    return $results
}

function Test-SystemResources {
    Write-DiagnosticLog "Analyzing system resources and performance"
    
    $results = @{}
    
    try {
        # CPU Information
        $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        $results.CPU = @{
            Name = $cpu.Name
            Cores = $cpu.NumberOfCores
            LogicalProcessors = $cpu.NumberOfLogicalProcessors
            MaxClockSpeed = $cpu.MaxClockSpeed
        }
        
        # Memory Information
        $memory = Get-WmiObject -Class Win32_OperatingSystem
        $totalRAM = [math]::Round($memory.TotalVisibleMemorySize/1MB, 2)
        $freeRAM = [math]::Round($memory.FreePhysicalMemory/1MB, 2)
        $usedRAM = $totalRAM - $freeRAM
        $memoryUsagePercent = [math]::Round(($usedRAM / $totalRAM) * 100, 2)
        
        $results.Memory = @{
            TotalGB = $totalRAM
            FreeGB = $freeRAM
            UsedGB = $usedRAM
            UsagePercent = $memoryUsagePercent
        }
        
        # Disk Information
        $disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            @{
                Drive = $_.DeviceID
                TotalGB = [math]::Round($_.Size/1GB, 2)
                FreeGB = [math]::Round($_.FreeSpace/1GB, 2)
                UsagePercent = [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2)
            }
        }
        $results.Disks = $disks
        
        Write-DiagnosticLog "System resources analyzed successfully" "SUCCESS"
    }
    catch {
        Write-DiagnosticLog "Failed to analyze system resources: $($_.Exception.Message)" "ERROR"
        $results.Error = $_.Exception.Message
    }
    
    return $results
}

function Test-FileSystemStructure {
    Write-DiagnosticLog "Analyzing DevOptimizer file system structure"
    
    $expectedDirectories = @(
        "scripts", "logs", "config", "backups", "templates", 
        "categories", "generators", "registry", "docs", "tools"
    )
    
    $results = @{
        ExpectedDirectories = @{}
        FileInventory = @{}
        Issues = @()
    }
    
    # Check expected directories
    foreach ($dir in $expectedDirectories) {
        $exists = Test-Path $dir
        $itemCount = if ($exists) { (Get-ChildItem $dir -Force -ErrorAction SilentlyContinue | Measure-Object).Count } else { 0 }
        
        $results.ExpectedDirectories[$dir] = @{
            Exists = $exists
            ItemCount = $itemCount
        }
        
        if (!$exists) {
            $results.Issues += "Missing directory: $dir"
            Write-DiagnosticLog "Missing directory: $dir" "WARNING"
        }
    }
    
    # File inventory
    $fileTypes = @("*.bat", "*.ps1", "*.json", "*.md", "*.txt", "*.log")
    foreach ($fileType in $fileTypes) {
        $files = Get-ChildItem $fileType -ErrorAction SilentlyContinue
        $extension = $fileType.Replace("*", "")
        $results.FileInventory[$extension] = @{
            Count = $files.Count
            TotalSize = ($files | Measure-Object -Property Length -Sum).Sum
        }
    }
    
    return $results
}

function Test-ScriptIntegrity {
    Write-DiagnosticLog "Testing script integrity and dependencies"
    
    $results = @{
        BATFiles = @{}
        PowerShellFiles = @{}
        Issues = @()
    }
    
    # Test BAT files
    $batFiles = Get-ChildItem "*.bat" -ErrorAction SilentlyContinue
    foreach ($batFile in $batFiles) {
        $accessTest = Test-FileAccess $batFile.FullName
        $content = if ($accessTest.Success) { Get-Content $batFile.FullName -ErrorAction SilentlyContinue } else { @() }
        
        $analysis = @{
            Name = $batFile.Name
            Size = $batFile.Length
            LastModified = $batFile.LastWriteTime
            Accessible = $accessTest.Success
            Locked = $accessTest.Locked
            HasEchoOff = ($content | Select-String "@echo off" | Measure-Object).Count -gt 0
            HasTitle = ($content | Select-String "title " | Measure-Object).Count -gt 0
            HasPowerShellCall = ($content | Select-String "powershell" | Measure-Object).Count -gt 0
            LineCount = $content.Count
        }
        
        if ($accessTest.Locked) {
            $results.Issues += "File locked: $($batFile.Name)"
        }
        
        $results.BATFiles[$batFile.Name] = $analysis
    }
    
    # Test PowerShell files
    $ps1Files = Get-ChildItem "*.ps1" -ErrorAction SilentlyContinue
    foreach ($ps1File in $ps1Files) {
        $accessTest = Test-FileAccess $ps1File.FullName
        
        $analysis = @{
            Name = $ps1File.Name
            Size = $ps1File.Length
            LastModified = $ps1File.LastWriteTime
            Accessible = $accessTest.Success
            Locked = $accessTest.Locked
        }
        
        if ($accessTest.Success) {
            try {
                # Try to parse the PowerShell file for syntax errors
                $errors = $null
                [System.Management.Automation.PSParser]::Tokenize((Get-Content $ps1File.FullName -Raw), [ref]$errors) | Out-Null
                $analysis.SyntaxValid = $errors.Count -eq 0
                $analysis.SyntaxErrors = $errors.Count
            }
            catch {
                $analysis.SyntaxValid = $false
                $analysis.SyntaxErrors = "Parse failed"
            }
        }
        
        $results.PowerShellFiles[$ps1File.Name] = $analysis
    }
    
    return $results
}

# Main diagnostic execution
Write-Host "`n🔍 DevOptimizer Advanced Diagnostic Suite v4.0" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

Write-DiagnosticLog "Starting advanced diagnostic suite" "INFO"

$diagnosticResults = @{
    Timestamp = Get-Date
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    ComputerName = $env:COMPUTERNAME
    UserName = $env:USERNAME
}

# Run diagnostic tests
Write-Host "🧪 Running diagnostic tests..." -ForegroundColor Yellow

$diagnosticResults.PowerShellIntegration = Test-PowerShellIntegration
$diagnosticResults.SystemResources = Test-SystemResources
$diagnosticResults.FileSystemStructure = Test-FileSystemStructure
$diagnosticResults.ScriptIntegrity = Test-ScriptIntegrity
$diagnosticResults.ProcessLocks = Get-ProcessLocks

# Generate summary
$totalIssues = 0
$totalIssues += $diagnosticResults.FileSystemStructure.Issues.Count
$totalIssues += $diagnosticResults.ScriptIntegrity.Issues.Count

Write-Host "`n📊 Diagnostic Summary:" -ForegroundColor Green
Write-Host "=" * 30 -ForegroundColor Green
Write-Host "Total Issues Found: $totalIssues" -ForegroundColor $(if ($totalIssues -gt 0) { "Yellow" } else { "Green" })
Write-Host "Admin Rights: $($diagnosticResults.IsAdmin)" -ForegroundColor $(if ($diagnosticResults.IsAdmin) { "Green" } else { "Yellow" })
Write-Host "PowerShell Integration: $(if ($diagnosticResults.PowerShellIntegration.ExecutionPolicy.Success) { 'OK' } else { 'Issues' })" -ForegroundColor $(if ($diagnosticResults.PowerShellIntegration.ExecutionPolicy.Success) { "Green" } else { "Red" })

# Export results if requested
if ($ExportResults) {
    Write-DiagnosticLog "Exporting diagnostic results to JSON" "INFO"
    $diagnosticResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsPath -Encoding UTF8
    Write-Host "`n📄 Results exported to: $resultsPath" -ForegroundColor Cyan
}

Write-Host "`n📋 Log file: $logPath" -ForegroundColor Cyan
Write-DiagnosticLog "Advanced diagnostic suite completed" "SUCCESS"

# Provide recommendations
Write-Host "`n💡 Recommendations:" -ForegroundColor Magenta
if ($totalIssues -gt 0) {
    Write-Host "  🔧 Review and fix the issues identified above" -ForegroundColor Yellow
}
if (!$diagnosticResults.IsAdmin) {
    Write-Host "  🔑 Run as Administrator for full system access" -ForegroundColor Yellow
}
if ($diagnosticResults.ScriptIntegrity.Issues.Count -gt 0) {
    Write-Host "  🔒 Resolve file locks by closing applications or restarting" -ForegroundColor Yellow
}
Write-Host "  📁 Consider running the directory structure fix utility" -ForegroundColor Green
Write-Host "  🧹 Use the system cleanup tools to resolve conflicts" -ForegroundColor Green

Write-Host "`nDiagnostics completed. Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

