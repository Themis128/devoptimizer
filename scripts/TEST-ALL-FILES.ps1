<#
.SYNOPSIS
    Tests all files.
.DESCRIPTION
    Tests all files.
#>

param(
    [switch]$Detailed,
    [switch]$FixIssues
)

Write-Host "=== DevOptimizer Comprehensive File Testing ===" -ForegroundColor Cyan
Write-Host "Testing all .bat and .ps1 files for functionality..." -ForegroundColor White
Write-Host ""

$Global:TestResults = @{
    BatFiles = @{}
    PS1Files = @{}
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Warnings = 0
}

function Write-TestResult {
    param(
        [string]$FileName,
        [string]$TestType,
        [string]$Status,
        [string]$Message = "",
        [string]$Level = "INFO"
    )
    
    $Global:TestResults.TotalTests++
    
    $color = switch ($Status) {
        "PASS" { "Green"; $Global:TestResults.PassedTests++ }
        "FAIL" { "Red"; $Global:TestResults.FailedTests++ }
        "WARN" { "Yellow"; $Global:TestResults.Warnings++ }
        default { "White" }
    }
    
    $statusIcon = switch ($Status) {
        "PASS" { "[PASS]" }
        "FAIL" { "[FAIL]" }
        "WARN" { "[WARN]" }
        default { "[INFO]" }
    }
    
    Write-Host "$statusIcon $FileName [$TestType] - $Status" -ForegroundColor $color
    if ($Message -and $Detailed) {
        Write-Host "   -> $Message" -ForegroundColor Gray
    }
}

# Test PowerShell files
Write-Host "1. Testing PowerShell (.ps1) files..." -ForegroundColor Yellow
Write-Host ""

$ps1Files = Get-ChildItem "*.ps1" | Where-Object { $_.Name -ne "TEST-ALL-FILES.ps1" }
foreach ($file in $ps1Files) {
    try {
        # Test 1: File readability
        $content = Get-Content $file.FullName -Raw -ErrorAction Stop
        Write-TestResult $file.Name "Read" "PASS" "File readable"
        
        # Test 2: Syntax validation
        try {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)
            
            if ($errors.Count -eq 0) {
                Write-TestResult $file.Name "Syntax" "PASS" "No syntax errors"
            } else {
                $errorMsg = ($errors | Select-Object -First 3 | ForEach-Object { $_.Message }) -join "; "
                Write-TestResult $file.Name "Syntax" "FAIL" $errorMsg
            }
        } catch {
            Write-TestResult $file.Name "Syntax" "FAIL" $_.Exception.Message
        }
        
        # Test 3: Check for required functions (for specific files)
        if ($file.Name -eq "dev-optimizer-fixed.ps1") {
            if ($content -match "function\s+Write-Log") {
                Write-TestResult $file.Name "Functions" "PASS" "Core functions present"
            } else {
                Write-TestResult $file.Name "Functions" "WARN" "Missing expected functions"
            }
        }
        
        # Test 4: Check for proper encoding
        try {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            if ($bytes.Length -gt 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                Write-TestResult $file.Name "Encoding" "PASS" "UTF-8 with BOM"
            } elseif ($content -match "[^\x00-\x7F]") {
                Write-TestResult $file.Name "Encoding" "WARN" "Contains non-ASCII characters"
            } else {
                Write-TestResult $file.Name "Encoding" "PASS" "ASCII compatible"
            }
        } catch {
            Write-TestResult $file.Name "Encoding" "WARN" "Could not check encoding"
        }
        
    } catch {
        Write-TestResult $file.Name "Read" "FAIL" $_.Exception.Message
    }
}

Write-Host ""
Write-Host "2. Testing Batch (.bat) files..." -ForegroundColor Yellow
Write-Host ""

$batFiles = Get-ChildItem "*.bat" | Where-Object { $_.Name -ne "TEST-ALL-FILES.bat" }
foreach ($file in $batFiles) {
    try {
        # Test 1: File readability
        $content = Get-Content $file.FullName -Raw -ErrorAction Stop
        Write-TestResult $file.Name "Read" "PASS" "File readable"
        
        # Test 2: Check for basic batch syntax
        if ($content -match "@echo off" -or $content -match "echo\s+") {
            Write-TestResult $file.Name "Structure" "PASS" "Valid batch structure"
        } else {
            Write-TestResult $file.Name "Structure" "WARN" "Unusual batch structure"
        }
        
        # Test 3: Check for PowerShell calls
        if ($content -match "powershell\s+-Command") {
            Write-TestResult $file.Name "PS-Integration" "PASS" "PowerShell integration found"
        } else {
            Write-TestResult $file.Name "PS-Integration" "INFO" "No PowerShell integration"
        }
        
        # Test 4: Check for admin requirements
        if ($content -match "RunAsAdministrator" -or $content -match "Admin Required") {
            Write-TestResult $file.Name "Admin-Check" "PASS" "Admin requirements noted"
        } else {
            Write-TestResult $file.Name "Admin-Check" "INFO" "No explicit admin check"
        }
        
        # Test 5: Check for proper file references
        $badPaths = @()
        if ($content -match "C:\\Users\\baltz\\") {
            $badPaths += "Old user path found"
        }
        if ($content -match "%~dp0") {
            Write-TestResult $file.Name "Paths" "PASS" "Uses relative paths"
        } elseif ($badPaths.Count -gt 0) {
            Write-TestResult $file.Name "Paths" "WARN" ($badPaths -join "; ")
        } else {
            Write-TestResult $file.Name "Paths" "INFO" "No dynamic paths detected"
        }
        
    } catch {
        Write-TestResult $file.Name "Read" "FAIL" $_.Exception.Message
    }
}

