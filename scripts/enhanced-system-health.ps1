# Enhanced System Health Check
# Improved version with better error handling and compatibility

param(
    [string]$Mode = "full",
    [switch]$FixIssues,
    [switch]$GenerateReport
)

Write-Host "🔍 Enhanced System Health Check" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# System Information
$systemInfo = @{
    "OS" = (Get-WmiObject -Class Win32_OperatingSystem).Caption
    "Version" = (Get-WmiObject -Class Win32_OperatingSystem).Version
    "Architecture" = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture
    "ComputerName" = $env:COMPUTERNAME
    "Username" = $env:USERNAME
    "CheckTime" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

Write-Host "🖥️ System Information:" -ForegroundColor Green
Write-Host "OS: $($systemInfo.OS)" -ForegroundColor White
Write-Host "Version: $($systemInfo.Version)" -ForegroundColor White
Write-Host "Architecture: $($systemInfo.Architecture)" -ForegroundColor White
Write-Host "Computer: $($systemInfo.ComputerName)" -ForegroundColor White
Write-Host "User: $($systemInfo.Username)" -ForegroundColor White
Write-Host "Check Time: $($systemInfo.CheckTime)" -ForegroundColor White
Write-Host ""

# Health Check Results
$healthResults = @{
    "Overall" = "Good"
    "Issues" = @()
    "Warnings" = @()
    "Recommendations" = @()
}

# 1. Windows Update Service Check
Write-Host "1️⃣ Windows Update Service Check..." -ForegroundColor Yellow
try {
    $wuService = Get-Service -Name "wuauserv" -ErrorAction Stop
    if ($wuService.Status -eq "Running") {
        Write-Host "   ✅ Windows Update Service: RUNNING" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ Windows Update Service: $($wuService.Status)" -ForegroundColor Yellow
        $healthResults.Warnings += "Windows Update Service is not running"
    }
} catch {
    Write-Host "   ❌ Windows Update Service: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $healthResults.Issues += "Cannot access Windows Update Service"
}

# 2. Disk Health Check
Write-Host "2️⃣ Disk Health Check..." -ForegroundColor Yellow
try {
    $disks = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}
    foreach ($disk in $disks) {
        $freeSpacePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
        $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)

        if ($freeSpacePercent -lt 10) {
            Write-Host "   ❌ Drive $($disk.DeviceID): CRITICAL - Only $freeSpacePercent% free ($freeSpaceGB GB / $totalSpaceGB GB)" -ForegroundColor Red
            $healthResults.Issues += "Drive $($disk.DeviceID) has critically low free space"
        } elseif ($freeSpacePercent -lt 20) {
            Write-Host "   ⚠️ Drive $($disk.DeviceID): WARNING - $freeSpacePercent% free ($freeSpaceGB GB / $totalSpaceGB GB)" -ForegroundColor Yellow
            $healthResults.Warnings += "Drive $($disk.DeviceID) has low free space"
        } else {
            Write-Host "   ✅ Drive $($disk.DeviceID): OK - $freeSpacePercent% free ($freeSpaceGB GB / $totalSpaceGB GB)" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "   ❌ Disk Health Check: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $healthResults.Issues += "Cannot access disk information"
}

# 3. Memory Check
Write-Host "3️⃣ Memory Check..." -ForegroundColor Yellow
try {
    $memory = Get-WmiObject -Class Win32_ComputerSystem
    $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)

    $memoryCounter = Get-Counter '\Memory\Available MBytes' -SampleInterval 1 -MaxSamples 1
    $availableMemoryGB = [math]::Round($memoryCounter.CounterSamples[0].CookedValue / 1024, 2)
    $usedMemoryGB = $totalMemoryGB - $availableMemoryGB
    $memoryUsagePercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)

    if ($memoryUsagePercent -gt 90) {
        Write-Host "   ❌ Memory Usage: CRITICAL - $memoryUsagePercent% used ($usedMemoryGB GB / $totalMemoryGB GB)" -ForegroundColor Red
        $healthResults.Issues += "Memory usage is critically high"
    } elseif ($memoryUsagePercent -gt 80) {
        Write-Host "   ⚠️ Memory Usage: WARNING - $memoryUsagePercent% used ($usedMemoryGB GB / $totalMemoryGB GB)" -ForegroundColor Yellow
        $healthResults.Warnings += "Memory usage is high"
    } else {
        Write-Host "   ✅ Memory Usage: OK - $memoryUsagePercent% used ($usedMemoryGB GB / $totalMemoryGB GB)" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ Memory Check: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $healthResults.Issues += "Cannot access memory information"
}

