<#
.SYNOPSIS
    Fixes bom.
.DESCRIPTION
    Fixes bom.
#>

$targets = @(
    'D:\DevOptimizer\ps\Bootstrap-DevEnvironment.ps1',
    'D:\DevOptimizer\ps\Collect-Metrics.ps1',
    'D:\DevOptimizer\ps\Register-ScheduledTasks.ps1',
    'D:\DevOptimizer\ps\Rollback-Changes.ps1',
    'D:\DevOptimizer\ps\Run-Analysis.ps1',
    'D:\DevOptimizer\ps\Security-Hardening.ps1',
    'D:\DevOptimizer\ps\Uninstall-DevOptimizer.ps1',
    'D:\DevOptimizer\ps\Verify-Installation.ps1',
    'D:\DevOptimizer\scripts\ADVANCED-DIAGNOSTICS.ps1',
    'D:\DevOptimizer\scripts\automation-module.ps1',
    'D:\DevOptimizer\scripts\enhanced-event-log-checker.ps1',
    'D:\DevOptimizer\scripts\enhanced-system-health.ps1',
    'D:\DevOptimizer\scripts\overclocking-manager.ps1',
    'D:\DevOptimizer\scripts\real-time-monitoring.ps1',
    'D:\DevOptimizer\scripts\UNIFIED-LAUNCHER.ps1',
    'D:\DevOptimizer\tools\normalize-bat-files-fixed.ps1',
    'D:\DevOptimizer\tools\normalize-bat-files.ps1',
    'D:\DevOptimizer\tools\ollama-analytics-dashboard.ps1',
    'D:\DevOptimizer\tools\update-all-ollama-scripts.ps1',
    'D:\DevOptimizer\Monitor-VSCodeInsiders.ps1',
    'D:\DevOptimizer\VS-Code-Cleanup-Launcher.ps1',
    'D:\DevOptimizer\vs.ps1',
    'D:\DevOptimizer\vscode-insiders-extension-config.ps1',
    'D:\DevOptimizer\Workspace-Launcher.ps1',
    'D:\DevOptimizer\wsl.ps1'
)

$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$bom = New-Object System.Text.UTF8Encoding($true)
$fixed = 0

foreach ($f in $targets) {
    try {
        $bytes = [IO.File]::ReadAllBytes($f)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF) { Write-Host "skip (already BOM): $f"; continue }
        $text = $utf8Strict.GetString($bytes)   # re-validate as strict UTF-8 before writing
        [IO.File]::WriteAllText($f, $text, $bom)
        $fixed++
        Write-Host "BOM added: $($f.Replace('D:\DevOptimizer\',''))"
    } catch {
        Write-Host "FAILED: $f -> $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host "`n$fixed files re-saved as UTF-8 with BOM"
