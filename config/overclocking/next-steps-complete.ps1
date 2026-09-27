# Complete Next Steps Workflow
# Runs verification, monitoring, and stability test guidance

param(
    [switch]$VerifyOnly,
    [switch]$MonitorOnly,
    [switch]$TestOnly,
    [int]$MonitorDuration = 5,
    [int]$TestDuration = 30
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Complete Next Steps Workflow' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

if (-not $VerifyOnly -and -not $MonitorOnly -and -not $TestOnly) {
    Write-Host 'This workflow will guide you through:' -ForegroundColor Yellow
    Write-Host '  1. Verify settings in MSI Afterburner GUI' -ForegroundColor White
    Write-Host '  2. Monitor temperatures during use' -ForegroundColor White
    Write-Host '  3. Test stability with stress test' -ForegroundColor White
    Write-Host ''
    Write-Host 'Press Enter to continue...' -ForegroundColor Yellow
    $null = Read-Host
}

# Step 1: Verify Settings
if (-not $MonitorOnly -and -not $TestOnly) {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '  STEP 1: Verify Settings' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    & "$PSScriptRoot\verify-settings.ps1"

    if (-not $VerifyOnly) {
        Write-Host 'Press Enter to continue to temperature monitoring...' -ForegroundColor Yellow
        $null = Read-Host
    }
}

# Step 2: Monitor Temperatures
if (-not $VerifyOnly -and -not $TestOnly) {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '  STEP 2: Monitor Temperatures' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    & "$PSScriptRoot\monitor-temperatures.ps1" -DurationMinutes $MonitorDuration

    if (-not $MonitorOnly) {
        Write-Host 'Press Enter to continue to stability testing...' -ForegroundColor Yellow
        $null = Read-Host
    }
}

# Step 3: Stability Test
if (-not $VerifyOnly -and -not $MonitorOnly) {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '  STEP 3: Stability Test' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    & "$PSScriptRoot\run-stability-test.ps1" -TestDurationMinutes $TestDuration
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Next Steps Complete!' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Summary:' -ForegroundColor Yellow
Write-Host '  ✅ Settings verified' -ForegroundColor Green
Write-Host '  ✅ Temperatures monitored' -ForegroundColor Green
Write-Host '  ✅ Stability test guidance provided' -ForegroundColor Green
Write-Host ''
Write-Host 'If all tests passed:' -ForegroundColor Cyan
Write-Host '  - Your overclocking settings are stable!' -ForegroundColor Green
Write-Host '  - You can use Profile 1 with confidence' -ForegroundColor Green
Write-Host '  - Monitor temperatures during normal use' -ForegroundColor White
Write-Host ''
Write-Host 'If tests failed:' -ForegroundColor Yellow
Write-Host '  - Reduce overclocking values' -ForegroundColor White
Write-Host '  - Test again with lower settings' -ForegroundColor White
Write-Host '  - Find the highest stable values' -ForegroundColor White
Write-Host ''
