#Requires -RunAsAdministrator

# Legacy NAT-mode port forwarding helper. NOTE: with networkingMode=mirrored in
# .wslconfig (the current setup), localhost reaching WSL services is handled by
# WSL itself and a netsh portproxy against 'wsl hostname -I' is unnecessary -
# and the NAT IP no longer behaves the way this script expects.

Write-Host "WSL2 port forwarding helper (port 50000 - Next.js dev server)" -ForegroundColor Green
Write-Host ""

$wslConfig = "$env:USERPROFILE\.wslconfig"
$mirrored = $false
if (Test-Path $wslConfig) {
    $mirrored = (Get-Content $wslConfig) -match '^\s*networkingMode\s*=\s*mirrored'
}

if ($mirrored) {
    Write-Host "Your .wslconfig uses networkingMode=mirrored." -ForegroundColor Yellow
    Write-Host "Under mirrored networking WSL services are reachable on localhost" -ForegroundColor Yellow
    Write-Host "directly - a netsh portproxy is NOT needed and would target a stale NAT IP." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If http://localhost:50000 does not respond, check that the dev server" -ForegroundColor Gray
    Write-Host "inside WSL is listening and that localhostForwarding=true is set." -ForegroundColor Gray
    exit 0
}

# NAT mode (legacy): forward host port 50000 to the WSL NAT IP
$WSL_IP = (wsl hostname -I).Trim().Split(' ')[0]
if (-not $WSL_IP) {
    Write-Host "Could not determine WSL IP (is the distribution running?)" -ForegroundColor Red
    exit 1
}

Write-Host "WSL2 IP Address: $WSL_IP"
Write-Host "Setting up port forwarding for port 50000..."
netsh interface portproxy add v4tov4 listenport=50000 listenaddress=127.0.0.1 connectport=50000 connectaddress=$WSL_IP

Write-Host ""
Write-Host "Port forwarding setup complete! http://localhost:50000" -ForegroundColor Green
Write-Host "To remove it later:" -ForegroundColor Yellow
Write-Host "netsh interface portproxy delete v4tov4 listenport=50000 listenaddress=127.0.0.1"
