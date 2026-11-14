# docker-dashboard-guard.ps1 — keep the Docker Desktop dashboard window closed.
# com.docker.backend polls `docker stats --all --no-trunc --no-stream` every
# ~5s for the Containers view (upstream docker/for-win#13923/#13967, no
# setting to disable). Each poll spawns cmd.exe+conhost -> visible flash.
# Closing the dashboard reduces/eliminates the polling; the engine keeps
# running in the tray. Runs headless via scheduled task every 5 min.
$closed = 0
Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle } |
  ForEach-Object {
    $_.CloseMainWindow() | Out-Null
    $closed++
  }
if ($closed -gt 0) {
  "$(Get-Date -Format o) closed $closed Docker Desktop window(s)" |
    Out-File 'D:\DevOptimizer\scripts\_docker-dashboard-guard.log' -Append -Encoding utf8
}
