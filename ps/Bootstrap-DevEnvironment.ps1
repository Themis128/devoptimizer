# DevOptimizer Development Environment Bootstrap Script
# Run with: pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Bootstrap-DevEnvironment.ps1"

param(
    [string]$PackageFile = "D:\DevOptimizer\configs\winget-packages.json",
    [string]$OutputDir = "D:\DevOptimizer\logs",
    [switch]$InstallTools = $true,
    [switch]$SetupPython = $true,
    [switch]$SetupGit = $true,
    [switch]$ConfigureEnvironment = $true,
    [switch]$CreateShortcuts = $true,
    [switch]$VerifyInstallations = $true
)

$ErrorActionPreference = 'Stop'

Write-Host "Starting DevOptimizer Development Environment Bootstrap..." -ForegroundColor Green
Write-Host "Package File: $PackageFile" -ForegroundColor Yellow
Write-Host "Output Directory: $OutputDir" -ForegroundColor Yellow

try {
    # Create output directory
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $BootstrapResults = @{
        timestamp = Get-Date
        packages_installed = @()
        python_setup = @{}
        git_setup = @{}
        environment_config = @{}
        shortcuts_created = @()
        verification_results = @{}
        errors = @()
    }

    # Check prerequisites
    Write-Host "`nChecking prerequisites..." -ForegroundColor Blue

    # Check if running as administrator
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $IsAdmin) {
        Write-Warning "Not running as administrator. Some installations may fail."
    }

    # Check winget availability
    $WingetAvailable = $false
    try {
        $WingetVersion = winget --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $WingetAvailable = $true
            Write-Host "✓ winget is available" -ForegroundColor Green
        }
    } catch {
        Write-Warning "winget not available"
    }

    # Check Chocolatey availability
    $ChocolateyAvailable = $false
    try {
        $ChocoVersion = choco --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $ChocolateyAvailable = $true
            Write-Host "✓ Chocolatey is available" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Chocolatey not available"
    }

    if (-not $WingetAvailable -and -not $ChocolateyAvailable) {
        Write-Error "No package managers available (winget or Chocolatey)"
        exit 1
    }

    # Install Development Tools
    if ($InstallTools -and (Test-Path $PackageFile)) {
        Write-Host "`nInstalling development tools..." -ForegroundColor Blue

        try {
            $PackagesConfig = Get-Content $PackageFile | ConvertFrom-Json
            $Packages = $PackagesConfig.packages

            Write-Host "Found $($Packages.Count) packages to install" -ForegroundColor Yellow

            foreach ($Package in $Packages) {
                $PackageName = $Package.name
                $PackageId = $Package.id
                $Category = $Package.category

                Write-Host "Installing $PackageName..." -ForegroundColor Yellow

                $InstallSuccess = $false
                $InstallMethod = ""
                $InstallError = ""

                # Try winget first
                if ($WingetAvailable) {
                    try {
                        $WingetCmd = @("winget", "install", $PackageId, "--accept-source-agreements", "--accept-package-agreements", "--silent")
                        $WingetResult = & $WingetCmd[0] $WingetCmd[1..($WingetCmd.Length-1)] 2>&1

                        if ($LASTEXITCODE -eq 0) {
                            $InstallSuccess = $true
                            $InstallMethod = "winget"
                            Write-Host "✓ Installed $PackageName (winget)" -ForegroundColor Green
                        } else {
                            $InstallError = "winget failed: $WingetResult"
                        }
                    } catch {
                        $InstallError = "winget error: $($_.Exception.Message)"
                    }
                }

                # Try Chocolatey if winget failed
                if (-not $InstallSuccess -and $ChocolateyAvailable) {
                    try {
                        # Convert winget ID to Chocolatey package name (simplified)
                        $ChocoName = $PackageId.Split('.')[-1].ToLower()

                        $ChocoCmd = @("choco", "install", $ChocoName, "-y")
                        $ChocoResult = & $ChocoCmd[0] $ChocoCmd[1..($ChocoCmd.Length-1)] 2>&1

                        if ($LASTEXITCODE -eq 0) {
                            $InstallSuccess = $true
                            $InstallMethod = "chocolatey"
                            Write-Host "✓ Installed $PackageName (Chocolatey)" -ForegroundColor Green
                        } else {
                            $InstallError += " | chocolatey failed: $ChocoResult"
                        }
                    } catch {
                        $InstallError += " | chocolatey error: $($_.Exception.Message)"
                    }
                }

                # Record installation result
                $BootstrapResults.packages_installed += @{
                    name = $PackageName
                    id = $PackageId
                    category = $Category
                    method = $InstallMethod
                    status = if ($InstallSuccess) { "success" } else { "failed" }
                    error = $InstallError
                }

                if (-not $InstallSuccess) {
                    Write-Warning "Failed to install $PackageName`: $InstallError"
                }
            }

        } catch {
            $BootstrapResults.errors += @{
                action = "package_installation"
                error = $_.Exception.Message
            }
            Write-Error "Package installation failed: $_"
        }
    }

    # Setup Python Environment
    if ($SetupPython) {
        Write-Host "`nSetting up Python environment..." -ForegroundColor Blue

        try {
            $PythonSetup = @{
                python_installed = $false
                python_version = ""
                pip_available = $false
                venv_created = $false
                dependencies_installed = $false
                errors = @()
            }

            # Check if Python is installed
            try {
                $PythonVersion = python --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $PythonSetup.python_installed = $true
                    $PythonSetup.python_version = $PythonVersion
                    Write-Host "✓ Python found: $PythonVersion" -ForegroundColor Green
                }
            } catch {
                Write-Warning "Python not found, attempting to install..."

                # Try to install Python using winget
                if ($WingetAvailable) {
                    try {
                        Write-Host "Installing Python via winget..." -ForegroundColor Yellow
                        winget install Python.Python.3.12 --accept-source-agreements --accept-package-agreements --silent

                        if ($LASTEXITCODE -eq 0) {
                            $PythonSetup.python_installed = $true
                            $PythonSetup.python_version = "3.12.x"
                            Write-Host "✓ Python installed via winget" -ForegroundColor Green
                        }
                    } catch {
                        $PythonSetup.errors += "Failed to install Python: $($_.Exception.Message)"
                    }
                }
            }

            # Check pip availability
            if ($PythonSetup.python_installed) {
                try {
                    $PipVersion = pip --version 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $PythonSetup.pip_available = $true
                        Write-Host "✓ pip is available" -ForegroundColor Green
                    }
                } catch {
                    $PythonSetup.errors += "pip not available"
                }
            }

            # Create virtual environment
            if ($PythonSetup.python_installed) {
                try {
                    $VenvPath = "D:\DevOptimizer\py\venv"
                    Write-Host "Creating virtual environment at: $VenvPath" -ForegroundColor Yellow

                    python -m venv $VenvPath

                    if (Test-Path $VenvPath) {
                        $PythonSetup.venv_created = $true
                        Write-Host "✓ Virtual environment created" -ForegroundColor Green
                    }
                } catch {
                    $PythonSetup.errors += "Failed to create virtual environment: $($_.Exception.Message)"
                }
            }

            # Install Python dependencies
            if ($PythonSetup.pip_available) {
                try {
                    $RequirementsFile = "D:\DevOptimizer\py\requirements.txt"
                    if (Test-Path $RequirementsFile) {
                        Write-Host "Installing Python dependencies..." -ForegroundColor Yellow

                        if ($PythonSetup.venv_created) {
                            $PipPath = Join-Path $VenvPath "Scripts\pip.exe"
                            if (Test-Path $PipPath) {
                                & $PipPath install -r $RequirementsFile
                            } else {
                                pip install -r $RequirementsFile
                            }
                        } else {
                            pip install -r $RequirementsFile
                        }

                        $PythonSetup.dependencies_installed = $true
                        Write-Host "✓ Python dependencies installed" -ForegroundColor Green
                    }
                } catch {
                    $PythonSetup.errors += "Failed to install dependencies: $($_.Exception.Message)"
                }
            }

            $BootstrapResults.python_setup = $PythonSetup

        } catch {
            $BootstrapResults.errors += @{
                action = "python_setup"
                error = $_.Exception.Message
            }
            Write-Error "Python setup failed: $_"
        }
    }

    # Setup Git Configuration
    if ($SetupGit) {
        Write-Host "`nSetting up Git configuration..." -ForegroundColor Blue

        try {
            $GitSetup = @{
                git_installed = $false
                git_version = ""
                config_set = $false
                errors = @()
            }

            # Check if Git is installed
            try {
                $GitVersion = git --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $GitSetup.git_installed = $true
                    $GitSetup.git_version = $GitVersion
                    Write-Host "✓ Git found: $GitVersion" -ForegroundColor Green
                }
            } catch {
                Write-Warning "Git not found, attempting to install..."

                # Try to install Git using winget
                if ($WingetAvailable) {
                    try {
                        Write-Host "Installing Git via winget..." -ForegroundColor Yellow
                        winget install Git.Git --accept-source-agreements --accept-package-agreements --silent

                        if ($LASTEXITCODE -eq 0) {
                            $GitSetup.git_installed = $true
                            $GitSetup.git_version = "latest"
                            Write-Host "✓ Git installed via winget" -ForegroundColor Green
                        }
                    } catch {
                        $GitSetup.errors += "Failed to install Git: $($_.Exception.Message)"
                    }
                }
            }

            # Configure Git
            if ($GitSetup.git_installed) {
                try {
                    # Set basic Git configurations
                    $GitConfigs = @(
                        @("config", "--global", "init.defaultBranch", "main"),
                        @("config", "--global", "pull.rebase", "true"),
                        @("config", "--global", "push.default", "simple"),
                        @("config", "--global", "core.autocrlf", "true"),
                        @("config", "--global", "core.safecrlf", "true")
                    )

                    foreach ($Config in $GitConfigs) {
                        try {
                            & git $Config
                        } catch {
                            $GitSetup.errors += "Failed to set Git config: $($Config -join ' ')"
                        }
                    }

                    $GitSetup.config_set = $true
                    Write-Host "✓ Git configuration set" -ForegroundColor Green

                } catch {
                    $GitSetup.errors += "Failed to configure Git: $($_.Exception.Message)"
                }
            }

            $BootstrapResults.git_setup = $GitSetup

        } catch {
            $BootstrapResults.errors += @{
                action = "git_setup"
                error = $_.Exception.Message
            }
            Write-Error "Git setup failed: $_"
        }
    }

    # Configure Environment Variables
    if ($ConfigureEnvironment) {
        Write-Host "`nConfiguring environment variables..." -ForegroundColor Blue

        try {
            $EnvConfig = @{
                devoptimizer_root = "D:\DevOptimizer"
                python_path = "D:\DevOptimizer\py"
                scripts_path = "D:\DevOptimizer\ps"
                bin_path = "D:\DevOptimizer\bin"
                configs_path = "D:\DevOptimizer\configs"
                variables_set = @()
                errors = @()
            }

            # Set environment variables for current session
            $env:DEVOPTIMIZER_ROOT = $EnvConfig.devoptimizer_root
            $env:DEVOPTIMIZER_PYTHON = $EnvConfig.python_path
            $env:DEVOPTIMIZER_SCRIPTS = $EnvConfig.scripts_path
            $env:DEVOPTIMIZER_BIN = $EnvConfig.bin_path
            $env:DEVOPTIMIZER_CONFIGS = $EnvConfig.configs_path

            $EnvConfig.variables_set = @(
                "DEVOPTIMIZER_ROOT",
                "DEVOPTIMIZER_PYTHON",
                "DEVOPTIMIZER_SCRIPTS",
                "DEVOPTIMIZER_BIN",
                "DEVOPTIMIZER_CONFIGS"
            )

            Write-Host "✓ Environment variables set for current session" -ForegroundColor Green

            # Create .env file for persistence
            $EnvFile = "D:\DevOptimizer\.env\environment.env"
            $EnvContent = @"
# DevOptimizer Environment Variables
DEVOPTIMIZER_ROOT=D:\DevOptimizer
DEVOPTIMIZER_PYTHON=D:\DevOptimizer\py
DEVOPTIMIZER_SCRIPTS=D:\DevOptimizer\ps
DEVOPTIMIZER_BIN=D:\DevOptimizer\bin
DEVOPTIMIZER_CONFIGS=D:\DevOptimizer\configs

# Add to PATH
PATH=%DEVOPTIMIZER_SCRIPTS%;%DEVOPTIMIZER_BIN%;%DEVOPTIMIZER_PYTHON%\venv\Scripts;%PATH%
"@

            $EnvFile | Out-File -FilePath $EnvFile -Encoding UTF8
            Write-Host "✓ Environment file created: $EnvFile" -ForegroundColor Green

            $BootstrapResults.environment_config = $EnvConfig

        } catch {
            $BootstrapResults.errors += @{
                action = "environment_config"
                error = $_.Exception.Message
            }
            Write-Error "Environment configuration failed: $_"
        }
    }

    # Create Desktop Shortcuts
    if ($CreateShortcuts) {
        Write-Host "`nCreating desktop shortcuts..." -ForegroundColor Blue

        try {
            $Shortcuts = @(
                @{
                    name = "DevOptimizer CLI"
                    target = "D:\DevOptimizer\py\venv\Scripts\python.exe"
                    arguments = "-m devoptimizer_cli"
                    icon = "D:\DevOptimizer\py\venv\Scripts\python.exe"
                },
                @{
                    name = "DevOptimizer Metrics"
                    target = "D:\DevOptimizer\py\venv\Scripts\python.exe"
                    arguments = "-m devoptimizer_cli metrics collect"
                    icon = "D:\DevOptimizer\py\venv\Scripts\python.exe"
                },
                @{
                    name = "DevOptimizer Analysis"
                    target = "D:\DevOptimizer\py\venv\Scripts\python.exe"
                    arguments = "-m devoptimizer_cli analyze system"
                    icon = "D:\DevOptimizer\py\venv\Scripts\python.exe"
                }
            )

            $DesktopPath = [Environment]::GetFolderPath("Desktop")

            foreach ($Shortcut in $Shortcuts) {
                try {
                    $ShortcutPath = Join-Path $DesktopPath "$($Shortcut.name).lnk"

                    $WshShell = New-Object -ComObject WScript.Shell
                    $ShortcutObj = $WshShell.CreateShortcut($ShortcutPath)
                    $ShortcutObj.TargetPath = $Shortcut.target
                    $ShortcutObj.Arguments = $Shortcut.arguments
                    $ShortcutObj.IconLocation = $Shortcut.icon
                    $ShortcutObj.WorkingDirectory = "D:\DevOptimizer"
                    $ShortcutObj.Save()

                    $BootstrapResults.shortcuts_created += @{
                        name = $Shortcut.name
                        path = $ShortcutPath
                        status = "success"
                    }

                    Write-Host "✓ Created shortcut: $($Shortcut.name)" -ForegroundColor Green

                } catch {
                    $BootstrapResults.errors += @{
                        action = "create_shortcut"
                        name = $Shortcut.name
                        error = $_.Exception.Message
                    }
                    Write-Warning "Failed to create shortcut: $($Shortcut.name)"
                }
            }

        } catch {
            $BootstrapResults.errors += @{
                action = "shortcuts"
                error = $_.Exception.Message
            }
            Write-Error "Shortcut creation failed: $_"
        }
    }

    # Verify Installations
    if ($VerifyInstallations) {
        Write-Host "`nVerifying installations..." -ForegroundColor Blue

        try {
            $Verification = @{
                python_working = $false
                git_working = $false
                winget_working = $false
                chocolatey_working = $false
                devoptimizer_cli_working = $false
                errors = @()
            }

            # Verify Python
            try {
                $PythonTest = python --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $Verification.python_working = $true
                    Write-Host "✓ Python verification passed" -ForegroundColor Green
                }
            } catch {
                $Verification.errors += "Python verification failed"
            }

            # Verify Git
            try {
                $GitTest = git --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $Verification.git_working = $true
                    Write-Host "✓ Git verification passed" -ForegroundColor Green
                }
            } catch {
                $Verification.errors += "Git verification failed"
            }

            # Verify winget
            try {
                $WingetTest = winget --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $Verification.winget_working = $true
                    Write-Host "✓ winget verification passed" -ForegroundColor Green
                }
            } catch {
                $Verification.errors += "winget verification failed"
            }

            # Verify Chocolatey
            try {
                $ChocoTest = choco --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $Verification.chocolatey_working = $true
                    Write-Host "✓ Chocolatey verification passed" -ForegroundColor Green
                }
            } catch {
                $Verification.errors += "Chocolatey verification failed"
            }

            # Verify DevOptimizer CLI
            try {
                $VenvPath = "D:\DevOptimizer\py\venv\Scripts\python.exe"
                if (Test-Path $VenvPath) {
                    $CLITest = & $VenvPath -m devoptimizer_cli --version 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $Verification.devoptimizer_cli_working = $true
                        Write-Host "✓ DevOptimizer CLI verification passed" -ForegroundColor Green
                    }
                }
            } catch {
                $Verification.errors += "DevOptimizer CLI verification failed"
            }

            $BootstrapResults.verification_results = $Verification

        } catch {
            $BootstrapResults.errors += @{
                action = "verification"
                error = $_.Exception.Message
            }
            Write-Error "Verification failed: $_"
        }
    }

    # Save bootstrap results
    $BootstrapResultsFile = Join-Path $OutputDir "bootstrap_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $BootstrapResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $BootstrapResultsFile -Encoding UTF8
    Write-Host "✓ Bootstrap results saved to: $BootstrapResultsFile" -ForegroundColor Green

    # Display final summary
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "DEVELOPMENT ENVIRONMENT BOOTSTRAP COMPLETED" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green

    $PackagesInstalled = ($BootstrapResults.packages_installed | Where-Object {$_.status -eq "success"}).Count
    $PackagesFailed = ($BootstrapResults.packages_installed | Where-Object {$_.status -eq "failed"}).Count

    Write-Host "Packages Installed: $PackagesInstalled" -ForegroundColor White
    Write-Host "Packages Failed: $PackagesFailed" -ForegroundColor White
    Write-Host "Python Setup: $($BootstrapResults.python_setup.python_installed)" -ForegroundColor White
    Write-Host "Git Setup: $($BootstrapResults.git_setup.git_installed)" -ForegroundColor White
    Write-Host "Environment Configured: $($BootstrapResults.environment_config.variables_set.Count -gt 0)" -ForegroundColor White
    Write-Host "Shortcuts Created: $($BootstrapResults.shortcuts_created.Count)" -ForegroundColor White

    if ($BootstrapResults.errors.Count -gt 0) {
        Write-Host "`nErrors encountered:" -ForegroundColor Red
        foreach ($Error in $BootstrapResults.errors) {
            Write-Host "- $($Error.action): $($Error.error)" -ForegroundColor Red
        }
    }

    Write-Host "`nOutput Directory: $OutputDir" -ForegroundColor White
    Write-Host "Results File: $BootstrapResultsFile" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Green

} catch {
    Write-Error "Development environment bootstrap failed: $_"
    exit 1
}
