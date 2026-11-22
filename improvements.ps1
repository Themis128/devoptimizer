# DevOptimizer Improvements Execution Script
# Run elevated for items 2, 3, 4; user-level for item 1

$ErrorActionPreference = 'Continue'

function Log($m) { 
    $l = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"
    Write-Host $l
    Add-Content "D:\DevOptimizer\logs\improvements.log" $l
}

Log "=== DevOptimizer Improvements Started ==="

# 1. Disable startup bloat (user-level, no elevation needed)
Log "--- 1. Disabling startup bloat ---"
$startupKeys = @(
    "EPSDNMON",
    "Teams",
    "MicrosoftEdgeAutoLaunch_A01BB405273478455F34CB9FB316D156",
    "Grok Bot"
)

foreach ($key in $startupKeys) {
    try {
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $key -ErrorAction Stop
        Log "Removed startup: $key"
    } catch {
        Log "Startup $key not found or already removed: $($_.Exception.Message)"
    }
}

# 2. Enable Storage Sense (user-level)
Log "--- 2. Enabling Storage Sense ---"
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense" -Name "StorageSenseEnabled" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense" -Name "StorageSenseGlobal" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense" -Name "CleanupTempFiles" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense" -Name "CleanupRecycleBin" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense" -Name "CleanupDownloads" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense" -Name "CleanupCloudContent" -Value 1 -Type DWord -Force -ErrorAction Stop
    Log "Storage Sense enabled with all cleanup options"
} catch {
    Log "Storage Sense config failed: $($_.Exception.Message)"
}

Log "=== User-level improvements done ==="
Log "For elevated improvements (component store, VHDX compaction), run as Administrator"