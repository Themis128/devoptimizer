$urls = @(
    'https://download01.logi.com/web/ftp/pub/techsupport/camera/CameraSettings.exe',
    'https://download01.logi.com/web/ftp/pub/techsupport/camera/CameraSettings_2.0.exe',
    'https://download.logitech.com/web/ftp/pub/techsupport/camera/CameraSettings.exe',
    'https://cdn.logi.com/web/ftp/pub/techsupport/camera/CameraSettings.exe',
    'https://download01.logi.com/web/ftp/pub/techsupport/camera/',
    'https://download.logitech.com/web/ftp/pub/techsupport/camera/'
)
foreach ($url in $urls) {
    try {
        $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -ErrorAction Stop
        Write-Host "FOUND: $url - Status: $($r.StatusCode)"
    } catch {
        Write-Host "MISSING: $url - $($_.Exception.Message)"
    }
}