Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              Dashboard Diagnostic Test                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Testing components...`n" -ForegroundColor Yellow

# Test 1: PowerShell version
Write-Host "1. PowerShell Version:" -ForegroundColor Cyan
Write-Host "   $($PSVersionTable.PSVersion)" -ForegroundColor White

# Test 2: Can we get VS Code processes?
Write-Host "`n2. VS Code Processes:" -ForegroundColor Cyan
try {
    $procs = Get-Process -Name "Code - Insiders" -ErrorAction Stop
    Write-Host "   Found: $($procs.Count) processes" -ForegroundColor Green
    foreach ($p in ($procs | Select-Object -First 3)) {
        $mb = [math]::Round($p.WorkingSet64 / 1MB, 2)
        Write-Host "   - PID $($p.Id): $mb MB" -ForegroundColor White
    }
} catch {
    Write-Host "   Not running (this is OK)" -ForegroundColor Yellow
}

# Test 3: Can we get monitor processes?
Write-Host "`n3. Monitor Processes:" -ForegroundColor Cyan
try {
    $monitors = Get-Process -Name "pwsh","powershell" -ErrorAction SilentlyContinue |
        Where-Object { 
            try { $_.CommandLine -like "*Monitor*.ps1*" } catch { $false }
        }
    if ($monitors) {
        Write-Host "   Found: $($monitors.Count) monitor(s)" -ForegroundColor Green
    } else {
        Write-Host "   Not running (this is OK)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Error checking: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Can we get system info?
Write-Host "`n4. System Memory:" -ForegroundColor Cyan
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    Write-Host "   Total: $totalGB GB" -ForegroundColor White
    Write-Host "   Free:  $freeGB GB" -ForegroundColor White
} catch {
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Dashboard file exists?
Write-Host "`n5. Dashboard File:" -ForegroundColor Cyan
$dashPath = "D:\DevOptimizer\Monitor-Dashboard.ps1"
if (Test-Path $dashPath) {
    $size = (Get-Item $dashPath).Length
    Write-Host "   Exists: Yes ($size bytes)" -ForegroundColor Green
} else {
    Write-Host "   Exists: NO - File missing!" -ForegroundColor Red
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

# Now try to run the dashboard
Write-Host "`nAttempting to run dashboard...`n" -ForegroundColor Yellow

try {
    & "D:\DevOptimizer\Monitor-Dashboard.ps1" -ErrorAction Stop
} catch {
    Write-Host "Dashboard Error:" -ForegroundColor Red
    Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
