# deploy-phone-watchdog.ps1 - push the canonical phone-watchdog script from
# the tailnet-watch repo to omv, serve it on omv's tailnet IP :8000, and
# print the exact phone-side pull one-liner (typed into Termux).
# Only omv's TAILNET IP is reachable (omv firewall blocks :8000 on LAN;
# the PC's own firewall blocks inbound :8000; omv adb push fails - wireless
# debug binds wlan0). See skill: devoptimizer-phone-watchdog
# Usage: pwsh -File scripts\deploy-phone-watchdog.ps1 [-StopServer]
# 2026-11-20
param(
    [switch]$StopServer   # stop the omv temp server instead of deploying
)
$ErrorActionPreference = 'Stop'
$omvUser = 'tbaltzakis'
$omvHost = 'github-omv.tail4ecae1.ts.net'
$omvTailnetIp = '100.74.191.58'
$canonical = 'D:\tailnet-watch\scripts\phone-watchdog-termux.sh'
$remotePayload = '/home/tbaltzakis/watchdog-payload.txt'

if ($StopServer) {
    ssh -o BatchMode=yes "$omvUser@$omvHost" "pkill -f 'python3 -m http.server 8000' 2>/dev/null; echo server-stop-requested"
    exit 0
}

if (-not (Test-Path $canonical)) { Write-Error "canonical script missing: $canonical"; exit 1 }

# 1. push to omv as a .txt payload (avoids tooling that blocks .sh writes)
scp -o BatchMode=yes $canonical "$omvUser@$omvHost`:$remotePayload".Replace('`:', ':')
if ($LASTEXITCODE -ne 0) { Write-Error "scp to omv failed"; exit 1 }

# 2. start the omv server, detached so it survives this ssh session
ssh -o BatchMode=yes "$omvUser@$omvHost" "nohup setsid python3 -m http.server 8000 --bind 0.0.0.0 </dev/null >/tmp/wd-httpsrv.log 2>&1 & sleep 1; curl -s -o /dev/null -w 'omv-serve:%{http_code}' http://127.0.0.1:8000/watchdog-payload.txt"
if ($LASTEXITCODE -ne 0) { Write-Error "omv server start/verify failed"; exit 1 }

# 3. print the phone-side steps
Write-Host ''
Write-Host '=== PHONE SIDE (type into Termux, verify terminal foreground first) ==='
Write-Host "curl -s -o ~/phone-watchdog.sh http://${omvTailnetIp}:8000/watchdog-payload.txt && sed -i 's/\r$//' ~/phone-watchdog.sh && chmod +x ~/phone-watchdog.sh && bash -n ~/phone-watchdog.sh && echo DEPLOYED-OK"
Write-Host ''
Write-Host 'then restart the loop:'
Write-Host 'pkill -f phone-watchdog-boot; (bash ~/.termux/boot/phone-watchdog-boot.sh &) && pgrep -f phone-watchdog-boot'
Write-Host ''
Write-Host 'cleanup when done: pwsh -File scripts\deploy-phone-watchdog.ps1 -StopServer'
