for ($i=0; $i -lt 30; $i++) { 
    if (docker info 2>$null) { 
        Write-Host 'Docker engine ready' 
        exit 0 
    } 
    Start-Sleep 2 
}
Write-Host 'Docker engine not ready after 60s'
exit 1