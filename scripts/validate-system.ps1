<#
.SYNOPSIS
    DevOptimizer automation script: validate-system.
.DESCRIPTION
    DevOptimizer automation script: validate-system.
#>

# DevOptimizer System Validation Script
# Comprehensive testing of all DevOptimizer functionality

param(
    [switch]$Quick,
    [switch]$Detailed,
    [switch]$Fix,
    [switch]$Report
)

$DevOptimizerPath = "D:\DevOptimizer"
$LogFile = "$DevOptimizerPath\logs\validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ReportFile = "$DevOptimizerPath\validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"

# Ensure logs directory exists
$LogDir = Split-Path $LogFile -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

$Global:TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Warnings = 0
    StartTime = Get-Date
    Tests = @()
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "DEBUG" { "Cyan" }
    }

    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Add-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message,
        [string]$Details = ""
    )

    $Global:TestResults.Total++
    $Global:TestResults.Tests += @{
        Name = $TestName
        Status = $Status
        Message = $Message
        Details = $Details
        Timestamp = Get-Date
    }

    switch ($Status) {
        "PASS" {
            $Global:TestResults.Passed++
            Write-Log "${TestName}: PASS - ${Message}" -Level "SUCCESS"
        }
        "FAIL" {
            $Global:TestResults.Failed++
            Write-Log "${TestName}: FAIL - ${Message}" -Level "ERROR"
        }
        "WARN" {
            $Global:TestResults.Warnings++
            Write-Log "${TestName}: WARN - ${Message}" -Level "WARNING"
        }
    }
}

function Test-DirectoryStructure {
    Write-Log "Testing directory structure..." -Level "INFO"

    $requiredDirs = @(
        "logs",
        "backup",
        "config",
        "scripts"
    )

    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $DevOptimizerPath $dir
        if (Test-Path $dirPath) {
            Add-TestResult -TestName "Directory: $dir" -Status "PASS" -Message "Directory exists"
        } else {
            Add-TestResult -TestName "Directory: $dir" -Status "WARN" -Message "Directory missing" -Details "Creating directory"
            if ($Fix) {
                New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
                Add-TestResult -TestName "Directory: $dir (Fixed)" -Status "PASS" -Message "Directory created"
            }
        }
    }
}

function Test-CoreFiles {
    Write-Log "Testing core files..." -Level "INFO"

    $coreFiles = @(
        "devoptimizer.ps1",
        "DevOptimizer.bat",
        "modules\DevOptimizer-Master.psm1",
        "modules\DevOptimizer-Config.psm1",
        "config\devoptimizer-config.json",
        "config\hub-registry.json",
        "scripts\UNIFIED-LAUNCHER.ps1",
        "scripts\Hub-Registry.ps1"
    )

    foreach ($file in $coreFiles) {
        $filePath = Join-Path $DevOptimizerPath $file
        if (Test-Path $filePath) {
            Add-TestResult -TestName "Core File: $file" -Status "PASS" -Message "File exists"
        } else {
            Add-TestResult -TestName "Core File: $file" -Status "FAIL" -Message "File missing"
        }
    }
}

function Test-PowerShellScripts {
    Write-Log "Testing PowerShell scripts..." -Level "INFO"

    $psFiles = Get-ChildItem -Path $DevOptimizerPath -Filter "*.ps1" | Where-Object { $_.Name -ne "validate-system.ps1" }

    foreach ($file in $psFiles) {
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$null)
            Add-TestResult -TestName "PowerShell: $($file.Name)" -Status "PASS" -Message "Syntax valid"
        }
        catch {
            Add-TestResult -TestName "PowerShell: $($file.Name)" -Status "WARN" -Message "Syntax issues detected" -Details $_.Exception.Message
        }
    }
}

function Test-BatchFiles {
    Write-Log "Testing batch files..." -Level "INFO"

    $batFiles = Get-ChildItem -Path $DevOptimizerPath -Filter "*.bat" | Where-Object { $_.Name -notlike "00-SETUP*" }

    foreach ($file in $batFiles) {
        $content = Get-Content $file.FullName -Raw
        if ($content -match "call.*\.bat") {
            Add-TestResult -TestName "Batch: $($file.Name)" -Status "PASS" -Message "Contains batch calls"
        } elseif ($content -match "powershell.*\.ps1") {
            Add-TestResult -TestName "Batch: $($file.Name)" -Status "PASS" -Message "Contains PowerShell calls"
        } else {
            Add-TestResult -TestName "Batch: $($file.Name)" -Status "WARN" -Message "No external calls detected"
        }
    }
}