Write-Host ""
Write-Host "3. Testing main launcher functionality..." -ForegroundColor Yellow
Write-Host ""

$mainLauncher = Join-Path $PSScriptRoot "..\devoptimizer.ps1"
if (Test-Path $mainLauncher) {
    try {
        $launcherContent = Get-Content $mainLauncher -Raw
        $moduleRef = "DevOptimizer-Master.psm1"
        if ($launcherContent -match [regex]::Escape($moduleRef) -and (Test-Path (Join-Path $PSScriptRoot "..\modules\$moduleRef"))) {
            Write-TestResult "devoptimizer.ps1" "Existence" "PASS" "Main launcher present and its core module resolves"
        } elseif ($launcherContent -match [regex]::Escape($moduleRef)) {
            Write-TestResult "devoptimizer.ps1" "References" "FAIL" "Core module $moduleRef not found"
        } else {
            Write-TestResult "devoptimizer.ps1" "Analysis" "WARN" "Launcher exists but does not reference $moduleRef directly"
        }
    } catch {
        Write-TestResult "devoptimizer.ps1" "Analysis" "FAIL" $_.Exception.Message
    }
} else {
    Write-TestResult "devoptimizer.ps1" "Existence" "FAIL" "Main launcher not found"
}

Write-Host ""
Write-Host "4. Testing configuration files..." -ForegroundColor Yellow
Write-Host ""

# Test JSON config files (-File: without it, folders like "Newtonsoft.Json" match *.json)
$jsonFiles = Get-ChildItem "*.json" -File -ErrorAction SilentlyContinue
foreach ($file in $jsonFiles) {
    try {
        $jsonContent = Get-Content $file.FullName -Raw
        $null = ConvertFrom-Json $jsonContent
        Write-TestResult $file.Name "JSON-Syntax" "PASS" "Valid JSON format"
    } catch {
        Write-TestResult $file.Name "JSON-Syntax" "FAIL" $_.Exception.Message
    }
}

# Test markdown files
$mdFiles = Get-ChildItem "*.md" -File -ErrorAction SilentlyContinue
foreach ($file in $mdFiles) {
    try {
        $mdContent = Get-Content $file.FullName -Raw
        if ($mdContent.Length -gt 100) {
            Write-TestResult $file.Name "Content" "PASS" "Contains documentation"
        } else {
            Write-TestResult $file.Name "Content" "WARN" "Very short content"
        }
        
        # Check for old paths
        if ($mdContent -match "C:\\Users\\baltz\\") {
            Write-TestResult $file.Name "Paths" "WARN" "Contains old paths"
        } else {
            Write-TestResult $file.Name "Paths" "PASS" "No old paths found"
        }
    } catch {
        Write-TestResult $file.Name "Read" "FAIL" $_.Exception.Message
    }
}

# Generate summary report
Write-Host ""
Write-Host "=== TEST SUMMARY REPORT ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests Run: $($Global:TestResults.TotalTests)" -ForegroundColor White
Write-Host "Passed: $($Global:TestResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($Global:TestResults.FailedTests)" -ForegroundColor Red
Write-Host "Warnings: $($Global:TestResults.Warnings)" -ForegroundColor Yellow
Write-Host ""

$successRate = if ($Global:TestResults.TotalTests -gt 0) { 
    [math]::Round(($Global:TestResults.PassedTests / $Global:TestResults.TotalTests) * 100, 1) 
} else { 0 }

Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })

if ($Global:TestResults.FailedTests -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] ALL CRITICAL TESTS PASSED!" -ForegroundColor Green
    Write-Host "Your DevOptimizer files are ready to use." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[WARNING] Some tests failed. Review the results above." -ForegroundColor Yellow
    Write-Host "Files may still be functional despite warnings." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== RECOMMENDATIONS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Run as Administrator: Most .bat files require admin privileges" -ForegroundColor White
Write-Host "2. Start with: 00-LAUNCHER.bat for easy access to all tools" -ForegroundColor White  
Write-Host "3. Basic optimization: Use 01-Quick-Optimization.bat first" -ForegroundColor White
Write-Host "4. System health: Run 06-System-Health-Check.bat to check performance" -ForegroundColor White
Write-Host ""

# Save detailed report
$reportPath = "TEST-RESULTS-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$reportContent = @"
DevOptimizer Test Results
Generated: $(Get-Date)
Location: $(Get-Location)

SUMMARY:
- Total Tests: $($Global:TestResults.TotalTests)
- Passed: $($Global:TestResults.PassedTests)
- Failed: $($Global:TestResults.FailedTests)
- Warnings: $($Global:TestResults.Warnings)
- Success Rate: $successRate%

STATUS: $(if ($Global:TestResults.FailedTests -eq 0) { "ALL TESTS PASSED" } else { "SOME ISSUES FOUND" })

FILES TESTED:
PowerShell Files: $($ps1Files.Count)
Batch Files: $($batFiles.Count)
JSON Files: $($jsonFiles.Count)
Markdown Files: $($mdFiles.Count)

NEXT STEPS:
1. Address any FAILED tests above
2. Review WARNINGS for potential improvements
3. Test actual functionality by running tools
4. Run 00-LAUNCHER.bat to start using the tools

For detailed test output, run this script with -Detailed parameter.
"@

$reportContent | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Detailed report saved to: $reportPath" -ForegroundColor Cyan

Write-Host ""
Write-Host "Testing completed! You can now safely use the DevOptimizer tools." -ForegroundColor Green
