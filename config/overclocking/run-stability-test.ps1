# Stability Test Script
# Guides through running stability tests for overclocking

param(
    [int]$TestDurationMinutes = 30,
    [string]$TestType = 'auto'
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Overclocking Stability Test' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Test Configuration:' -ForegroundColor Yellow
Write-Host "  Duration: $TestDurationMinutes minutes" -ForegroundColor White
Write-Host "  Type: $TestType" -ForegroundColor White
Write-Host ''

# Check for available stress test tools
Write-Host 'Checking for stress test tools...' -ForegroundColor Yellow
Write-Host ''

$toolsFound = @()

# Check for FurMark
$furmarkPaths = @(
    "$env:ProgramFiles\Geeks3D\FurMark\FurMark.exe",
    "$env:ProgramFiles(x86)\Geeks3D\FurMark\FurMark.exe",
    "$env:USERPROFILE\Downloads\FurMark.exe"
)

foreach ($path in $furmarkPaths) {
    if (Test-Path $path) {
        $toolsFound += @{ Name = 'FurMark'; Path = $path; Type = 'GPU' }
        Write-Host '[OK] FurMark found' -ForegroundColor Green
        break
    }
}

# Check for MSI Afterburner benchmark
$msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1
if ($msiProcess) {
    $toolsFound += @{ Name = 'MSI Afterburner Benchmark'; Path = 'Built-in'; Type = 'GPU' }
    Write-Host '[OK] MSI Afterburner (has built-in benchmark)' -ForegroundColor Green
}

# Check for Intel XTU
$xtuPaths = @(
    "C:\Program Files (x86)\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
    "C:\Program Files\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
)

foreach ($path in $xtuPaths) {
    if (Test-Path $path) {
        $toolsFound += @{ Name = 'Intel XTU'; Path = $path; Type = 'CPU' }
        Write-Host '[OK] Intel XTU found (has built-in stress test)' -ForegroundColor Green
        break
    }
}

# Check for 3DMark
$mark3dPaths = @(
    "$env:ProgramFiles\Unigine\Heaven Benchmark\heaven.exe",
    "$env:ProgramFiles(x86)\Unigine\Heaven Benchmark\heaven.exe"
)

foreach ($path in $mark3dPaths) {
    if (Test-Path $path) {
        $toolsFound += @{ Name = 'Unigine Heaven'; Path = $path; Type = 'GPU' }
        Write-Host '[OK] Unigine Heaven found' -ForegroundColor Green
        break
    }
}

if ($toolsFound.Count -eq 0) {
    Write-Host '[INFO] No stress test tools detected' -ForegroundColor Gray
    Write-Host '  Will provide manual testing instructions' -ForegroundColor Gray
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Stability Test Options' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# GPU Stress Test
Write-Host '=== GPU Stress Test ===' -ForegroundColor Yellow
Write-Host ''

if ($toolsFound | Where-Object { $_.Type -eq 'GPU' }) {
    $gpuTools = $toolsFound | Where-Object { $_.Type -eq 'GPU' }
    Write-Host 'Available GPU stress test tools:' -ForegroundColor White
    foreach ($tool in $gpuTools) {
        Write-Host "  - $($tool.Name)" -ForegroundColor Gray
    }
    Write-Host ''
}

Write-Host 'Option 1: MSI Afterburner Built-in Benchmark' -ForegroundColor Cyan
Write-Host '  1. Open MSI Afterburner' -ForegroundColor White
Write-Host '  2. Click the "K" icon (Kombustor benchmark)' -ForegroundColor White
Write-Host '  3. Select a preset (e.g., 1080p)' -ForegroundColor White
Write-Host '  4. Click "Run" and monitor for ' -NoNewline -ForegroundColor White
Write-Host "$TestDurationMinutes minutes" -ForegroundColor Yellow
Write-Host '  5. Watch for:' -ForegroundColor White
Write-Host '     - Artifacts (visual glitches)' -ForegroundColor Gray
Write-Host '     - Crashes or freezes' -ForegroundColor Gray
Write-Host '     - Temperature above 83°C' -ForegroundColor Gray
Write-Host '     - Throttling (clock speeds dropping)' -ForegroundColor Gray
Write-Host ''

Write-Host 'Option 2: FurMark (If Installed)' -ForegroundColor Cyan
Write-Host '  1. Launch FurMark' -ForegroundColor White
Write-Host '  2. Select resolution (e.g., 1920x1080)' -ForegroundColor White
Write-Host '  3. Click "GPU stress test"' -ForegroundColor White
Write-Host "  4. Run for $TestDurationMinutes minutes" -ForegroundColor White
Write-Host '  5. Monitor temperatures and watch for issues' -ForegroundColor White
Write-Host ''

Write-Host 'Option 3: Demanding Game' -ForegroundColor Cyan
Write-Host '  1. Launch a demanding game' -ForegroundColor White
Write-Host '  2. Play at maximum settings' -ForegroundColor White
Write-Host "  3. Play for $TestDurationMinutes minutes" -ForegroundColor White
Write-Host '  4. Monitor for:' -ForegroundColor White
Write-Host '     - Crashes' -ForegroundColor Gray
Write-Host '     - Artifacts' -ForegroundColor Gray
Write-Host '     - High temperatures' -ForegroundColor Gray
Write-Host '     - Performance drops' -ForegroundColor Gray
Write-Host ''

# CPU Stress Test
Write-Host '=== CPU Stress Test ===' -ForegroundColor Yellow
Write-Host ''

if ($toolsFound | Where-Object { $_.Type -eq 'CPU' }) {
    $cpuTools = $toolsFound | Where-Object { $_.Type -eq 'CPU' }
    Write-Host 'Available CPU stress test tools:' -ForegroundColor White
    foreach ($tool in $cpuTools) {
        Write-Host "  - $($tool.Name)" -ForegroundColor Gray
    }
    Write-Host ''
}

Write-Host 'Option 1: Intel XTU Stress Test' -ForegroundColor Cyan
Write-Host '  1. Open Intel XTU' -ForegroundColor White
Write-Host '  2. Click "Stress Test" button' -ForegroundColor White
Write-Host "  3. Run for $TestDurationMinutes minutes" -ForegroundColor White
Write-Host '  4. Monitor:' -ForegroundColor White
Write-Host '     - Core Temperature (< 90°C)' -ForegroundColor Gray
Write-Host '     - Package Temperature (< 95°C)' -ForegroundColor Gray
Write-Host '     - Throttling indicators' -ForegroundColor Gray
Write-Host '     - System stability' -ForegroundColor Gray
Write-Host ''

Write-Host 'Option 2: Prime95 (If Installed)' -ForegroundColor Cyan
Write-Host '  1. Launch Prime95' -ForegroundColor White
Write-Host '  2. Select "Just stress testing"' -ForegroundColor White
Write-Host '  3. Choose "Small FFTs" or "Blend"' -ForegroundColor White
Write-Host "  4. Run for $TestDurationMinutes minutes" -ForegroundColor White
Write-Host '  5. Monitor temperatures and watch for errors' -ForegroundColor White
Write-Host ''

Write-Host 'Option 3: AIDA64 (If Installed)' -ForegroundColor Cyan
Write-Host '  1. Launch AIDA64' -ForegroundColor White
Write-Host '  2. Go to Tools > System Stability Test' -ForegroundColor White
Write-Host '  3. Select CPU and/or GPU stress tests' -ForegroundColor White
Write-Host "  4. Run for $TestDurationMinutes minutes" -ForegroundColor White
Write-Host '  5. Monitor all sensors' -ForegroundColor White
Write-Host ''

# Combined Test
Write-Host '=== Combined CPU + GPU Test ===' -ForegroundColor Yellow
Write-Host ''
Write-Host 'For comprehensive testing:' -ForegroundColor White
Write-Host '  1. Run GPU stress test (FurMark, MSI Afterburner benchmark)' -ForegroundColor Gray
Write-Host '  2. Simultaneously run CPU stress test (Intel XTU, Prime95)' -ForegroundColor Gray
Write-Host "  3. Run both for $TestDurationMinutes minutes" -ForegroundColor Gray
Write-Host '  4. Monitor all temperatures and system stability' -ForegroundColor Gray
Write-Host '  5. This tests power sharing between CPU and GPU' -ForegroundColor Gray
Write-Host ''

Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Test Checklist' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Before Testing:' -ForegroundColor Yellow
Write-Host '  [ ] Overclocking settings applied' -ForegroundColor White
Write-Host '  [ ] Temperature monitoring enabled (MSI Afterburner OSD)' -ForegroundColor White
Write-Host '  [ ] Adequate cooling available' -ForegroundColor White
Write-Host '  [ ] System is stable at idle' -ForegroundColor White
Write-Host ''
Write-Host 'During Testing:' -ForegroundColor Yellow
Write-Host '  [ ] Monitor GPU temperature (< 83°C)' -ForegroundColor White
Write-Host '  [ ] Monitor CPU temperature (< 90°C)' -ForegroundColor White
Write-Host '  [ ] Watch for artifacts or visual glitches' -ForegroundColor White
Write-Host '  [ ] Watch for crashes or freezes' -ForegroundColor White
Write-Host '  [ ] Monitor clock speeds (watch for throttling)' -ForegroundColor White
Write-Host '  [ ] Check power consumption' -ForegroundColor White
Write-Host ''
Write-Host 'After Testing:' -ForegroundColor Yellow
Write-Host '  [ ] System remained stable (no crashes)' -ForegroundColor White
Write-Host '  [ ] No artifacts observed' -ForegroundColor White
Write-Host '  [ ] Temperatures stayed within limits' -ForegroundColor White
Write-Host '  [ ] No throttling occurred' -ForegroundColor White
Write-Host '  [ ] Performance is as expected' -ForegroundColor White
Write-Host ''

# Launch tools if available
if ($TestType -eq 'auto' -and $toolsFound.Count -gt 0) {
    Write-Host 'Would you like to launch a stress test tool? (Y/N)' -ForegroundColor Yellow
    $launch = Read-Host

    if ($launch -eq 'Y' -or $launch -eq 'y') {
        Write-Host ''
        Write-Host 'Available tools:' -ForegroundColor Cyan
        for ($i = 0; $i -lt $toolsFound.Count; $i++) {
            Write-Host "  $($i + 1). $($toolsFound[$i].Name)" -ForegroundColor White
        }
        Write-Host ''
        $choice = Read-Host 'Enter number to launch (or press Enter to skip)'

        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $toolsFound.Count) {
            $selectedTool = $toolsFound[[int]$choice - 1]
            Write-Host ''
            Write-Host "Launching $($selectedTool.Name)..." -ForegroundColor Yellow

            if ($selectedTool.Path -ne 'Built-in') {
                Start-Process -FilePath $selectedTool.Path
                Write-Host "[OK] $($selectedTool.Name) launched" -ForegroundColor Green
            }
            else {
                Write-Host "[INFO] $($selectedTool.Name) is already running" -ForegroundColor Gray
                Write-Host '  Use the built-in benchmark feature' -ForegroundColor Gray
            }
        }
    }
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Stability Test Guide Complete!' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "Recommended: Run stress test for $TestDurationMinutes minutes minimum" -ForegroundColor Yellow
Write-Host '  - 15 minutes: Quick test' -ForegroundColor Gray
Write-Host '  - 30 minutes: Standard test' -ForegroundColor Gray
Write-Host '  - 60 minutes: Thorough test' -ForegroundColor Gray
Write-Host ''
Write-Host 'If test passes: Settings are stable!' -ForegroundColor Green
Write-Host 'If test fails: Reduce overclocking values and test again' -ForegroundColor Yellow
Write-Host ''
