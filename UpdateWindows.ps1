# Create the AutoUpdate COM object
$u = New-Object -ComObject Microsoft.Update.AutoUpdate
# Detect updates
$u.DetectNow()
# Wait for detection to complete
Start-Sleep -Seconds 10
# Download updates
$u.Download()
