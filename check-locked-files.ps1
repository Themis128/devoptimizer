# Check for locked files that cause cleanup errors
Write-Host ""
Write-Host "Checking for locked files in common cleanup areas..." -ForegroundColor Cyan

$testPaths = @{
    "Edge Cache" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    "Teams Cache" = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache"
    "Windows Update" = "C:\Windows\SoftwareDistribution\Download"
    "WhatsApp" = "$env:LOCALAPPDATA\Packages\5319275A.WhatsAppDesktop_cv1g1gnamjy7m\LocalCache"
}

$lockedCount = 0
$unlockedCount = 0

foreach ($name in $testPaths.Keys) {
    $path = $testPaths[$name]
    if (Test-Path $path) {
        Write-Host ""
        Write-Host "[$name]" -ForegroundColor Yellow
        $files = Get-ChildItem $path -File -Force -ErrorAction SilentlyContinue | Select-Object -First 5
        foreach ($file in $files) {
            try {
                $handle = [IO.File]::Open($file.FullName, 'Open', 'Read', 'None')
                $handle.Close()
                Write-Host "  OK: $($file.Name)" -ForegroundColor Green
                $unlockedCount++
            } catch {
                Write-Host "  LOCKED: $($file.Name)" -ForegroundColor Red
                $lockedCount++
            }
        }
    }
}

Write-Host ""
Write-Host "[Summary]" -ForegroundColor Cyan
Write-Host "Locked files: $lockedCount" 
Write-Host "Unlocked: $unlockedCount"
Write-Host ""
Write-Host "Tip: Close browsers and Teams before running cleanup to reduce errors."