function Test-PathConfiguration {
    Write-Log "Testing PATH configuration..." -Level "INFO"

    # Accept either machine PATH or user PATH (user is standard for per-user installs)
    $pathMachine = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    $pathUser = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($pathMachine -like "*$DevOptimizerPath*") {
        Add-TestResult -TestName "PATH Configuration" -Status "PASS" -Message "DevOptimizer in system PATH"
    } elseif ($pathUser -like "*$DevOptimizerPath*") {
        Add-TestResult -TestName "PATH Configuration" -Status "PASS" -Message "DevOptimizer in user PATH"
    } else {
        Add-TestResult -TestName "PATH Configuration" -Status "FAIL" -Message "DevOptimizer not in system or user PATH"
    }

    # Test if devoptimizer.ps1 is reachable from PATH
    try {
        $null = Get-Command "devoptimizer.ps1" -ErrorAction Stop
        Add-TestResult -TestName "Global Access" -Status "PASS" -Message "devoptimizer.ps1 accessible globally"
    }
    catch {
        Add-TestResult -TestName "Global Access" -Status "WARN" -Message "devoptimizer.ps1 not accessible globally (PATH refresh may be needed)"
    }
}

function Test-Functionality {
    Write-Log "Testing core functionality..." -Level "INFO"

    # Test launcher (current unified entry point)
    $launcherPath = Join-Path $DevOptimizerPath "devoptimizer.ps1"
    if (Test-Path $launcherPath) {
        Add-TestResult -TestName "Launcher Exists" -Status "PASS" -Message "Main launcher found"
    } else {
        Add-TestResult -TestName "Launcher Exists" -Status "FAIL" -Message "Main launcher missing"
    }

    # Test optimizer script (legacy location moved to scripts\)
    $optimizerPath = Join-Path $DevOptimizerPath "scripts\optimizer.ps1"
    if (Test-Path $optimizerPath) {
        try {
            $result = & powershell -ExecutionPolicy Bypass -File $optimizerPath -Status
            Add-TestResult -TestName "Optimizer Script" -Status "PASS" -Message "Script executes successfully"
        }
        catch {
            Add-TestResult -TestName "Optimizer Script" -Status "WARN" -Message "Script execution issues" -Details $_.Exception.Message
        }
    }
}

function Test-SystemRequirements {
    Write-Log "Testing system requirements..." -Level "INFO"

    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -ge 10) {
        Add-TestResult -TestName "Windows Version" -Status "PASS" -Message "Windows 10 or later"
    } else {
        Add-TestResult -TestName "Windows Version" -Status "WARN" -Message "Older Windows version detected"
    }

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 5) {
        Add-TestResult -TestName "PowerShell Version" -Status "PASS" -Message "PowerShell 5.0 or later"
    } else {
        Add-TestResult -TestName "PowerShell Version" -Status "WARN" -Message "Older PowerShell version"
    }

    # Check admin privileges
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Add-TestResult -TestName "Admin Privileges" -Status "PASS" -Message "Running with admin privileges"
    } else {
        Add-TestResult -TestName "Admin Privileges" -Status "WARN" -Message "Not running with admin privileges"
    }
}

