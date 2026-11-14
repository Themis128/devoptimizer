Set-NetIPInterface -InterfaceAlias "Wi-Fi" -Forwarding Enabled -ErrorAction Stop
"forwarding enabled" | Out-File 'D:\DevOptimizer\logs\.ip-forwarding-done' -Encoding ascii
