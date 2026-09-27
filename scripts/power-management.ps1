# Power Management and Performance Configuration Functions

function Get-PowerPlans {
    Write-Log "Getting available power plans..." -Level "INFO"
    
    try {
        $plans = powercfg /list | Select-String "Power Scheme GUID" | ForEach-Object {
            $line = $_.Line
            $guid = ($line -split " ")[3]
            $name = ($line -split "\(")[1] -replace "\)", ""
            $active = $line.Contains("*")
            
            [PSCustomObject]@{
                GUID = $guid
                Name = $name
                Active = $active
            }
        }
        
        Write-Log "Found $($plans.Count) power plans:" -Level "INFO"
        foreach ($plan in $plans) {
            $status = if ($plan.Active) { " (ACTIVE)" } else { "" }
            Write-Log "  - $($plan.Name)$status" -Level "INFO"
        }
        
        return $plans
    }
    catch {
        Write-Log "Error getting power plans: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Set-PowerPlan {
    param(
        [ValidateSet("Balanced", "High Performance", "Power Saver", "Ultimate Performance")]
        [string]$PlanName
    )
    
    Write-Log "Setting power plan to: $PlanName" -Level "INFO"
    
    try {
        $planGuids = @{
            "Balanced" = "381b4222-f694-41f0-9685-ff5bb260df2e"
            "High Performance" = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
            "Power Saver" = "a1841308-3541-4fab-bc81-f71556f20b4a"
            "Ultimate Performance" = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        }
        
        $guid = $planGuids[$PlanName]
        
        # Check if Ultimate Performance exists, if not create it
        if ($PlanName -eq "Ultimate Performance") {
            $existing = powercfg /list | Select-String $guid
            if (-not $existing) {
                Write-Log "Creating Ultimate Performance power plan..." -Level "INFO"
                powercfg /duplicatescheme $guid | Out-Null
            }
        }
        
        # Set the power plan
        powercfg /setactive $guid
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Power plan set to: $PlanName" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Failed to set power plan" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error setting power plan: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Optimize-PowerSettings {
    param(
        [ValidateSet("Gaming", "Development", "Battery", "Balanced", "Maximum")]
        [string]$Profile = "Balanced"
    )
    
    Write-Log "Optimizing power settings for profile: $Profile" -Level "INFO"
    
    try {
        switch ($Profile) {
            "Gaming" {
                Set-PowerPlan -PlanName "High Performance"
                
                # Disable USB selective suspend
                powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
                
                # Set minimum processor state to 100%
                powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
                
                # Disable core parking
                powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0
                
                Write-Log "Gaming power profile applied" -Level "SUCCESS"
            }
            "Development" {
                Set-PowerPlan -PlanName "High Performance"
                
                # Never turn off display
                powercfg /setacvalueindex SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 0
                
                # Never sleep
                powercfg /setacvalueindex SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 0
                
                # Keep USB devices active
                powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
                
                Write-Log "Development power profile applied" -Level "SUCCESS"
            }
            "Battery" {
                Set-PowerPlan -PlanName "Power Saver"
                
                # Aggressive display timeout
                powercfg /setacvalueindex SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 300
                
                # Enable USB selective suspend
                powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
                
                # Minimum processor state to 5%
                powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 5
                
                Write-Log "Battery saving power profile applied" -Level "SUCCESS"
            }
            "Maximum" {
                Set-PowerPlan -PlanName "Ultimate Performance"
                
                # Maximum performance settings
                powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
                powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100
                
                # Disable all power saving features
                powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
                powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
                
                Write-Log "Maximum performance power profile applied" -Level "SUCCESS"
            }
            default {
                Set-PowerPlan -PlanName "Balanced"
                Write-Log "Balanced power profile applied" -Level "SUCCESS"
            }
        }
        
        # Apply settings
        powercfg /setactive SCHEME_CURRENT
        
        Write-Log "Power optimization completed for $Profile profile" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error optimizing power settings: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-PowerReport {
    Write-Log "Generating power efficiency report..." -Level "INFO"
    
    try {
        $reportPath = "$env:TEMP\power-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        
        # Generate power efficiency report
        powercfg /energy /output $reportPath /duration 10
        
        if (Test-Path $reportPath) {
            Write-Log "Power report generated: $reportPath" -Level "SUCCESS"
            
            # Try to open the report
            try {
                Start-Process $reportPath
                Write-Log "Power report opened in default browser" -Level "INFO"
            } catch {
                Write-Log "Could not open report automatically. Manual path: $reportPath" -Level "INFO"
            }
            
            return $reportPath
        } else {
            Write-Log "Failed to generate power report" -Level "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Error generating power report: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}
