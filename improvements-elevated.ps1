# DevOptimizer Elevated Improvements
# MUST RUN AS ADMINISTRATOR

$ErrorActionPreference = 'Continue'

function Log($m) { 
    $l = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"
    Write-Host $l
    Add-Content "D:\DevOptimizer\logs\improvements-elevated.log" $l
}

Log "=== DevOptimizer Elevated Improvements Started ==="

# Check elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Log "ERROR: Not running as Administrator. Exiting."
    exit 1
}

# 3. Component Store Cleanup
Log "--- 3. Component Store Cleanup (DISM) ---"
Log "Running: dism /online /cleanup-image /startcomponentcleanup /resetbase"
try {
    $result = & dism /online /cleanup-image /startcomponentcleanup /resetbase 2>&1
    $result | ForEach-Object { Log "DISM: $_" }
    Log "Component store cleanup completed"
} catch {
    Log "DISM failed: $($_.Exception.Message)"
}

# 4. Delivery Optimization Cache Clear
Log "--- 4. Delivery Optimization Cache ---"
try {
    Stop-Service -Name 'DoSvc' -Force -ErrorAction SilentlyContinue
    $doCache = "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization"
    if (Test-Path $doCache) {
        $before = (Get-ChildItem $doCache -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        Remove-Item "$doCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        $after = (Get-ChildItem $doCache -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $freed = [math]::Round(($before - $after) / 1GB, 2)
        Log "Delivery Optimization cache cleared: $freed GB freed"
    }
    Start-Service -Name 'DoSvc' -ErrorAction SilentlyContinue
} catch {
    Log "Delivery Optimization cleanup failed: $($_.Exception.Message)"
}

# 5. Shadow Copy Cleanup (oldest only)
Log "--- 5. Shadow Copy Cleanup ---"
try {
    $shadows = & vssadmin list shadows /for=C: 2>&1
    if ($shadows -match 'Shadow Copy Volume') {
        Log "Running: vssadmin delete shadows /for=C: /oldest"
        & vssadmin delete shadows /for=C: /oldest 2>&1 | ForEach-Object { Log "VSS: $_" }
    } else {
        Log "No shadow copies found on C:"
    }
} catch {
    Log "Shadow copy cleanup failed: $($_.Exception.Message)"
}

# 6. VHDX Compaction (ext4.vhdx + docker_data.vhdx)
Log "--- 6. VHDX Compaction ---"
Log "Running nightly-wsl-vhdx-compact.ps1..."
try {
    & "D:\DevOptimizer\logs\nightly-wsl-vhdx-compact.ps1" 2>&1 | ForEach-Object { Log "VHDX: $_" }
    Log "VHDX compaction completed"
} catch {
    Log "VHDX compaction failed: $($_.Exception.Message)"
}

Log "=== Elevated Improvements Done ==="