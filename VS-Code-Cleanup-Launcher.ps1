# VS Code Cleanup - Interactive Launcher
# Provides menu-driven access to all cleanup options

function Show-Menu {
    Clear-Host
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      VS Code Insiders Emergency Cleanup - Launcher        ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Show current status
    $processes = Get-Process -Name "Code - Insiders" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*Insiders*" }
    
    if ($processes) {
        $count = $processes.Count
        $memoryMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
        Write-Host "  Current Status: " -NoNewline
        Write-Host "$count processes" -ForegroundColor Yellow -NoNewline
        Write-Host " using " -NoNewline
        Write-Host "$memoryMB MB" -ForegroundColor $(if($memoryMB -gt 2000){'Red'}else{'Yellow'})
    } else {
        Write-Host "  Current Status: " -NoNewline
        Write-Host "No processes running" -ForegroundColor Green
    }
    
    Write-Host "`n  Choose cleanup mode:`n" -ForegroundColor White
    Write-Host "  [1] Interactive Cleanup" -ForegroundColor Cyan
    Write-Host "      → Shows analysis, asks for confirmation" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] Force Kill (Immediate)" -ForegroundColor Yellow
    Write-Host "      → No questions, instant termination" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] Memory Threshold Cleanup" -ForegroundColor Magenta
    Write-Host "      → Only if exceeding specified MB" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4] View Detailed Process Info" -ForegroundColor Blue
    Write-Host "      → Analysis only, no cleanup" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [5] Open Documentation" -ForegroundColor White
    Write-Host "      → Full optimization guide" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-DetailedInfo {
    $processes = Get-Process -Name "Code - Insiders" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*Insiders*" }
    
    if (-not $processes) {
        Write-Host "`n  No VS Code Insiders processes found.`n" -ForegroundColor Green
        return
    }
    
    Clear-Host
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Detailed Process Information                  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $count = $processes.Count
    $totalMemoryMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
    $mainWindows = $processes | Where-Object { $_.MainWindowTitle }
    $background = $processes | Where-Object { -not $_.MainWindowTitle }
    
    Write-Host "  Summary:" -ForegroundColor White
    Write-Host "    Total Processes:    $count" -ForegroundColor Yellow
    Write-Host "    Main Windows:       $($mainWindows.Count)" -ForegroundColor Yellow
    Write-Host "    Background:         $($background.Count)" -ForegroundColor Yellow
    Write-Host "    Total Memory:       $totalMemoryMB MB`n" -ForegroundColor Yellow
    
    Write-Host "  All Processes:" -ForegroundColor White
    $processes | Select-Object Id,
        @{Name="Memory (MB)";Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}},
        @{Name="CPU Time";Expression={$_.TotalProcessorTime.ToString("hh\:mm\:ss")}},
        @{Name="Threads";Expression={$_.Threads.Count}},
        @{Name="Type";Expression={if($_.MainWindowTitle){"Window"}else{"Background"}}} |
        Format-Table -AutoSize
    
    if ($mainWindows) {
        Write-Host "`n  Active Windows:" -ForegroundColor White
        $mainWindows | ForEach-Object {
            Write-Host "    • $($_.MainWindowTitle)" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "  Enter choice"
    
    switch ($choice.ToUpper()) {
        '1' {
            Write-Host "`n  Launching interactive cleanup...`n" -ForegroundColor Green
            & "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1"
            Write-Host "`n  Press any key to return to menu..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '2' {
            Write-Host "`n  Launching force kill...`n" -ForegroundColor Yellow
            & "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1" -Force
            Write-Host "`n  Press any key to return to menu..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '3' {
            Write-Host ""
            $threshold = Read-Host "  Enter memory threshold in MB (e.g., 2000)"
            if ($threshold -match '^\d+$') {
                Write-Host "`n  Launching cleanup with ${threshold}MB threshold...`n" -ForegroundColor Magenta
                & "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1" -MemoryThreshold $threshold
            } else {
                Write-Host "`n  Invalid threshold. Please enter a number." -ForegroundColor Red
            }
            Write-Host "`n  Press any key to return to menu..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '4' {
            Show-DetailedInfo
            Write-Host "  Press any key to return to menu..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '5' {
            Write-Host "`n  Opening documentation...`n" -ForegroundColor White
            Start-Process "D:\DevOptimizer\VS-Code-Cleanup-Optimization-Guide.md"
            Start-Sleep -Seconds 1
        }
        'Q' {
            Write-Host "`n  Goodbye!`n" -ForegroundColor Gray
            break
        }
        default {
            Write-Host "`n  Invalid choice. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($choice.ToUpper() -ne 'Q')
