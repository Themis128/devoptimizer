# VHDX Compaction - MUST RUN AS ADMINISTRATOR

$vhdx = "C:\Users\tbaltzakis\AppData\Local\wsl\{12c19879-cec8-4dd1-9fe4-7049940b6a2f}\ext4.vhdx"

Write-Host "=== WSL VHDX Compaction ===" -ForegroundColor Cyan
Write-Host "VHDX: $vhdx" -ForegroundColor Yellow

if (-not (Test-Path $vhdx)) {
    Write-Host "VHDX not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$before = (Get-Item $vhdx).Length
Write-Host "Before: $([math]::Round($before/1GB,2)) GB" -ForegroundColor Green

# Kill WSL processes
Write-Host "`nStopping WSL..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep 5

# Kill any remaining vmmem processes
Get-Process -Name "vmmemWSL", "vmmem" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "Killing $($_.ProcessName) (PID $($_.Id))"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

# Compact
Write-Host "`nCompacting VHDX (this may take 1-2 minutes)..." -ForegroundColor Yellow
try {
    Optimize-VHD -Path $vhdx -Mode Full -ErrorAction Stop
    $after = (Get-Item $vhdx).Length
    Write-Host "`nSUCCESS!" -ForegroundColor Green
    Write-Host "After:  $([math]::Round($after/1GB,2)) GB" -ForegroundColor Green
    Write-Host "Freed:  $([math]::Round(($before-$after)/1GB,2)) GB" -ForegroundColor Green
} catch {
    Write-Host "`nFAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nTrying Mount-VHD approach..." -ForegroundColor Yellow
    try {
        Mount-VHD -Path $vhdx -ReadOnly -ErrorAction Stop
        Optimize-VHD -Path $vhdx -Mode Full -ErrorAction Stop
        Dismount-VHD -Path $vhdx -ErrorAction Stop
        $after = (Get-Item $vhdx).Length
        Write-Host "SUCCESS (alt)!" -ForegroundColor Green
        Write-Host "After:  $([math]::Round($after/1GB,2)) GB" -ForegroundColor Green
        Write-Host "Freed:  $([math]::Round(($before-$after)/1GB,2)) GB" -ForegroundColor Green
    } catch {
        Write-Host "FAILED (alt): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Read-Host "`nPress Enter to exit"