function Generate-Report {
    Write-Log "Generating validation report..." -Level "INFO"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>DevOptimizer Validation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .summary { background-color: #ecf0f1; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .test-result { margin: 5px 0; padding: 10px; border-radius: 3px; }
        .pass { background-color: #d5f4e6; border-left: 4px solid #27ae60; }
        .fail { background-color: #fadbd8; border-left: 4px solid #e74c3c; }
        .warn { background-color: #fef9e7; border-left: 4px solid #f39c12; }
        .stats { display: flex; justify-content: space-around; margin: 20px 0; }
        .stat-box { text-align: center; padding: 15px; border-radius: 5px; }
        .stat-pass { background-color: #27ae60; color: white; }
        .stat-fail { background-color: #e74c3c; color: white; }
        .stat-warn { background-color: #f39c12; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>DevOptimizer System Validation Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    </div>

    <div class="summary">
        <h2>Summary</h2>
        <div class="stats">
            <div class="stat-box stat-pass">
                <h3>$($Global:TestResults.Passed)</h3>
                <p>Passed</p>
            </div>
            <div class="stat-box stat-fail">
                <h3>$($Global:TestResults.Failed)</h3>
                <p>Failed</p>
            </div>
            <div class="stat-box stat-warn">
                <h3>$($Global:TestResults.Warnings)</h3>
                <p>Warnings</p>
            </div>
        </div>
        <p><strong>Success Rate:</strong> $([math]::Round(($Global:TestResults.Passed / $Global:TestResults.Total) * 100, 1))%</p>
        <p><strong>Total Tests:</strong> $($Global:TestResults.Total)</p>
    </div>

    <h2>Test Results</h2>
"@

    foreach ($test in $Global:TestResults.Tests) {
        $statusClass = $test.Status.ToLower()
        $html += @"
    <div class="test-result $statusClass">
        <h4>$($test.Name)</h4>
        <p><strong>Status:</strong> $($test.Status)</p>
        <p><strong>Message:</strong> $($test.Message)</p>
"@
        if ($test.Details) {
            $html += "<p><strong>Details:</strong> $($test.Details)</p>"
        }
        $html += "<p><strong>Time:</strong> $($test.Timestamp)</p></div>"
    }

    $html += @"
    <div class="summary">
        <h2>Recommendations</h2>
"@

    if ($Global:TestResults.Failed -gt 0) {
        $html += "<p>❌ <strong>Critical Issues Found:</strong> Please address failed tests before using the system.</p>"
    }

    if ($Global:TestResults.Warnings -gt 0) {
        $html += "<p>⚠️ <strong>Warnings:</strong> Consider addressing warning items for optimal performance.</p>"
    }

    if ($Global:TestResults.Failed -eq 0 -and $Global:TestResults.Warnings -eq 0) {
        $html += "<p>✅ <strong>All Tests Passed:</strong> System is ready for production use!</p>"
    }

    $html += "</div></body></html>"

    $html | Out-File -FilePath $ReportFile -Encoding UTF8
    Write-Log "Report generated: $ReportFile" -Level "SUCCESS"
}

# Main execution
Write-Log "=== DevOptimizer System Validation ===" -Level "INFO"
Write-Log "Mode: $(if ($Quick) { 'Quick' } elseif ($Detailed) { 'Detailed' } else { 'Standard' })" -Level "INFO"

# Run tests
Test-DirectoryStructure
Test-CoreFiles
Test-PathConfiguration

if (-not $Quick) {
    Test-PowerShellScripts
    Test-BatchFiles
    Test-Functionality
    Test-SystemRequirements
}

# Calculate results
$successRate = [math]::Round(($Global:TestResults.Passed / $Global:TestResults.Total) * 100, 1)
$endTime = Get-Date
$duration = $endTime - $Global:TestResults.StartTime

Write-Log "=== Validation Complete ===" -Level "INFO"
Write-Log "Total Tests: $($Global:TestResults.Total)" -Level "INFO"
Write-Log "Passed: $($Global:TestResults.Passed)" -Level "SUCCESS"
Write-Log "Failed: $($Global:TestResults.Failed)" -Level "$(if ($Global:TestResults.Failed -gt 0) { 'ERROR' } else { 'INFO' })"
Write-Log "Warnings: $($Global:TestResults.Warnings)" -Level "$(if ($Global:TestResults.Warnings -gt 0) { 'WARNING' } else { 'INFO' })"
Write-Log "Success Rate: $successRate%" -Level "INFO"
Write-Log "Duration: $($duration.TotalSeconds) seconds" -Level "INFO"

if ($Report) {
    Generate-Report
}

Write-Log "Log saved to: $LogFile" -Level "INFO"

# Return appropriate exit code
if ($Global:TestResults.Failed -gt 0) {
    exit 1
} else {
    exit 0
}
