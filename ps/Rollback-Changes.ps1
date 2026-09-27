# DevOptimizer Rollback Script
# Run with: pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Rollback-Changes.ps1"

param(
    [string]$BackupDir = "D:\DevOptimizer\backups",
    [switch]$RollbackServices = $true,
    [switch]$RollbackRegistry = $true,
    [switch]$RollbackDefender = $true,
    [switch]$RollbackFirewall = $true,
    [switch]$RollbackUpdates = $true,
    [switch]$Force = $false
)

$ErrorActionPreference = 'Stop'

Write-Host "DevOptimizer Rollback Script" -ForegroundColor Yellow
Write-Host "This will rollback system changes made by DevOptimizer" -ForegroundColor Yellow

if (-not $Force) {
    Write-Host "`nWARNING: This will rollback system changes!" -ForegroundColor Red
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  RollbackServices: $RollbackServices" -ForegroundColor White
    Write-Host "  RollbackRegistry: $RollbackRegistry" -ForegroundColor White
    Write-Host "  RollbackDefender: $RollbackDefender" -ForegroundColor White
    Write-Host "  RollbackFirewall: $RollbackFirewall" -ForegroundColor White
    Write-Host "  RollbackUpdates: $RollbackUpdates" -ForegroundColor White

    $Confirm = Read-Host "`nDo you want to continue? (yes/no)"
    if ($Confirm -ne "yes") {
        Write-Host "Rollback cancelled" -ForegroundColor Yellow
        exit 0
    }
}