# 4. CPU Check
Write-Host "4️⃣ CPU Check..." -ForegroundColor Yellow
try {
    $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 3
    $avgCpuUsage = [math]::Round(($cpuCounter.CounterSamples | Measure-Object -Property CookedValue -Average).Average, 2)

    if ($avgCpuUsage -gt 90) {
        Write-Host "   ❌ CPU Usage: CRITICAL - $avgCpuUsage% average" -ForegroundColor Red
        $healthResults.Issues += "CPU usage is critically high"
    } elseif ($avgCpuUsage -gt 80) {
        Write-Host "   ⚠️ CPU Usage: WARNING - $avgCpuUsage% average" -ForegroundColor Yellow
        $healthResults.Warnings += "CPU usage is high"
    } else {
        Write-Host "   ✅ CPU Usage: OK - $avgCpuUsage% average" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ CPU Check: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $healthResults.Issues += "Cannot access CPU information"
}

# 5. Temperature Check (Enhanced)
Write-Host "5️⃣ Temperature Check..." -ForegroundColor Yellow
try {
    # Try multiple temperature sources
    $temperature = $null

    # Method 1: WMI Thermal Zone
    try {
        $tempWMI = Get-WmiObject -Namespace root/wmi -Class MSAcpi_ThermalZoneTemperature -ErrorAction Stop
        if ($tempWMI) {
            $temperature = [math]::Round(($tempWMI.CurrentTemperature / 10) - 273.15, 2)
            Write-Host "   ✅ Temperature: $temperature°C (WMI)" -ForegroundColor Green
        }
    } catch {
        # Method 2: Open Hardware Monitor (if available)
        try {
            $tempOHM = Get-WmiObject -Namespace root\OpenHardwareMonitor -Class Sensor -ErrorAction Stop | Where-Object {$_.SensorType -eq "Temperature"}
            if ($tempOHM) {
                $temperature = [math]::Round($tempOHM.Value, 2)
                Write-Host "   ✅ Temperature: $temperature°C (OpenHardwareMonitor)" -ForegroundColor Green
            }
        } catch {
            # Method 3: HWiNFO (if available)
            try {
                $tempHWiNFO = Get-WmiObject -Namespace root\HWiNFO64 -Class Sensor -ErrorAction Stop | Where-Object {$_.SensorType -eq "Temperature"}
                if ($tempHWiNFO) {
                    $temperature = [math]::Round($tempHWiNFO.Value, 2)
                    Write-Host "   ✅ Temperature: $temperature°C (HWiNFO)" -ForegroundColor Green
                }
            } catch {
                Write-Host "   ⚠️ Temperature: Not available (no compatible monitoring software)" -ForegroundColor Yellow
                $healthResults.Warnings += "Temperature monitoring not available"
            }
        }
    }

    if ($temperature) {
        if ($temperature -gt 85) {
            Write-Host "   ❌ Temperature: CRITICAL - $temperature°C" -ForegroundColor Red
            $healthResults.Issues += "System temperature is critically high"
        } elseif ($temperature -gt 75) {
            Write-Host "   ⚠️ Temperature: WARNING - $temperature°C" -ForegroundColor Yellow
            $healthResults.Warnings += "System temperature is high"
        }
    }
} catch {
    Write-Host "   ❌ Temperature Check: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $healthResults.Issues += "Cannot access temperature information"
}

# 6. Network Check
Write-Host "6️⃣ Network Check..." -ForegroundColor Yellow
try {
    $networkAdapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Loopback*"}
    if ($networkAdapters) {
        Write-Host "   ✅ Network: $($networkAdapters.Count) active adapter(s)" -ForegroundColor Green

        # Test internet connectivity
        try {
            $pingResult = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
            if ($pingResult) {
                Write-Host "   ✅ Internet: Connected" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️ Internet: No connectivity" -ForegroundColor Yellow
                $healthResults.Warnings += "No internet connectivity"
            }
        } catch {
            Write-Host "   ⚠️ Internet: Cannot test connectivity" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ Network: No active adapters" -ForegroundColor Red
        $healthResults.Issues += "No active network adapters"
    }
} catch {
    Write-Host "   ❌ Network Check: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $healthResults.Issues += "Cannot access network information"
}

# 7. Security Check
Write-Host "7️⃣ Security Check..." -ForegroundColor Yellow
try {
    # Check Windows Defender
    $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defender) {
        if ($defender.AntivirusEnabled) {
            Write-Host "   ✅ Windows Defender: Enabled" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️ Windows Defender: Disabled" -ForegroundColor Yellow
            $healthResults.Warnings += "Windows Defender is disabled"
        }
    } else {
        Write-Host "   ⚠️ Windows Defender: Status unknown" -ForegroundColor Yellow
    }

    # Check Firewall
    $firewall = Get-NetFirewallProfile | Where-Object {$_.Enabled -eq $false}
    if ($firewall) {
        Write-Host "   ⚠️ Firewall: Some profiles disabled" -ForegroundColor Yellow
        $healthResults.Warnings += "Some firewall profiles are disabled"
    } else {
        Write-Host "   ✅ Firewall: All profiles enabled" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ Security Check: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $healthResults.Issues += "Cannot access security information"
}

# 8. System File Check
Write-Host "8️⃣ System File Check..." -ForegroundColor Yellow
try {
    $sfcResult = sfc /verifyonly 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ System Files: No integrity violations" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ System Files: Integrity violations detected" -ForegroundColor Yellow
        $healthResults.Warnings += "System file integrity violations detected"
        $healthResults.Recommendations += "Run 'sfc /scannow' to repair system files"
    }
} catch {
    Write-Host "   ❌ System File Check: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $healthResults.Issues += "Cannot verify system file integrity"
}

# Overall Health Assessment
Write-Host ""
Write-Host "📊 HEALTH SUMMARY" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan

if ($healthResults.Issues.Count -eq 0 -and $healthResults.Warnings.Count -eq 0) {
    $healthResults.Overall = "Excellent"
    Write-Host "🎉 Overall Health: EXCELLENT" -ForegroundColor Green
    Write-Host "Your system is in great condition!" -ForegroundColor Green
} elseif ($healthResults.Issues.Count -eq 0) {
    $healthResults.Overall = "Good"
    Write-Host "✅ Overall Health: GOOD" -ForegroundColor Green
    Write-Host "Minor warnings detected, but system is healthy." -ForegroundColor Green
} elseif ($healthResults.Issues.Count -le 2) {
    $healthResults.Overall = "Fair"
    Write-Host "⚠️ Overall Health: FAIR" -ForegroundColor Yellow
    Write-Host "Some issues detected that should be addressed." -ForegroundColor Yellow
} else {
    $healthResults.Overall = "Poor"
    Write-Host "❌ Overall Health: POOR" -ForegroundColor Red
    Write-Host "Multiple issues detected that need immediate attention." -ForegroundColor Red
}

# Display Issues
if ($healthResults.Issues.Count -gt 0) {
    Write-Host ""
    Write-Host "🚨 ISSUES DETECTED:" -ForegroundColor Red
    foreach ($issue in $healthResults.Issues) {
        Write-Host "   • $issue" -ForegroundColor Red
    }
}

# Display Warnings
if ($healthResults.Warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️ WARNINGS:" -ForegroundColor Yellow
    foreach ($warning in $healthResults.Warnings) {
        Write-Host "   • $warning" -ForegroundColor Yellow
    }
}

# Display Recommendations
if ($healthResults.Recommendations.Count -gt 0) {
    Write-Host ""
    Write-Host "💡 RECOMMENDATIONS:" -ForegroundColor Cyan
    foreach ($recommendation in $healthResults.Recommendations) {
        Write-Host "   • $recommendation" -ForegroundColor Cyan
    }
}

# Generate Report
if ($GenerateReport) {
    $reportPath = ".\health-report-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').html"
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Health Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .excellent { color: #27ae60; }
        .good { color: #2ecc71; }
        .fair { color: #f39c12; }
        .poor { color: #e74c3c; }
        .issue { background-color: #e74c3c; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .warning { background-color: #f39c12; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .recommendation { background-color: #3498db; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 System Health Report</h1>
        <p>Generated: $($systemInfo.CheckTime)</p>
        <p>Computer: $($systemInfo.ComputerName) | User: $($systemInfo.Username)</p>
    </div>

    <h2>System Information</h2>
    <p><strong>OS:</strong> $($systemInfo.OS)</p>
    <p><strong>Version:</strong> $($systemInfo.Version)</p>
    <p><strong>Architecture:</strong> $($systemInfo.Architecture)</p>

    <h2>Health Assessment</h2>
    <p class="$($healthResults.Overall.ToLower())"><strong>Overall Health:</strong> $($healthResults.Overall.ToUpper())</p>

    <h2>Issues ($($healthResults.Issues.Count))</h2>
    $(if ($healthResults.Issues.Count -gt 0) {
        foreach ($issue in $healthResults.Issues) {
            "<div class='issue'>• $issue</div>"
        }
    } else {
        "<p>No issues detected.</p>"
    })

    <h2>Warnings ($($healthResults.Warnings.Count))</h2>
    $(if ($healthResults.Warnings.Count -gt 0) {
        foreach ($warning in $healthResults.Warnings) {
            "<div class='warning'>• $warning</div>"
        }
    } else {
        "<p>No warnings.</p>"
    })

    <h2>Recommendations ($($healthResults.Recommendations.Count))</h2>
    $(if ($healthResults.Recommendations.Count -gt 0) {
        foreach ($recommendation in $healthResults.Recommendations) {
            "<div class='recommendation'>• $recommendation</div>"
        }
    } else {
        "<p>No recommendations.</p>"
    })
</body>
</html>
"@

    $html | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host ""
    Write-Host "📊 Health report generated: $reportPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "🔍 Enhanced System Health Check completed!" -ForegroundColor Cyan
