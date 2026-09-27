# Security Hardening and Audit Functions
function Test-SystemSecurity {
    Write-Log "Starting comprehensive security audit..." -Level "INFO"
    
    $securityResults = @{
        WindowsDefender = @{}
        UAC = @{}
        Firewall = @{}
        Updates = @{}
        UserAccounts = @()
        Services = @()
        Registry = @{}
        Policies = @{}
    }
    
    try {
        # Windows Defender status
        Write-Log "Checking Windows Defender status..." -Level "INFO"
        try {
            $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
            if ($defenderStatus) {
                $securityResults.WindowsDefender = @{
                    AntivirusEnabled = $defenderStatus.AntivirusEnabled
                    RealTimeProtectionEnabled = $defenderStatus.RealTimeProtectionEnabled
                    LastQuickScanAge = $defenderStatus.QuickScanAge
                }
                
                $defenderHealth = "Healthy"
                if (-not $defenderStatus.AntivirusEnabled) { $defenderHealth = "Critical - Antivirus Disabled" }
                elseif (-not $defenderStatus.RealTimeProtectionEnabled) { $defenderHealth = "Warning - Real-time Protection Disabled" }
                elseif ($defenderStatus.QuickScanAge -gt 7) { $defenderHealth = "Warning - Quick Scan Overdue" }
                
                Write-Log "Windows Defender: $defenderHealth" -Level $(if($defenderHealth -eq "Healthy") { "SUCCESS" } else { "WARN" })
            }
        } catch {
            Write-Log "Could not check Windows Defender status" -Level "WARN"
        }
        
        # UAC Status
        Write-Log "Checking UAC status..." -Level "INFO"
        try {
            $uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            $uacEnabled = Get-ItemProperty -Path $uacKey -Name "EnableLUA" -ErrorAction SilentlyContinue
            
            if ($uacEnabled -and $uacEnabled.EnableLUA -eq 1) {
                Write-Log "UAC: Enabled" -Level "SUCCESS"
            } else {
                Write-Log "UAC: Disabled - SECURITY RISK!" -Level "ERROR"
            }
        } catch {
            Write-Log "Could not check UAC status" -Level "WARN"
        }
        
        # Windows Firewall Status
        Write-Log "Checking Windows Firewall status..." -Level "INFO"
        try {
            $firewallProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
            if ($firewallProfiles) {
                foreach ($profile in $firewallProfiles) {
                    $status = if ($profile.Enabled) { "Enabled" } else { "Disabled" }
                    $level = if ($profile.Enabled) { "SUCCESS" } else { "ERROR" }
                    Write-Log "Firewall ($($profile.Name)): $status" -Level $level
                }
            }
        } catch {
            Write-Log "Could not check Windows Firewall status" -Level "WARN"
        }
        
        Write-Log "=== SECURITY AUDIT COMPLETED ===" -Level "SUCCESS"
        return $securityResults
    }
    catch {
        Write-Log "Error in security audit: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Set-SecurityHardening {
    param([switch]$All)
    
    Write-Log "Starting security hardening..." -Level "INFO"
    
    try {
        # Enable Windows Defender features
        try {
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
            Write-Log "Windows Defender real-time protection enabled" -Level "SUCCESS"
        } catch {
            Write-Log "Could not configure Windows Defender" -Level "WARN"
        }
        
        # Harden UAC
        try {
            $uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            Set-RegistryValueSafe -Path $uacKey -Name "EnableLUA" -Value 1
            Write-Log "UAC enabled" -Level "SUCCESS"
        } catch {
            Write-Log "Could not enable UAC" -Level "WARN"
        }
        
        # Enable Windows Firewall
        try {
            Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction SilentlyContinue
            Write-Log "Windows Firewall enabled for all profiles" -Level "SUCCESS"
        } catch {
            Write-Log "Could not enable Windows Firewall" -Level "WARN"
        }
        
        Write-Log "Security hardening completed!" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error in security hardening: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Test-SystemVulnerabilities {
    Write-Log "Scanning for common vulnerabilities..." -Level "INFO"
    
    $vulnerabilities = @()
    
    try {
        # Check for disabled UAC
        $uacEnabled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
        if (-not $uacEnabled -or $uacEnabled.EnableLUA -eq 0) {
            $vulnerabilities += "User Account Control (UAC) is disabled"
        }
        
        # Check for disabled Windows Defender
        try {
            $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
            if ($defenderStatus -and -not $defenderStatus.AntivirusEnabled) {
                $vulnerabilities += "Windows Defender Antivirus is disabled"
            }
        } catch {}
        
        # Display results
        Write-Log "=== VULNERABILITY SCAN RESULTS ===" -Level "INFO"
        if ($vulnerabilities.Count -eq 0) {
            Write-Log " No common vulnerabilities detected!" -Level "SUCCESS"
        } else {
            Write-Log "  Found $($vulnerabilities.Count) potential security issues:" -Level "WARN"
            foreach ($vuln in $vulnerabilities) {
                Write-Log "   $vuln" -Level "WARN"
            }
        }
        
        return $vulnerabilities
    }
    catch {
        Write-Log "Error scanning for vulnerabilities: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

