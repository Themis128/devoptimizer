# Force kill stuck Windows Update services
$services = @('wuauserv', 'cryptSvc', 'bits', 'msiserver', 'AppIDSvc')

foreach ($svc in $services) {
    Write-Host "Stopping $svc..." -ForegroundColor Yellow
    
    # Try graceful stop first
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    
    # If still running, kill the process directly
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='$svc'" -ErrorAction SilentlyContinue
    if ($service -and $service.State -eq 'Running') {
        $processId = $service.ProcessId
        if ($processId -gt 0) {
            Write-Host "  Force killing PID $processId..." -ForegroundColor Red
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "`nAll services stopped. Re-run the repair script now." -ForegroundColor Green