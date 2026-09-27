# DevOptimizer Metrics Collection Script
# Run with: pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Collect-Metrics.ps1"

param(
    [int]$Duration = 300,
    [string]$OutputDir = "D:\DevOptimizer\metrics",
    [string]$CounterFile = "D:\DevOptimizer\configs\default-counters.txt",
    [int]$Interval = 5
)

$ErrorActionPreference = 'Stop'

# Import DevOptimizer module
$ModulePath = "D:\DevOptimizer\ps\DevOptimizer.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
} else {
    Write-Error "DevOptimizer module not found at: $ModulePath"
    exit 1
}

Write-Host "Starting DevOptimizer metrics collection..." -ForegroundColor Green
Write-Host "Duration: $Duration seconds" -ForegroundColor Yellow
Write-Host "Output Directory: $OutputDir" -ForegroundColor Yellow
Write-Host "Counter File: $CounterFile" -ForegroundColor Yellow

try {
    # Initialize DevOptimizer
    Initialize-DevOptimizer

    # Create output directory
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Get system metrics snapshot
    Write-Host "`nTaking system metrics snapshot..." -ForegroundColor Blue
    $SystemMetrics = Get-SystemMetrics
    $SnapshotFile = Join-Path $OutputDir "system_snapshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $SystemMetrics | ConvertTo-Json -Depth 3 | Out-File -FilePath $SnapshotFile -Encoding UTF8
    Write-Host "✓ System snapshot saved to: $SnapshotFile" -ForegroundColor Green

    # Start performance counter collection
    Write-Host "`nStarting performance counter collection..." -ForegroundColor Blue
    if (Test-Path $CounterFile) {
        $CounterContent = Get-Content $CounterFile
        $CounterResult = Start-PerformanceCollection -Duration $Duration -Counters $CounterContent
        Write-Host "✓ Performance collection started" -ForegroundColor Green
        Write-Host "Session: $($CounterResult.SessionName)" -ForegroundColor Cyan
        Write-Host "Output: $($CounterResult.OutputPath)" -ForegroundColor Cyan
    } else {
        Write-Warning "Counter file not found: $CounterFile"
        $CounterResult = Start-PerformanceCollection -Duration $Duration
        Write-Host "✓ Performance collection started with default counters" -ForegroundColor Green
    }

    # Start ETW trace (CPU profile)
    Write-Host "`nStarting ETW trace..." -ForegroundColor Blue
    $ETWResult = Start-ETWTrace -Profile "CPU" -Duration $Duration
    Write-Host "✓ ETW trace started" -ForegroundColor Green
    Write-Host "Profile: $($ETWResult.Profile)" -ForegroundColor Cyan

    # Export event logs
    Write-Host "`nExporting event logs..." -ForegroundColor Blue
    $LogNames = @(
        "System",
        "Application",
        "Microsoft-Windows-Diagnostics-Performance/Operational",
        "Microsoft-Windows-Kernel-Process/Analytic"
    )
    Export-EventLogs -LogNames $LogNames -StartTime (Get-Date).AddDays(-1)
    Write-Host "✓ Event logs exported" -ForegroundColor Green

    # Wait for collection to complete
    Write-Host "`nCollection in progress..." -ForegroundColor Blue
    $ProgressBar = 0
    $ProgressTotal = $Duration / $Interval

    for ($i = 0; $i -lt $Duration; $i += $Interval) {
        Start-Sleep -Seconds $Interval
        $ProgressBar++
        $Percent = [math]::Round(($ProgressBar / $ProgressTotal) * 100)
        Write-Progress -Activity "Metrics Collection" -Status "Collecting data..." -PercentComplete $Percent
    }

    Write-Progress -Activity "Metrics Collection" -Completed

    # Stop ETW trace
    Write-Host "`nStopping ETW trace..." -ForegroundColor Blue
    $ETWOutput = Stop-ETWTrace
    Write-Host "✓ ETW trace saved to: $ETWOutput" -ForegroundColor Green

    # Generate collection summary
    Write-Host "`nGenerating collection summary..." -ForegroundColor Blue
    $Summary = @{
        Timestamp = Get-Date
        Duration = $Duration
        OutputDirectory = $OutputDir
        FilesGenerated = @(
            $SnapshotFile,
            $CounterResult.OutputPath,
            $ETWOutput
        )
        EventLogs = $LogNames
        Status = "Completed"
    }

    $SummaryFile = Join-Path $OutputDir "collection_summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $Summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $SummaryFile -Encoding UTF8
    Write-Host "✓ Collection summary saved to: $SummaryFile" -ForegroundColor Green

    # Display summary
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "METRICS COLLECTION COMPLETED" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green
    Write-Host "Duration: $Duration seconds" -ForegroundColor White
    Write-Host "Output Directory: $OutputDir" -ForegroundColor White
    Write-Host "Files Generated:" -ForegroundColor White
    foreach ($File in $Summary.FilesGenerated) {
        if (Test-Path $File) {
            $FileSize = [math]::Round((Get-Item $File).Length / 1MB, 2)
            Write-Host "  - $(Split-Path $File -Leaf) ($FileSize MB)" -ForegroundColor Cyan
        }
    }
    Write-Host "Summary: $SummaryFile" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Green

} catch {
    Write-Error "Metrics collection failed: $_"
    exit 1
}
