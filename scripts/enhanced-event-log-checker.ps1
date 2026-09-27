# Enhanced Event Log Checker
# Provides detailed analysis of system, application, and security events

<#+
.SYNOPSIS
Analyzes recent Windows event logs and summarizes system health indicators.

.DESCRIPTION
Collects critical, warning, and informational entries from system, application, and security logs over a configurable time window. Optionally outputs detailed findings and exports a report.

.PARAMETER Hours
Controls the look-back window when querying event logs. Defaults to 24 hours.

.PARAMETER Detailed
Includes top event samples and extended diagnostics in the console output.

.PARAMETER ExportReport
Writes the summarized analysis to a structured report file.

.EXAMPLE
PS> .\enhanced-event-log-checker.ps1 -Hours 12 -Detailed
Checks the last 12 hours of events and displays detailed entries in the console.

.EXAMPLE
PS> .\enhanced-event-log-checker.ps1 -ExportReport
Runs the standard 24-hour analysis and saves the report for later review.

.NOTES
Author: DevOptimizer automation tools
#>

param(
    [int]$Hours = 24,
    [switch]$Detailed,
    [switch]$ExportReport
)

Write-Host "🔍 Enhanced Event Log Analysis" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# System Information
$systemInfo = @{
    "ComputerName" = $env:COMPUTERNAME
    "Username" = $env:USERNAME
    "CheckTime" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "AnalysisPeriod" = "$Hours hours"
}

Write-Host "🖥️ System Information:" -ForegroundColor Green
Write-Host "Computer: $($systemInfo.ComputerName)" -ForegroundColor White
Write-Host "User: $($systemInfo.Username)" -ForegroundColor White
Write-Host "Check Time: $($systemInfo.CheckTime)" -ForegroundColor White
Write-Host "Analysis Period: $($systemInfo.AnalysisPeriod)" -ForegroundColor White
Write-Host ""

# Analysis Results
$analysisResults = @{
    "Overall" = "Good"
    "CriticalIssues" = @()
    "Warnings" = @()
    "Info" = @()
    "Recommendations" = @()
}

