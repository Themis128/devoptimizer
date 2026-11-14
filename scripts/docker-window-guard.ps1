# docker-window-guard.ps1 - persistent Docker Desktop window closer.
# com.docker.backend polls `docker stats` every ~5s while a dashboard
# client window exists; each poll spawns conhost -> visible flash
# (docker/for-win#13923/#13967, no upstream setting). The 5-min
# DockerDashboardGuard task only bounds the window-open time; this loop
# bounds it to ~3s. Engine/tray keep running - only the GUI window closes.
$log = 'D:\DevOptimizer\scripts\_docker-window-guard.log'
while ($true) {
    try {
        $procs = Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle }
        foreach ($p in $procs) {
            $null = $p.CloseMainWindow()
            "$(Get-Date -Format o) closed Docker Desktop window pid=$($p.Id) title=$($p.MainWindowTitle)" |
                Out-File $log -Append -Encoding utf8
        }
    } catch {}
    Start-Sleep -Seconds 3
}
