# Windows Features Management Functions

function Get-WindowsFeatures {
    Write-Log "Getting Windows Features status..." -Level "INFO"
    
    try {
        $features = Get-WindowsOptionalFeature -Online | Sort-Object FeatureName
        
        $enabled = $features | Where-Object { $_.State -eq "Enabled" }
        $disabled = $features | Where-Object { $_.State -eq "Disabled" }
        
        Write-Log "Windows Features Summary:" -Level "INFO"
        Write-Log "  Total features: $($features.Count)" -Level "INFO"
        Write-Log "  Enabled: $($enabled.Count)" -Level "SUCCESS"
        Write-Log "  Disabled: $($disabled.Count)" -Level "INFO"
        
        # Show key development features
        $devFeatures = @(
            "Microsoft-Windows-Subsystem-Linux",
            "VirtualMachinePlatform",
            "Microsoft-Hyper-V-All",
            "IIS-WebServerRole",
            "IIS-WebServer",
            "NetFx4Extended-ASPNET45",
            "WCF-Services45",
            "TFTP",
            "TelnetClient",
            "SimpleTCP"
        )
        
        Write-Log "Development-related features:" -Level "INFO"
        foreach ($featureName in $devFeatures) {
            $feature = $features | Where-Object { $_.FeatureName -eq $featureName }
            if ($feature) {
                $status = if ($feature.State -eq "Enabled") { " Enabled" } else { " Disabled" }
                $level = if ($feature.State -eq "Enabled") { "SUCCESS" } else { "WARN" }
                Write-Log "  $($feature.DisplayName): $status" -Level $level
            }
        }
        
        return $features
    }
    catch {
        Write-Log "Error getting Windows features: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Enable-DevelopmentFeatures {
    param(
        [switch]$WSL,
        [switch]$HyperV,
        [switch]$IIS,
        [switch]$DotNet,
        [switch]$Containers,
        [switch]$All
    )
    
    Write-Log "Enabling development features..." -Level "INFO"
    
    $featuresToEnable = @()
    
    if ($All -or $WSL) {
        $featuresToEnable += @(
            @{ Name = "Microsoft-Windows-Subsystem-Linux"; Display = "Windows Subsystem for Linux" },
            @{ Name = "VirtualMachinePlatform"; Display = "Virtual Machine Platform" }
        )
    }
    
    if ($All -or $HyperV) {
        $featuresToEnable += @(
            @{ Name = "Microsoft-Hyper-V-All"; Display = "Hyper-V Platform" }
        )
    }
    
    if ($All -or $IIS) {
        $featuresToEnable += @(
            @{ Name = "IIS-WebServerRole"; Display = "Internet Information Services" },
            @{ Name = "IIS-WebServer"; Display = "World Wide Web Services" },
            @{ Name = "IIS-CommonHttpFeatures"; Display = "Common HTTP Features" },
            @{ Name = "IIS-HttpErrors"; Display = "HTTP Errors" },
            @{ Name = "IIS-HttpRedirect"; Display = "HTTP Redirection" },
            @{ Name = "IIS-ApplicationDevelopment"; Display = "Application Development Features" },
            @{ Name = "IIS-NetFxExtensibility45"; Display = ".NET Extensibility 4.5" },
            @{ Name = "IIS-ASPNET45"; Display = "ASP.NET 4.5" }
        )
    }
    
    if ($All -or $DotNet) {
        $featuresToEnable += @(
            @{ Name = "NetFx4Extended-ASPNET45"; Display = ".NET Framework 4.5 Extended" },
            @{ Name = "WCF-Services45"; Display = "WCF Services" }
        )
    }
    
    if ($All -or $Containers) {
        $featuresToEnable += @(
            @{ Name = "Containers"; Display = "Containers" }
        )
    }
    
    $enabledCount = 0
    foreach ($feature in $featuresToEnable) {
        try {
            Write-Log "Enabling: $($feature.Display)..." -Level "INFO"
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature.Name -All -NoRestart -ErrorAction Stop
            
            if ($result.RestartNeeded) {
                Write-Log "Feature enabled (restart required): $($feature.Display)" -Level "WARN"
            } else {
                Write-Log "Feature enabled: $($feature.Display)" -Level "SUCCESS"
            }
            $enabledCount++
        }
        catch {
            Write-Log "Failed to enable feature: $($feature.Display) - $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    Write-Log "Development features operation completed: $enabledCount features processed" -Level "SUCCESS"
    return $enabledCount
}

function Disable-UnnecessaryFeatures {
    param(
        [switch]$Legacy,
        [switch]$Internet,
        [switch]$Media,
        [switch]$Print,
        [switch]$All
    )
    
    Write-Log "Disabling unnecessary features..." -Level "INFO"
    
    $featuresToDisable = @()
    
    if ($All -or $Legacy) {
        $featuresToDisable += @(
            @{ Name = "LegacyComponents"; Display = "Legacy Components" },
            @{ Name = "DirectPlay"; Display = "DirectPlay" },
            @{ Name = "SimpleTCP"; Display = "Simple TCPIP Services" }
        )
    }
    
    if ($All -or $Internet) {
        $featuresToDisable += @(
            @{ Name = "Internet-Explorer-Optional-amd64"; Display = "Internet Explorer 11" },
            @{ Name = "TFTP"; Display = "TFTP Client" },
            @{ Name = "TelnetClient"; Display = "Telnet Client" }
        )
    }
    
    if ($All -or $Media) {
        $featuresToDisable += @(
            @{ Name = "MediaPlayback"; Display = "Media Features" },
            @{ Name = "WindowsMediaPlayer"; Display = "Windows Media Player" }
        )
    }
    
    if ($All -or $Print) {
        $featuresToDisable += @(
            @{ Name = "Printing-Foundation-Features"; Display = "Print and Document Services" },
            @{ Name = "Printing-XPSServices-Features"; Display = "XPS Services" }
        )
    }
    
    $disabledCount = 0
    foreach ($feature in $featuresToDisable) {
        try {
            # Check if feature exists and is enabled
            $currentFeature = Get-WindowsOptionalFeature -Online -FeatureName $feature.Name -ErrorAction SilentlyContinue
            if ($currentFeature -and $currentFeature.State -eq "Enabled") {
                Write-Log "Disabling: $($feature.Display)..." -Level "INFO"
                $result = Disable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction Stop
                
                if ($result.RestartNeeded) {
                    Write-Log "Feature disabled (restart required): $($feature.Display)" -Level "WARN"
                } else {
                    Write-Log "Feature disabled: $($feature.Display)" -Level "SUCCESS"
                }
                $disabledCount++
            } else {
                Write-Log "Feature already disabled or not found: $($feature.Display)" -Level "INFO"
            }
        }
        catch {
            Write-Log "Failed to disable feature: $($feature.Display) - $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    Write-Log "Unnecessary features cleanup completed: $disabledCount features disabled" -Level "SUCCESS"
    return $disabledCount
}

function Set-DeveloperMode {
    param([switch]$Enable)
    
    Write-Log "$(if($Enable){'Enabling'}else{'Disabling'}) Windows Developer Mode..." -Level "INFO"
    
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        
        if ($Enable) {
            # Enable Developer Mode
            Set-RegistryValueSafe -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -Value 1
            Set-RegistryValueSafe -Path $regPath -Name "AllowAllTrustedApps" -Value 1
            
            Write-Log "Developer Mode enabled" -Level "SUCCESS"
            Write-Log "You can now sideload apps and use advanced developer features" -Level "INFO"
        } else {
            # Disable Developer Mode
            Set-RegistryValueSafe -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -Value 0
            Set-RegistryValueSafe -Path $regPath -Name "AllowAllTrustedApps" -Value 0
            
            Write-Log "Developer Mode disabled" -Level "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-Log "Error setting Developer Mode: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Optimize-WindowsFeatures {
    param(
        [ValidateSet("Development", "Gaming", "Server", "Minimal", "Custom")]
        [string]$Profile = "Development"
    )
    
    Write-Log "Optimizing Windows features for profile: $Profile" -Level "INFO"
    
    try {
        switch ($Profile) {
            "Development" {
                Write-Log "Applying Development profile..." -Level "INFO"
                Enable-DevelopmentFeatures -WSL -DotNet -IIS
                Set-DeveloperMode -Enable
                Disable-UnnecessaryFeatures -Legacy -Media
            }
            "Gaming" {
                Write-Log "Applying Gaming profile..." -Level "INFO"
                Disable-UnnecessaryFeatures -Legacy -Print -Internet
                # Keep media features for gaming
                Enable-DevelopmentFeatures -DotNet  # For some games
            }
            "Server" {
                Write-Log "Applying Server profile..." -Level "INFO"
                Enable-DevelopmentFeatures -IIS -DotNet -HyperV
                Disable-UnnecessaryFeatures -Legacy -Media -Internet
            }
            "Minimal" {
                Write-Log "Applying Minimal profile..." -Level "INFO"
                Disable-UnnecessaryFeatures -All
            }
            "Custom" {
                Write-Log "Custom profile - manual feature selection required" -Level "INFO"
                Get-WindowsFeatures
            }
        }
        
        Write-Log "Windows features optimization completed for $Profile profile" -Level "SUCCESS"
        Write-Log "IMPORTANT: Some changes may require a system restart to take effect" -Level "WARN"
        
        return $true
    }
    catch {
        Write-Log "Error optimizing Windows features: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

