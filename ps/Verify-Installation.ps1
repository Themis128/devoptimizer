# DevOptimizer Installation Verification Script
# Run with: pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Verify-Installation.ps1"

param(
    [string]$OutputDir = "D:\DevOptimizer\logs",
    [switch]$QuickCheck = $false
)

$ErrorActionPreference = 'Stop'

Write-Host "DevOptimizer Installation Verification" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green

try {
    $VerificationResults = @{
        timestamp = Get-Date
        overall_status = "Unknown"
        checks = @()
        errors = @()
        warnings = @()
        recommendations = @()
    }

    # Check 1: Directory Structure
    Write-Host "`n[1/10] Checking directory structure..." -ForegroundColor Blue

    $RequiredDirs = @(
        "D:\DevOptimizer",
        "D:\DevOptimizer\bin",
        "D:\DevOptimizer\ps",
        "D:\DevOptimizer\py",
        "D:\DevOptimizer\py\devoptimizer_cli",
        "D:\DevOptimizer\tasks",
        "D:\DevOptimizer\configs",
        "D:\DevOptimizer\.env",
        "D:\DevOptimizer\metrics",
        "D:\DevOptimizer\traces",
        "D:\DevOptimizer\logs",
        "D:\DevOptimizer\ai-analysis",
        "D:\DevOptimizer\security"
    )

    $DirCheck = @{
        name = "Directory Structure"
        status = "Pass"
        details = @()
        issues = @()
    }

    foreach ($Dir in $RequiredDirs) {
        if (Test-Path $Dir) {
            $DirCheck.details += "✓ $Dir"
        } else {
            $DirCheck.status = "Fail"
            $DirCheck.issues += "Missing: $Dir"
            $VerificationResults.errors += "Missing directory: $Dir"
        }
    }

    $VerificationResults.checks += $DirCheck

    if ($DirCheck.status -eq "Pass") {
        Write-Host "✓ Directory structure is complete" -ForegroundColor Green
    } else {
        Write-Host "✗ Directory structure has issues" -ForegroundColor Red
        foreach ($Issue in $DirCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Red
        }
    }

    # Check 2: PowerShell Module
    Write-Host "`n[2/10] Checking PowerShell module..." -ForegroundColor Blue

    $ModuleCheck = @{
        name = "PowerShell Module"
        status = "Unknown"
        details = @()
        issues = @()
    }

    try {
        $ModulePath = "D:\DevOptimizer\ps\DevOptimizer.psm1"
        if (Test-Path $ModulePath) {
            Import-Module $ModulePath -Force -ErrorAction Stop
            $ModuleCheck.details += "✓ Module file exists"
            $ModuleCheck.details += "✓ Module imports successfully"

            # Check if functions are available
            $Functions = Get-Command -Module DevOptimizer -ErrorAction SilentlyContinue
            if ($Functions) {
                $ModuleCheck.details += "✓ Functions available: $($Functions.Count)"
                $ModuleCheck.status = "Pass"
            } else {
                $ModuleCheck.status = "Fail"
                $ModuleCheck.issues += "No functions exported"
            }
        } else {
            $ModuleCheck.status = "Fail"
            $ModuleCheck.issues += "Module file not found"
        }
    } catch {
        $ModuleCheck.status = "Fail"
        $ModuleCheck.issues += "Module import failed: $($_.Exception.Message)"
        $VerificationResults.errors += "PowerShell module error: $($_.Exception.Message)"
    }

    $VerificationResults.checks += $ModuleCheck

    if ($ModuleCheck.status -eq "Pass") {
        Write-Host "✓ PowerShell module is working" -ForegroundColor Green
    } else {
        Write-Host "✗ PowerShell module has issues" -ForegroundColor Red
        foreach ($Issue in $ModuleCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Red
        }
    }

    # Check 3: Python CLI
    Write-Host "`n[3/10] Checking Python CLI..." -ForegroundColor Blue

    $PythonCheck = @{
        name = "Python CLI"
        status = "Unknown"
        details = @()
        issues = @()
    }

    try {
        # Check Python installation
        $PythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $PythonCheck.details += "✓ Python found: $PythonVersion"

            # Check virtual environment
            $VenvPath = "D:\DevOptimizer\py\venv"
            if (Test-Path $VenvPath) {
                $PythonCheck.details += "✓ Virtual environment exists"

                # Check CLI package
                $CLIPath = "D:\DevOptimizer\py\devoptimizer_cli"
                if (Test-Path $CLIPath) {
                    $PythonCheck.details += "✓ CLI package exists"

                    # Try to run CLI
                    $CLIResult = python -m devoptimizer_cli --version 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $PythonCheck.details += "✓ CLI executes successfully"
                        $PythonCheck.status = "Pass"
                    } else {
                        $PythonCheck.status = "Fail"
                        $PythonCheck.issues += "CLI execution failed: $CLIResult"
                    }
                } else {
                    $PythonCheck.status = "Fail"
                    $PythonCheck.issues += "CLI package not found"
                }
            } else {
                $PythonCheck.status = "Fail"
                $PythonCheck.issues += "Virtual environment not found"
            }
        } else {
            $PythonCheck.status = "Fail"
            $PythonCheck.issues += "Python not found"
        }
    } catch {
        $PythonCheck.status = "Fail"
        $PythonCheck.issues += "Python check failed: $($_.Exception.Message)"
        $VerificationResults.errors += "Python CLI error: $($_.Exception.Message)"
    }

    $VerificationResults.checks += $PythonCheck

    if ($PythonCheck.status -eq "Pass") {
        Write-Host "✓ Python CLI is working" -ForegroundColor Green
    } else {
        Write-Host "✗ Python CLI has issues" -ForegroundColor Red
        foreach ($Issue in $PythonCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Red
        }
    }

    # Check 4: Configuration Files
    Write-Host "`n[4/10] Checking configuration files..." -ForegroundColor Blue

    $ConfigCheck = @{
        name = "Configuration Files"
        status = "Pass"
        details = @()
        issues = @()
    }

    $RequiredConfigs = @(
        "D:\DevOptimizer\configs\winget-packages.json",
        "D:\DevOptimizer\configs\default-counters.txt"
    )

    foreach ($ConfigFile in $RequiredConfigs) {
        if (Test-Path $ConfigFile) {
            $ConfigCheck.details += "✓ $(Split-Path $ConfigFile -Leaf)"
        } else {
            $ConfigCheck.status = "Fail"
            $ConfigCheck.issues += "Missing: $(Split-Path $ConfigFile -Leaf)"
            $VerificationResults.errors += "Missing config file: $ConfigFile"
        }
    }

    $VerificationResults.checks += $ConfigCheck

    if ($ConfigCheck.status -eq "Pass") {
        Write-Host "✓ Configuration files are present" -ForegroundColor Green
    } else {
        Write-Host "✗ Configuration files have issues" -ForegroundColor Red
        foreach ($Issue in $ConfigCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Red
        }
    }

    # Check 5: Scheduled Tasks
    Write-Host "`n[5/10] Checking scheduled tasks..." -ForegroundColor Blue

    $TaskCheck = @{
        name = "Scheduled Tasks"
        status = "Pass"
        details = @()
        issues = @()
    }

    try {
        $DevOptimizerTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*DevOptimizer*" }

        if ($DevOptimizerTasks) {
            foreach ($Task in $DevOptimizerTasks) {
                $State = $Task.State.ToString()
                $TaskCheck.details += "✓ $($Task.TaskName) - $State"

                if ($State -ne "Ready") {
                    $TaskCheck.issues += "Task not ready: $($Task.TaskName)"
                    $VerificationResults.warnings += "Scheduled task not ready: $($Task.TaskName)"
                }
            }
        } else {
            $TaskCheck.status = "Fail"
            $TaskCheck.issues += "No DevOptimizer tasks found"
            $VerificationResults.warnings += "No scheduled tasks registered"
        }
    } catch {
        $TaskCheck.status = "Fail"
        $TaskCheck.issues += "Failed to check scheduled tasks: $($_.Exception.Message)"
        $VerificationResults.errors += "Scheduled tasks error: $($_.Exception.Message)"
    }

    $VerificationResults.checks += $TaskCheck

    if ($TaskCheck.status -eq "Pass") {
        Write-Host "✓ Scheduled tasks are configured" -ForegroundColor Green
    } else {
        Write-Host "✗ Scheduled tasks have issues" -ForegroundColor Red
        foreach ($Issue in $TaskCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Red
        }
    }

    # Check 6: PowerShell Modules
    Write-Host "`n[6/10] Checking PowerShell modules..." -ForegroundColor Blue

    $ModulesCheck = @{
        name = "PowerShell Modules"
        status = "Pass"
        details = @()
        issues = @()
    }

    $RequiredModules = @(
        "Microsoft.PowerShell.SecretManagement",
        "Microsoft.PowerShell.SecretStore",
        "Microsoft.WinGet.Client"
    )

    foreach ($ModuleName in $RequiredModules) {
        try {
            $Module = Get-Module -Name $ModuleName -ListAvailable
            if ($Module) {
                $ModulesCheck.details += "✓ $ModuleName (v$($Module.Version))"
            } else {
                $ModulesCheck.status = "Fail"
                $ModulesCheck.issues += "Missing: $ModuleName"
                $VerificationResults.errors += "Missing PowerShell module: $ModuleName"
            }
        } catch {
            $ModulesCheck.status = "Fail"
            $ModulesCheck.issues += "Error checking: $ModuleName"
        }
    }

    $VerificationResults.checks += $ModulesCheck

    if ($ModulesCheck.status -eq "Pass") {
        Write-Host "✓ PowerShell modules are installed" -ForegroundColor Green
    } else {
        Write-Host "✗ PowerShell modules have issues" -ForegroundColor Red
        foreach ($Issue in $ModulesCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Red
        }
    }

    # Check 7: SecretManagement Vault
    Write-Host "`n[7/10] Checking SecretManagement vault..." -ForegroundColor Blue

    $VaultCheck = @{
        name = "SecretManagement Vault"
        status = "Unknown"
        details = @()
        issues = @()
    }

    try {
        $Vaults = Get-SecretVault -ErrorAction SilentlyContinue
        if ($Vaults -and $Vaults.Name -contains 'DevOptimizerVault') {
            $VaultCheck.details += "✓ DevOptimizerVault exists"
            $VaultCheck.status = "Pass"
        } else {
            $VaultCheck.status = "Fail"
            $VaultCheck.issues += "DevOptimizerVault not found"
            $VerificationResults.warnings += "SecretManagement vault not configured"
        }
    } catch {
        $VaultCheck.status = "Fail"
        $VaultCheck.issues += "Failed to check vault: $($_.Exception.Message)"
        $VerificationResults.errors += "Vault check error: $($_.Exception.Message)"
    }

    $VerificationResults.checks += $VaultCheck

    if ($VaultCheck.status -eq "Pass") {
        Write-Host "✓ SecretManagement vault is configured" -ForegroundColor Green
    } else {
        Write-Host "✗ SecretManagement vault has issues" -ForegroundColor Red
        foreach ($Issue in $VaultCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Red
        }
    }

    # Check 8: Desktop Shortcuts
    Write-Host "`n[8/10] Checking desktop shortcuts..." -ForegroundColor Blue

    $ShortcutCheck = @{
        name = "Desktop Shortcuts"
        status = "Pass"
        details = @()
        issues = @()
    }

    try {
        $DesktopPath = [Environment]::GetFolderPath("Desktop")
        $ShortcutNames = @(
            "DevOptimizer CLI.lnk",
            "DevOptimizer Metrics.lnk",
            "DevOptimizer Analysis.lnk"
        )

        foreach ($ShortcutName in $ShortcutNames) {
            $ShortcutPath = Join-Path $DesktopPath $ShortcutName
            if (Test-Path $ShortcutPath) {
                $ShortcutCheck.details += "✓ $ShortcutName"
            } else {
                $ShortcutCheck.issues += "Missing: $ShortcutName"
                $VerificationResults.warnings += "Desktop shortcut missing: $ShortcutName"
            }
        }
    } catch {
        $ShortcutCheck.status = "Fail"
        $ShortcutCheck.issues += "Failed to check shortcuts: $($_.Exception.Message)"
    }

    $VerificationResults.checks += $ShortcutCheck

    if ($ShortcutCheck.status -eq "Pass") {
        Write-Host "✓ Desktop shortcuts are present" -ForegroundColor Green
    } else {
        Write-Host "⚠ Desktop shortcuts have issues" -ForegroundColor Yellow
        foreach ($Issue in $ShortcutCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Yellow
        }
    }

    # Check 9: Environment Variables
    Write-Host "`n[9/10] Checking environment variables..." -ForegroundColor Blue

    $EnvCheck = @{
        name = "Environment Variables"
        status = "Pass"
        details = @()
        issues = @()
    }

    $RequiredEnvVars = @(
        "DEVOPTIMIZER_ROOT",
        "DEVOPTIMIZER_PYTHON",
        "DEVOPTIMIZER_SCRIPTS",
        "DEVOPTIMIZER_BIN",
        "DEVOPTIMIZER_CONFIGS"
    )

    foreach ($EnvVar in $RequiredEnvVars) {
        if (Test-Path "Env:\$EnvVar") {
            $EnvCheck.details += "✓ $EnvVar = $((Get-Item "Env:\$EnvVar").Value)"
        } else {
            $EnvCheck.issues += "Missing: $EnvVar"
            $VerificationResults.warnings += "Environment variable missing: $EnvVar"
        }
    }

    $VerificationResults.checks += $EnvCheck

    if ($EnvCheck.status -eq "Pass") {
        Write-Host "✓ Environment variables are set" -ForegroundColor Green
    } else {
        Write-Host "⚠ Environment variables have issues" -ForegroundColor Yellow
        foreach ($Issue in $EnvCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Yellow
        }
    }

    # Check 10: Ollama (Optional)
    Write-Host "`n[10/10] Checking Ollama (optional)..." -ForegroundColor Blue

    $OllamaCheck = @{
        name = "Ollama AI Models"
        status = "Unknown"
        details = @()
        issues = @()
    }

    try {
        $OllamaVersion = ollama --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $OllamaCheck.details += "✓ Ollama found: $OllamaVersion"

            # Check for models
            $Models = ollama list 2>&1
            if ($Models -match "llama3.1|codellama") {
                $OllamaCheck.details += "✓ AI models available"
                $OllamaCheck.status = "Pass"
            } else {
                $OllamaCheck.status = "Fail"
                $OllamaCheck.issues += "No AI models found. Run: ollama pull llama3.1"
                $VerificationResults.warnings += "Ollama models not installed"
            }
        } else {
            $OllamaCheck.status = "Fail"
            $OllamaCheck.issues += "Ollama not found. Install from https://ollama.ai"
            $VerificationResults.warnings += "Ollama not installed"
        }
    } catch {
        $OllamaCheck.status = "Fail"
        $OllamaCheck.issues += "Ollama check failed: $($_.Exception.Message)"
        $VerificationResults.warnings += "Ollama not available"
    }

    $VerificationResults.checks += $OllamaCheck

    if ($OllamaCheck.status -eq "Pass") {
        Write-Host "✓ Ollama and AI models are ready" -ForegroundColor Green
    } else {
        Write-Host "⚠ Ollama has issues (optional for basic functionality)" -ForegroundColor Yellow
        foreach ($Issue in $OllamaCheck.issues) {
            Write-Host "  - $Issue" -ForegroundColor Yellow
        }
    }

    # Calculate overall status
    $PassedChecks = ($VerificationResults.checks | Where-Object { $_.status -eq "Pass" }).Count
    $TotalChecks = $VerificationResults.checks.Count
    $CriticalErrors = $VerificationResults.errors.Count

    if ($CriticalErrors -eq 0 -and $PassedChecks -eq $TotalChecks) {
        $VerificationResults.overall_status = "Excellent"
    } elseif ($CriticalErrors -eq 0 -and $PassedChecks -ge ($TotalChecks * 0.8)) {
        $VerificationResults.overall_status = "Good"
    } elseif ($CriticalErrors -le 2) {
        $VerificationResults.overall_status = "Fair"
    } else {
        $VerificationResults.overall_status = "Poor"
    }

    # Generate recommendations
    if ($VerificationResults.errors.Count -gt 0) {
        $VerificationResults.recommendations += "Fix critical errors before using DevOptimizer"
    }

    if ($VerificationResults.warnings.Count -gt 0) {
        $VerificationResults.recommendations += "Address warnings for optimal functionality"
    }

    if ($OllamaCheck.status -eq "Fail") {
        $VerificationResults.recommendations += "Install Ollama for AI analysis capabilities"
    }

    if ($ShortcutCheck.issues.Count -gt 0) {
        $VerificationResults.recommendations += "Run Bootstrap-DevEnvironment.ps1 to create desktop shortcuts"
    }

    if ($EnvCheck.issues.Count -gt 0) {
        $VerificationResults.recommendations += "Restart PowerShell to load environment variables"
    }

    # Save results
    $OutputDir = "D:\DevOptimizer\logs"
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $ResultsFile = Join-Path $OutputDir "verification_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $VerificationResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $ResultsFile -Encoding UTF8

    # Display final summary
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "VERIFICATION SUMMARY" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Green

    Write-Host "Overall Status: $($VerificationResults.overall_status)" -ForegroundColor White
    Write-Host "Checks Passed: $PassedChecks/$TotalChecks" -ForegroundColor White
    Write-Host "Critical Errors: $($VerificationResults.errors.Count)" -ForegroundColor Red
    Write-Host "Warnings: $($VerificationResults.warnings.Count)" -ForegroundColor Yellow

    if ($VerificationResults.recommendations.Count -gt 0) {
        Write-Host "`nRecommendations:" -ForegroundColor Blue
        foreach ($Recommendation in $VerificationResults.recommendations) {
            Write-Host "- $Recommendation" -ForegroundColor White
        }
    }

    Write-Host "`nResults saved to: $ResultsFile" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Green

    # Exit with appropriate code
    if ($CriticalErrors -eq 0) {
        exit 0
    } else {
        exit 1
    }

} catch {
    Write-Error "Verification failed: $_"
    exit 1
}
