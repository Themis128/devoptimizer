# DevOptimizer Uninstallation Script
# Run with: pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Uninstall-DevOptimizer.ps1"

param(
    [switch]$Force = $false,
    [switch]$KeepData = $false,
    [switch]$KeepLogs = $false,
    [switch]$KeepConfigs = $false,
    [switch]$UnregisterTasks = $true,
    [switch]$RemovePythonVenv = $true,
    [switch]$RemoveDesktopShortcuts = $true
)

$ErrorActionPreference = 'Stop'

Write-Host "DevOptimizer Uninstallation Script" -ForegroundColor Red
Write-Host "This will remove DevOptimizer and its components" -ForegroundColor Yellow

if (-not $Force) {
    Write-Host "`nWARNING: This will permanently remove DevOptimizer!" -ForegroundColor Red
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  KeepData: $KeepData" -ForegroundColor White
    Write-Host "  KeepLogs: $KeepLogs" -ForegroundColor White
    Write-Host "  KeepConfigs: $KeepConfigs" -ForegroundColor White
    Write-Host "  UnregisterTasks: $UnregisterTasks" -ForegroundColor White
    Write-Host "  RemovePythonVenv: $RemovePythonVenv" -ForegroundColor White
    Write-Host "  RemoveDesktopShortcuts: $RemoveDesktopShortcuts" -ForegroundColor White

    $Confirm = Read-Host "`nDo you want to continue? (yes/no)"
    if ($Confirm -ne "yes") {
        Write-Host "Uninstallation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

try {
    $UninstallResults = @{
        timestamp = Get-Date
        components_removed = @()
        errors = @()
        warnings = @()
    }

    # Check if running as administrator
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $IsAdmin) {
        Write-Warning "Not running as administrator. Some components may not be removed properly."
        $UninstallResults.warnings += "Not running as administrator"
    }

    Write-Host "`nStarting DevOptimizer uninstallation..." -ForegroundColor Blue

    # Unregister scheduled tasks
    if ($UnregisterTasks) {
        Write-Host "`nUnregistering scheduled tasks..." -ForegroundColor Yellow

        try {
            # Get DevOptimizer tasks
            $DevOptimizerTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*DevOptimizer*" }

            foreach ($Task in $DevOptimizerTasks) {
                try {
                    Unregister-ScheduledTask -TaskName $Task.TaskName -Confirm:$false
                    $UninstallResults.components_removed += "Scheduled Task: $($Task.TaskName)"
                    Write-Host "✓ Unregistered task: $($Task.TaskName)" -ForegroundColor Green
                } catch {
                    $UninstallResults.errors += "Failed to unregister task '$($Task.TaskName)': $($_.Exception.Message)"
                    Write-Warning "Failed to unregister task: $($Task.TaskName)"
                }
            }

            if ($DevOptimizerTasks.Count -eq 0) {
                Write-Host "No DevOptimizer scheduled tasks found" -ForegroundColor Yellow
            }

        } catch {
            $UninstallResults.errors += "Failed to unregister scheduled tasks: $($_.Exception.Message)"
            Write-Error "Failed to unregister scheduled tasks: $_"
        }
    }

    # Remove desktop shortcuts
    if ($RemoveDesktopShortcuts) {
        Write-Host "`nRemoving desktop shortcuts..." -ForegroundColor Yellow

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
                    try {
                        Remove-Item $ShortcutPath -Force
                        $UninstallResults.components_removed += "Desktop Shortcut: $ShortcutName"
                        Write-Host "✓ Removed shortcut: $ShortcutName" -ForegroundColor Green
                    } catch {
                        $UninstallResults.errors += "Failed to remove shortcut '$ShortcutName': $($_.Exception.Message)"
                        Write-Warning "Failed to remove shortcut: $ShortcutName"
                    }
                }
            }

        } catch {
            $UninstallResults.errors += "Failed to remove desktop shortcuts: $($_.Exception.Message)"
            Write-Error "Failed to remove desktop shortcuts: $_"
        }
    }

    # Remove Python virtual environment
    if ($RemovePythonVenv) {
        Write-Host "`nRemoving Python virtual environment..." -ForegroundColor Yellow

        try {
            $VenvPath = "D:\DevOptimizer\py\venv"
            if (Test-Path $VenvPath) {
                Remove-Item $VenvPath -Recurse -Force
                $UninstallResults.components_removed += "Python Virtual Environment"
                Write-Host "✓ Removed Python virtual environment" -ForegroundColor Green
            } else {
                Write-Host "Python virtual environment not found" -ForegroundColor Yellow
            }
        } catch {
            $UninstallResults.errors += "Failed to remove Python virtual environment: $($_.Exception.Message)"
            Write-Error "Failed to remove Python virtual environment: $_"
        }
    }

    # Remove PowerShell modules from session
    Write-Host "`nRemoving PowerShell modules from session..." -ForegroundColor Yellow

    try {
        $ModulesToRemove = @(
            "DevOptimizer",
            "Microsoft.PowerShell.SecretManagement",
            "Microsoft.PowerShell.SecretStore",
            "Microsoft.WinGet.Client"
        )

        foreach ($ModuleName in $ModulesToRemove) {
            try {
                $Module = Get-Module -Name $ModuleName -ErrorAction SilentlyContinue
                if ($Module) {
                    Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
                    Write-Host "✓ Removed module from session: $ModuleName" -ForegroundColor Green
                }
            } catch {
                # Module may not be loaded, continue
            }
        }

    } catch {
        $UninstallResults.warnings += "Failed to remove some PowerShell modules from session"
        Write-Warning "Some PowerShell modules could not be removed from session"
    }

    # Remove environment variables
    Write-Host "`nRemoving environment variables..." -ForegroundColor Yellow

    try {
        $EnvVarsToRemove = @(
            "DEVOPTIMIZER_ROOT",
            "DEVOPTIMIZER_PYTHON",
            "DEVOPTIMIZER_SCRIPTS",
            "DEVOPTIMIZER_BIN",
            "DEVOPTIMIZER_CONFIGS"
        )

        foreach ($EnvVar in $EnvVarsToRemove) {
            try {
                if (Test-Path "Env:\$EnvVar") {
                    Remove-Item "Env:\$EnvVar" -Force
                    Write-Host "✓ Removed environment variable: $EnvVar" -ForegroundColor Green
                }
            } catch {
                $UninstallResults.warnings += "Failed to remove environment variable: $EnvVar"
            }
        }

    } catch {
        $UninstallResults.warnings += "Failed to remove some environment variables"
        Write-Warning "Some environment variables could not be removed"
    }

    # Remove SecretManagement vault
    Write-Host "`nRemoving SecretManagement vault..." -ForegroundColor Yellow

    try {
        $VaultName = 'DevOptimizerVault'
        $ExistingVaults = Get-SecretVault -ErrorAction SilentlyContinue

        if ($ExistingVaults -and $ExistingVaults.Name -contains $VaultName) {
            Unregister-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
            $UninstallResults.components_removed += "SecretManagement Vault: $VaultName"
            Write-Host "✓ Removed SecretManagement vault: $VaultName" -ForegroundColor Green
        } else {
            Write-Host "SecretManagement vault not found" -ForegroundColor Yellow
        }

    } catch {
        $UninstallResults.warnings += "Failed to remove SecretManagement vault"
        Write-Warning "Failed to remove SecretManagement vault"
    }

    # Remove directories and files
    Write-Host "`nRemoving directories and files..." -ForegroundColor Yellow

    $DevOptimizerRoot = "D:\DevOptimizer"

    if (Test-Path $DevOptimizerRoot) {
        # Define what to keep based on parameters
        $KeepDirs = @()
        if ($KeepData) { $KeepDirs += "metrics", "traces", "ai-analysis" }
        if ($KeepLogs) { $KeepDirs += "logs" }
        if ($KeepConfigs) { $KeepDirs += "configs" }

        # Remove specific directories
        $DirsToRemove = @("bin", "ps", "py", "tasks", ".env", "security")

        foreach ($Dir in $DirsToRemove) {
            $DirPath = Join-Path $DevOptimizerRoot $Dir
            if (Test-Path $DirPath) {
                try {
                    Remove-Item $DirPath -Recurse -Force
                    $UninstallResults.components_removed += "Directory: $Dir"
                    Write-Host "✓ Removed directory: $Dir" -ForegroundColor Green
                } catch {
                    $UninstallResults.errors += "Failed to remove directory '$Dir': $($_.Exception.Message)"
                    Write-Warning "Failed to remove directory: $Dir"
                }
            }
        }

        # Remove files in root
        $FilesToRemove = @("README.md")
        foreach ($File in $FilesToRemove) {
            $FilePath = Join-Path $DevOptimizerRoot $File
            if (Test-Path $FilePath) {
                try {
                    Remove-Item $FilePath -Force
                    $UninstallResults.components_removed += "File: $File"
                    Write-Host "✓ Removed file: $File" -ForegroundColor Green
                } catch {
                    $UninstallResults.errors += "Failed to remove file '$File': $($_.Exception.Message)"
                    Write-Warning "Failed to remove file: $File"
                }
            }
        }

        # Check if directory is empty and remove if so
        $RemainingItems = Get-ChildItem $DevOptimizerRoot -Force -ErrorAction SilentlyContinue
        if ($RemainingItems.Count -eq 0) {
            try {
                Remove-Item $DevOptimizerRoot -Force
                $UninstallResults.components_removed += "Root Directory: DevOptimizer"
                Write-Host "✓ Removed root directory" -ForegroundColor Green
            } catch {
                $UninstallResults.errors += "Failed to remove root directory: $($_.Exception.Message)"
                Write-Warning "Failed to remove root directory"
            }
        } else {
            Write-Host "Root directory not empty, keeping it" -ForegroundColor Yellow
            Write-Host "Remaining items:" -ForegroundColor Yellow
            foreach ($Item in $RemainingItems) {
                Write-Host "  - $($Item.Name)" -ForegroundColor Yellow
            }
        }

    } else {
        Write-Host "DevOptimizer root directory not found" -ForegroundColor Yellow
    }

    # Remove from PATH (if added)
    Write-Host "`nChecking PATH for DevOptimizer entries..." -ForegroundColor Yellow

    try {
        $CurrentPath = $env:PATH
        $PathEntries = $CurrentPath -split ';'
        $DevOptimizerPaths = $PathEntries | Where-Object { $_ -like "*DevOptimizer*" }

        if ($DevOptimizerPaths) {
            Write-Host "Found DevOptimizer paths in PATH:" -ForegroundColor Yellow
            foreach ($Path in $DevOptimizerPaths) {
                Write-Host "  - $Path" -ForegroundColor Yellow
            }
            Write-Host "Please remove these manually from System Environment Variables" -ForegroundColor Yellow
            $UninstallResults.warnings += "DevOptimizer paths found in PATH - manual removal required"
        } else {
            Write-Host "No DevOptimizer paths found in PATH" -ForegroundColor Green
        }

    } catch {
        $UninstallResults.warnings += "Failed to check PATH for DevOptimizer entries"
        Write-Warning "Failed to check PATH"
    }

    # Save uninstall results
    $ResultsFile = "D:\DevOptimizer\logs\uninstall_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

    # Create logs directory if it doesn't exist (for the results file)
    if (-not (Test-Path "D:\DevOptimizer\logs")) {
        New-Item -ItemType Directory -Path "D:\DevOptimizer\logs" -Force | Out-Null
    }

    $UninstallResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $ResultsFile -Encoding UTF8
    Write-Host "✓ Uninstall results saved to: $ResultsFile" -ForegroundColor Green

    # Display final summary
    Write-Host "`n" + "="*60 -ForegroundColor Red
    Write-Host "DEVOPTIMIZER UNINSTALLATION COMPLETED" -ForegroundColor Red
    Write-Host "="*60 -ForegroundColor Red

    $ComponentsRemoved = $UninstallResults.components_removed.Count
    $Errors = $UninstallResults.errors.Count
    $Warnings = $UninstallResults.warnings.Count

    Write-Host "Components Removed: $ComponentsRemoved" -ForegroundColor White
    Write-Host "Errors: $Errors" -ForegroundColor Red
    Write-Host "Warnings: $Warnings" -ForegroundColor Yellow

    if ($UninstallResults.components_removed.Count -gt 0) {
        Write-Host "`nRemoved Components:" -ForegroundColor Green
        foreach ($Component in $UninstallResults.components_removed) {
            Write-Host "  ✓ $Component" -ForegroundColor Green
        }
    }

    if ($UninstallResults.errors.Count -gt 0) {
        Write-Host "`nErrors:" -ForegroundColor Red
        foreach ($Error in $UninstallResults.errors) {
            Write-Host "  ✗ $Error" -ForegroundColor Red
        }
    }

    if ($UninstallResults.warnings.Count -gt 0) {
        Write-Host "`nWarnings:" -ForegroundColor Yellow
        foreach ($Warning in $UninstallResults.warnings) {
            Write-Host "  ⚠ $Warning" -ForegroundColor Yellow
        }
    }

    Write-Host "`nResults file: $ResultsFile" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Red

    # Final instructions
    Write-Host "`nPost-Uninstallation Steps:" -ForegroundColor Blue
    Write-Host "1. Restart your computer to ensure all changes take effect" -ForegroundColor White
    Write-Host "2. Check System Environment Variables for any DevOptimizer paths" -ForegroundColor White
    Write-Host "3. Review the results file for any manual cleanup required" -ForegroundColor White
    Write-Host "4. Remove any remaining DevOptimizer references from your system" -ForegroundColor White

    if ($Errors -eq 0) {
        Write-Host "`n✓ DevOptimizer has been successfully uninstalled!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠ DevOptimizer uninstallation completed with errors" -ForegroundColor Yellow
        Write-Host "Please review the errors above and perform manual cleanup if needed" -ForegroundColor Yellow
    }

} catch {
    Write-Error "Uninstallation failed: $_"
    exit 1
}