# 1. System Events Analysis
Write-Host "1️⃣ System Events Analysis..." -ForegroundColor Yellow
try {
    $systemErrors = Get-EventLog -LogName System -EntryType Error -After (Get-Date).AddHours(-$Hours) -ErrorAction SilentlyContinue
    $systemWarnings = Get-EventLog -LogName System -EntryType Warning -After (Get-Date).AddHours(-$Hours) -ErrorAction SilentlyContinue

    if ($systemErrors) {
        Write-Host "   ❌ System Errors: $($systemErrors.Count) found" -ForegroundColor Red
        $analysisResults.CriticalIssues += "System errors detected: $($systemErrors.Count)"

        if ($Detailed) {
            Write-Host "   Recent System Errors:" -ForegroundColor Red
            $systemErrors | Select-Object -First 5 | ForEach-Object {
                Write-Host "     • $($_.TimeGenerated) - $($_.Source) - $($_.Message.Substring(0, [Math]::Min(100, $_.Message.Length)))..." -ForegroundColor Red
            }
        }
    } else {
        Write-Host "   ✅ System Errors: None found" -ForegroundColor Green
    }

    if ($systemWarnings) {
        Write-Host "   ⚠️ System Warnings: $($systemWarnings.Count) found" -ForegroundColor Yellow
        $analysisResults.Warnings += "System warnings: $($systemWarnings.Count)"
    } else {
        Write-Host "   ✅ System Warnings: None found" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ System Events: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $analysisResults.CriticalIssues += "Cannot access system event log"
}

# 2. Application Events Analysis
Write-Host "2️⃣ Application Events Analysis..." -ForegroundColor Yellow
try {
    $appErrors = Get-EventLog -LogName Application -EntryType Error -After (Get-Date).AddHours(-$Hours) -ErrorAction SilentlyContinue
    $appWarnings = Get-EventLog -LogName Application -EntryType Warning -After (Get-Date).AddHours(-$Hours) -ErrorAction SilentlyContinue

    if ($appErrors) {
        Write-Host "   ❌ Application Errors: $($appErrors.Count) found" -ForegroundColor Red
        $analysisResults.CriticalIssues += "Application errors detected: $($appErrors.Count)"

        if ($Detailed) {
            Write-Host "   Recent Application Errors:" -ForegroundColor Red
            $appErrors | Select-Object -First 5 | ForEach-Object {
                Write-Host "     • $($_.TimeGenerated) - $($_.Source) - $($_.Message.Substring(0, [Math]::Min(100, $_.Message.Length)))..." -ForegroundColor Red
            }
        }
    } else {
        Write-Host "   ✅ Application Errors: None found" -ForegroundColor Green
    }

    if ($appWarnings) {
        Write-Host "   ⚠️ Application Warnings: $($appWarnings.Count) found" -ForegroundColor Yellow
        $analysisResults.Warnings += "Application warnings: $($appWarnings.Count)"
    } else {
        Write-Host "   ✅ Application Warnings: None found" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ Application Events: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $analysisResults.CriticalIssues += "Cannot access application event log"
}

# 3. Security Events Analysis
Write-Host "3️⃣ Security Events Analysis..." -ForegroundColor Yellow
try {
    $securityEvents = Get-EventLog -LogName Security -After (Get-Date).AddHours(-$Hours) -ErrorAction SilentlyContinue

    if ($securityEvents) {
        # Analyze security events by type
        $failedLogons = $securityEvents | Where-Object {$_.EventID -eq 4625}
        $successfulLogons = $securityEvents | Where-Object {$_.EventID -eq 4624}
        $cryptoEvents = $securityEvents | Where-Object {$_.EventID -eq 5061}
        $otherSecurityEvents = $securityEvents | Where-Object {$_.EventID -notin @(4624, 4625, 5061)}

        Write-Host "   📊 Security Events Summary:" -ForegroundColor Cyan
        Write-Host "     • Total Events: $($securityEvents.Count)" -ForegroundColor White
        Write-Host "     • Successful Logons: $($successfulLogons.Count)" -ForegroundColor Green
        Write-Host "     • Failed Logons: $($failedLogons.Count)" -ForegroundColor $(if ($failedLogons.Count -gt 10) {"Red"} else {"Yellow"})
        Write-Host "     • Cryptographic Operations: $($cryptoEvents.Count)" -ForegroundColor Cyan
        Write-Host "     • Other Security Events: $($otherSecurityEvents.Count)" -ForegroundColor White

        # Check for suspicious activity
        if ($failedLogons.Count -gt 50) {
            Write-Host "   ⚠️ High number of failed logons detected: $($failedLogons.Count)" -ForegroundColor Yellow
            $analysisResults.Warnings += "High number of failed logons: $($failedLogons.Count)"
        }

        if ($cryptoEvents.Count -gt 100) {
            Write-Host "   ℹ️ Many cryptographic operations: $($cryptoEvents.Count) (likely Windows Hello)" -ForegroundColor Cyan
            $analysisResults.Info += "Many cryptographic operations: $($cryptoEvents.Count) (likely Windows Hello biometric authentication)"
        }

        # Check for specific security issues
        $suspiciousEvents = $securityEvents | Where-Object {
            $_.EventID -in @(4672, 4673, 4674, 4675) -or  # Privilege escalation
            $_.EventID -eq 4625 -and $_.Message -like "*Administrator*"  # Failed admin logons
        }

        if ($suspiciousEvents) {
            Write-Host "   🚨 Suspicious security events detected: $($suspiciousEvents.Count)" -ForegroundColor Red
            $analysisResults.CriticalIssues += "Suspicious security events: $($suspiciousEvents.Count)"
        }

    } else {
        Write-Host "   ⚠️ Security Events: No events found or access denied" -ForegroundColor Yellow
        $analysisResults.Warnings += "Cannot access security event log or no events found"
    }
} catch {
    Write-Host "   ❌ Security Events: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    $analysisResults.CriticalIssues += "Cannot access security event log"
}

# 4. Windows Update Events
Write-Host "4️⃣ Windows Update Events Analysis..." -ForegroundColor Yellow
try {
    $wuEvents = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-WindowsUpdateClient/Operational'; StartTime=(Get-Date).AddHours(-$Hours)} -ErrorAction SilentlyContinue

    if ($wuEvents) {
        $wuErrors = $wuEvents | Where-Object {$_.LevelDisplayName -eq 'Error'}
        $wuWarnings = $wuEvents | Where-Object {$_.LevelDisplayName -eq 'Warning'}
        $wuSuccess = $wuEvents | Where-Object {$_.LevelDisplayName -eq 'Information' -and $_.Id -in @(19, 20, 21, 22)}

        Write-Host "   📊 Windows Update Summary:" -ForegroundColor Cyan
        Write-Host "     • Total Events: $($wuEvents.Count)" -ForegroundColor White
        Write-Host "     • Errors: $($wuErrors.Count)" -ForegroundColor $(if ($wuErrors.Count -gt 0) {"Red"} else {"Green"})
        Write-Host "     • Warnings: $($wuWarnings.Count)" -ForegroundColor $(if ($wuWarnings.Count -gt 0) {"Yellow"} else {"Green"})
        Write-Host "     • Successful Operations: $($wuSuccess.Count)" -ForegroundColor Green

        if ($wuErrors) {
            $analysisResults.Warnings += "Windows Update errors: $($wuErrors.Count)"
        }
    } else {
        Write-Host "   ℹ️ Windows Update Events: No recent events found" -ForegroundColor Cyan
    }
} catch {
    Write-Host "   ⚠️ Windows Update Events: Cannot access (may require admin rights)" -ForegroundColor Yellow
}

# 5. Disk and Storage Events
Write-Host "5️⃣ Disk and Storage Events Analysis..." -ForegroundColor Yellow
try {
    $diskEvents = Get-EventLog -LogName System -After (Get-Date).AddHours(-$Hours) -ErrorAction SilentlyContinue | Where-Object {
        $_.Source -like "*Disk*" -or $_.Source -like "*Storage*" -or $_.Message -like "*disk*" -or $_.Message -like "*storage*"
    }

    if ($diskEvents) {
        $diskErrors = $diskEvents | Where-Object {$_.EntryType -eq 'Error'}
        $diskWarnings = $diskEvents | Where-Object {$_.EntryType -eq 'Warning'}

        Write-Host "   📊 Disk Events Summary:" -ForegroundColor Cyan
        Write-Host "     • Total Events: $($diskEvents.Count)" -ForegroundColor White
        Write-Host "     • Errors: $($diskErrors.Count)" -ForegroundColor $(if ($diskErrors.Count -gt 0) {"Red"} else {"Green"})
        Write-Host "     • Warnings: $($diskWarnings.Count)" -ForegroundColor $(if ($diskWarnings.Count -gt 0) {"Yellow"} else {"Green"})

        if ($diskErrors) {
            $analysisResults.CriticalIssues += "Disk errors detected: $($diskErrors.Count)"
        }
        if ($diskWarnings) {
            $analysisResults.Warnings += "Disk warnings: $($diskWarnings.Count)"
        }
    } else {
        Write-Host "   ✅ Disk Events: No issues found" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ Disk Events: ERROR - $($_.Exception.Message)" -ForegroundColor Red
}

# Overall Assessment
Write-Host ""
Write-Host "📊 EVENT LOG ANALYSIS SUMMARY" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

if ($analysisResults.CriticalIssues.Count -eq 0 -and $analysisResults.Warnings.Count -eq 0) {
    $analysisResults.Overall = "Excellent"
    Write-Host "🎉 Overall Status: EXCELLENT" -ForegroundColor Green
    Write-Host "No critical issues or warnings found in event logs!" -ForegroundColor Green
} elseif ($analysisResults.CriticalIssues.Count -eq 0) {
    $analysisResults.Overall = "Good"
    Write-Host "✅ Overall Status: GOOD" -ForegroundColor Green
    Write-Host "Minor warnings detected, but no critical issues." -ForegroundColor Green
} elseif ($analysisResults.CriticalIssues.Count -le 2) {
    $analysisResults.Overall = "Fair"
    Write-Host "⚠️ Overall Status: FAIR" -ForegroundColor Yellow
    Write-Host "Some issues detected that should be addressed." -ForegroundColor Yellow
} else {
    $analysisResults.Overall = "Poor"
    Write-Host "❌ Overall Status: POOR" -ForegroundColor Red
    Write-Host "Multiple critical issues detected that need immediate attention." -ForegroundColor Red
}

# Display Issues
if ($analysisResults.CriticalIssues.Count -gt 0) {
    Write-Host ""
    Write-Host "🚨 CRITICAL ISSUES:" -ForegroundColor Red
    foreach ($issue in $analysisResults.CriticalIssues) {
        Write-Host "   • $issue" -ForegroundColor Red
    }
}

# Display Warnings
if ($analysisResults.Warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️ WARNINGS:" -ForegroundColor Yellow
    foreach ($warning in $analysisResults.Warnings) {
        Write-Host "   • $warning" -ForegroundColor Yellow
    }
}

# Display Info
if ($analysisResults.Info.Count -gt 0) {
    Write-Host ""
    Write-Host "ℹ️ INFORMATION:" -ForegroundColor Cyan
    foreach ($info in $analysisResults.Info) {
        Write-Host "   • $info" -ForegroundColor Cyan
    }
}

# Generate Recommendations
if ($analysisResults.CriticalIssues.Count -gt 0) {
    $analysisResults.Recommendations += "Address critical issues immediately"
}
if ($analysisResults.Warnings.Count -gt 0) {
    $analysisResults.Recommendations += "Monitor warnings and address if they persist"
}
if ($analysisResults.Info -like "*cryptographic*") {
    $analysisResults.Recommendations += "Consider reviewing Windows Hello settings if cryptographic operations are excessive"
}

# Display Recommendations
if ($analysisResults.Recommendations.Count -gt 0) {
    Write-Host ""
    Write-Host "💡 RECOMMENDATIONS:" -ForegroundColor Cyan
    foreach ($recommendation in $analysisResults.Recommendations) {
        Write-Host "   • $recommendation" -ForegroundColor Cyan
    }
}

# Export Report
if ($ExportReport) {
    $reportPath = ".\event-log-report-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').html"
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Event Log Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .excellent { color: #27ae60; }
        .good { color: #2ecc71; }
        .fair { color: #f39c12; }
        .poor { color: #e74c3c; }
        .issue { background-color: #e74c3c; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .warning { background-color: #f39c12; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .info { background-color: #3498db; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .recommendation { background-color: #9b59b6; color: white; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 Event Log Analysis Report</h1>
        <p>Generated: $($systemInfo.CheckTime)</p>
        <p>Computer: $($systemInfo.ComputerName) | User: $($systemInfo.Username)</p>
        <p>Analysis Period: $($systemInfo.AnalysisPeriod)</p>
    </div>

    <h2>Analysis Summary</h2>
    <p class="$($analysisResults.Overall.ToLower())"><strong>Overall Status:</strong> $($analysisResults.Overall.ToUpper())</p>

    <h2>Critical Issues ($($analysisResults.CriticalIssues.Count))</h2>
    $(if ($analysisResults.CriticalIssues.Count -gt 0) {
        foreach ($issue in $analysisResults.CriticalIssues) {
            "<div class='issue'>• $issue</div>"
        }
    } else {
        "<p>No critical issues detected.</p>"
    })

    <h2>Warnings ($($analysisResults.Warnings.Count))</h2>
    $(if ($analysisResults.Warnings.Count -gt 0) {
        foreach ($warning in $analysisResults.Warnings) {
            "<div class='warning'>• $warning</div>"
        }
    } else {
        "<p>No warnings.</p>"
    })

    <h2>Information ($($analysisResults.Info.Count))</h2>
    $(if ($analysisResults.Info.Count -gt 0) {
        foreach ($info in $analysisResults.Info) {
            "<div class='info'>• $info</div>"
        }
    } else {
        "<p>No additional information.</p>"
    })

    <h2>Recommendations ($($analysisResults.Recommendations.Count))</h2>
    $(if ($analysisResults.Recommendations.Count -gt 0) {
        foreach ($recommendation in $analysisResults.Recommendations) {
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
    Write-Host "📊 Event log report generated: $reportPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "🔍 Enhanced Event Log Analysis completed!" -ForegroundColor Cyan