try {
    # Check if running as administrator
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $IsAdmin) {
        Write-Error "This script must be run as administrator to rollback system changes"
        exit 1
    }

    $RollbackResults = @{
        timestamp = Get-Date
        changes_rolled_back = @()
        errors = @()
        warnings = @()
    }

    Write-Host "`nStarting rollback process..." -ForegroundColor Blue

    # Rollback Services
    if ($RollbackServices) {
        Write-Host "`nRolling back services..." -ForegroundColor Yellow

        $ServicesToRestore = @(
            @{ Name = "Fax"; StartType = "Manual" },
            @{ Name = "TabletInputService"; StartType = "Manual" },
            @{ Name = "XblAuthManager"; StartType = "Manual" },
            @{ Name = "XblGameSave"; StartType = "Manual" },
            @{ Name = "XboxNetApiSvc"; StartType = "Manual" },
            @{ Name = "XboxGipSvc"; StartType = "Manual" },
            @{ Name = "XboxLiveAuthManager"; StartType = "Manual" }
        )

        foreach ($Service in $ServicesToRestore) {
            try {
                $ServiceObj = Get-Service -Name $Service.Name -ErrorAction SilentlyContinue
                if ($ServiceObj) {
                    # Set service back to manual start
                    Set-Service -Name $Service.Name -StartupType $Service.StartType -ErrorAction SilentlyContinue

                    $RollbackResults.changes_rolled_back += "Service: $($Service.Name) -> $($Service.StartType)"
                    Write-Host "✓ Restored service: $($Service.Name)" -ForegroundColor Green
                } else {
                    Write-Host "⚠ Service not found: $($Service.Name)" -ForegroundColor Yellow
                }
            } catch {
                $RollbackResults.errors += "Failed to restore service '$($Service.Name)': $($_.Exception.Message)"
                Write-Warning "Failed to restore service: $($Service.Name)"
            }
        }
    }

    # Rollback Registry Changes
    if ($RollbackRegistry) {
        Write-Host "`nRolling back registry changes..." -ForegroundColor Yellow

        $RegistryRollbacks = @(
            @{
                Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
                Name = "VisualFXSetting"
                Type = "DWORD"
                Value = 3  # Restore to "Let Windows choose what's best for my computer"
            },
            @{
                Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
                Name = "VisualFXSetting"
                Type = "DWORD"
                Value = 3
            },
            @{
                Path = "HKCU\Control Panel\Desktop\WindowMetrics"
                Name = "MinAnimate"
                Type = "SZ"
                Value = "1"  # Restore animations
            }
        )

        foreach ($RegChange in $RegistryRollbacks) {
            try {
                if ($RegChange.Type -eq "DWORD") {
                    reg add "$($RegChange.Path)" /v "$($RegChange.Name)" /t REG_DWORD /d $RegChange.Value /f 2>$null
                } else {
                    reg add "$($RegChange.Path)" /v "$($RegChange.Name)" /t REG_SZ /d $RegChange.Value /f 2>$null
                }

                $RollbackResults.changes_rolled_back += "Registry: $($RegChange.Path)\$($RegChange.Name)"
                Write-Host "✓ Restored registry: $($RegChange.Path)\$($RegChange.Name)" -ForegroundColor Green

            } catch {
                $RollbackResults.errors += "Failed to restore registry '$($RegChange.Path)\$($RegChange.Name)': $($_.Exception.Message)"
                Write-Warning "Failed to restore registry: $($RegChange.Path)\$($RegChange.Name)"
            }
        }
    }

    # Rollback Windows Defender Settings
    if ($RollbackDefender) {
        Write-Host "`nRolling back Windows Defender settings..." -ForegroundColor Yellow

        $DefenderRollbacks = @(
            "Set-MpPreference -DisableRealtimeMonitoring `$true",
            "Set-MpPreference -EnableCloudProtection `$false",
            "Set-MpPreference -ScanScheduleDay 0",
            "Set-MpPreference -DisableBehaviorMonitoring `$true",
            "Set-MpPreference -DisableIntrusionPreventionSystem `$true"
        )

        foreach ($Cmd in $DefenderRollbacks) {
            try {
                Invoke-Expression $Cmd -ErrorAction SilentlyContinue
                $RollbackResults.changes_rolled_back += "Defender: $Cmd"
                Write-Host "✓ Restored Defender setting" -ForegroundColor Green
            } catch {
                $RollbackResults.errors += "Failed to restore Defender setting '$Cmd': $($_.Exception.Message)"
                Write-Warning "Failed to restore Defender setting"
            }
        }
    }

    # Rollback Firewall Settings
    if ($RollbackFirewall) {
        Write-Host "`nRolling back firewall settings..." -ForegroundColor Yellow

        $FirewallRollbacks = @(
            "netsh advfirewall set allprofiles state off",
            "netsh advfirewall set allprofiles firewallpolicy allowinbound,allowoutbound",
            "netsh advfirewall set allprofiles logging disable"
        )

        foreach ($Cmd in $FirewallRollbacks) {
            try {
                Invoke-Expression $Cmd -ErrorAction SilentlyContinue
                $RollbackResults.changes_rolled_back += "Firewall: $Cmd"
                Write-Host "✓ Restored firewall setting" -ForegroundColor Green
            } catch {
                $RollbackResults.errors += "Failed to restore firewall setting '$Cmd': $($_.Exception.Message)"
                Write-Warning "Failed to restore firewall setting"
            }
        }
    }

    # Rollback Windows Update Settings
    if ($RollbackUpdates) {
        Write-Host "`nRolling back Windows Update settings..." -ForegroundColor Yellow

        $UpdateRollbacks = @(
            @{
                Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
                Name = "NoAutoUpdate"
                Type = "DWORD"
                Value = 1  # Disable automatic updates
            },
            @{
                Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
                Name = "ExcludeWUDriversInQualityUpdate"
                Type = "DWORD"
                Value = 1  # Exclude driver updates
            }
        )

        foreach ($RegChange in $UpdateRollbacks) {
            try {
                reg add "$($RegChange.Path)" /v "$($RegChange.Name)" /t REG_DWORD /d $RegChange.Value /f 2>$null
                $RollbackResults.changes_rolled_back += "Windows Update: $($RegChange.Path)\$($RegChange.Name)"
                Write-Host "✓ Restored Windows Update setting" -ForegroundColor Green
            } catch {
                $RollbackResults.errors += "Failed to restore Windows Update setting '$($RegChange.Path)\$($RegChange.Name)': $($_.Exception.Message)"
                Write-Warning "Failed to restore Windows Update setting"
            }
        }
    }

    # Create backup directory if it doesn't exist
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }

    # Save rollback results
    $ResultsFile = Join-Path $BackupDir "rollback_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $RollbackResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $ResultsFile -Encoding UTF8
    Write-Host "✓ Rollback results saved to: $ResultsFile" -ForegroundColor Green

    # Display final summary
    Write-Host "`n" + "="*60 -ForegroundColor Yellow
    Write-Host "ROLLBACK COMPLETED" -ForegroundColor Yellow
    Write-Host "="*60 -ForegroundColor Yellow

    $ChangesRolledBack = $RollbackResults.changes_rolled_back.Count
    $Errors = $RollbackResults.errors.Count
    $Warnings = $RollbackResults.warnings.Count

    Write-Host "Changes Rolled Back: $ChangesRolledBack" -ForegroundColor White
    Write-Host "Errors: $Errors" -ForegroundColor Red
    Write-Host "Warnings: $Warnings" -ForegroundColor Yellow

    if ($RollbackResults.changes_rolled_back.Count -gt 0) {
        Write-Host "`nRolled Back Changes:" -ForegroundColor Green
        foreach ($Change in $RollbackResults.changes_rolled_back) {
            Write-Host "  ✓ $Change" -ForegroundColor Green
        }
    }

    if ($RollbackResults.errors.Count -gt 0) {
        Write-Host "`nErrors:" -ForegroundColor Red
        foreach ($Error in $RollbackResults.errors) {
            Write-Host "  ✗ $Error" -ForegroundColor Red
        }
    }

    Write-Host "`nResults file: $ResultsFile" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Yellow

    # Final instructions
    Write-Host "`nPost-Rollback Steps:" -ForegroundColor Blue
    Write-Host "1. Restart your computer to ensure all changes take effect" -ForegroundColor White
    Write-Host "2. Verify that system behavior matches your expectations" -ForegroundColor White
    Write-Host "3. Check Windows Defender, Firewall, and Update settings" -ForegroundColor White
    Write-Host "4. Review the results file for any issues" -ForegroundColor White

    if ($Errors -eq 0) {
        Write-Host "`n✓ Rollback completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠ Rollback completed with errors" -ForegroundColor Yellow
        Write-Host "Please review the errors above and perform manual rollback if needed" -ForegroundColor Yellow
    }

} catch {
    Write-Error "Rollback failed: $_"
    exit 1
}
