# Check-DevinHealth.ps1 - health check + repair for Devin Desktop's WSL remote
# (devin-server in ~/.devin-server inside Ubuntu-26.04).
#
# Detects the three known failure classes from 2026-09:
#   1. WSL distro down / unreachable              -> Devin cannot connect at all
#   2. Corrupt server bundle (ERR_MODULE_NOT_FOUND) -> "Remote Extension host
#      terminated unexpectedly 3 times" popup; exthost exits code 1 instantly
#   3. Boot race: Devin opened <3 min after WSL start -> transient popup, self-heals
#
# Exit code: 0 = healthy, 1 = problems found, 2 = repaired (rerun to confirm).
# -Repair: kills devin-server and deletes the corrupt commit dir so the next
#          Reload Window re-downloads a fresh bundle. Does not touch extensions,
#          data, or settings. See memory: devin-desktop-install.
param([switch]$Repair)

$distro = 'Ubuntu-26.04'
$fail = @()
$warn = @()

function Invoke-Wsl([string]$cmd) {
    $out = & wsl.exe -d $distro -- bash -c $cmd 2>$null
    $joined = (@($out) -join "`n") -replace "`0", ''
    # wsl.exe can deliver multi-line output as ONE element with embedded
    # newlines; split so callers always get real lines.
    return ($joined -split "`r?`n") | Where-Object { $_ -ne '' }
}

Write-Host "=== Devin WSL-Remote Health ($distro) ===" -ForegroundColor Cyan

# 1. WSL reachable
$ping = Invoke-Wsl 'echo ok'
if ($ping -notmatch 'ok') {
    Write-Host "[FAIL] WSL distro '$distro' unreachable - start WSL first: wsl -d $distro --exec true" -ForegroundColor Red
    exit 1
}
Write-Host "[ OK ] WSL distro reachable" -ForegroundColor Green

# 2. WSL boot age (boot-race advisory)
try {
    $up = [double]((Invoke-Wsl 'cat /proc/uptime') -split '\s+')[0]
    if ($up -lt 180) { $warn += "WSL booted $([int]$up)s ago - Devin may race the boot; if a popup appeared, Reload Window once WSL is up" }
    Write-Host ("[ OK ] WSL uptime: {0:h\h\ m\m\ s\s}" -f [timespan]::FromSeconds($up)) -ForegroundColor Green
} catch { $warn += "could not read WSL uptime" }

# 3. devin-server process + current commit
$procs = Invoke-Wsl "pgrep -af 'server-mai[n]' || true"
$commit = $null
if ($procs -match '\.devin-server/bin/([a-f0-9]{40})/') {
    $commit = $Matches[1]
    Write-Host "[ OK ] devin-server running (commit $commit)" -ForegroundColor Green
} else {
    $warn += "devin-server not running - if Devin shows 'Cannot reconnect', click Reload Window"
    Write-Host "[WARN] devin-server not running in WSL" -ForegroundColor Yellow
}

# 4. Bundle integrity (the corrupt-bundle failure: node_modules truncated)
if ($commit) {
    $base = "`$HOME/.devin-server/bin/$commit/node_modules"
    $check = Invoke-Wsl "test -d $base/minimist -a -d $base/@vscode && echo intact || echo broken"
    if ($check -match 'intact') {
        Write-Host "[ OK ] server bundle intact (minimist + @vscode present)" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] server bundle CORRUPT - node_modules truncated (classic ERR_MODULE_NOT_FOUND crash loop)" -ForegroundColor Red
        $fail += "bundle corrupt: $commit"
        if ($Repair) {
            Write-Host "[FIX ] killing server and deleting corrupt commit dir..." -ForegroundColor Yellow
            [void](Invoke-Wsl "pkill -f 'server-mai[n]'; rm -rf `$HOME/.devin-server/bin/$commit; echo repaired")
            Write-Host "[FIX ] done. In Devin: click 'Reload Window' (or reopen) - a fresh bundle will download (~700 MB)." -ForegroundColor Yellow
            exit 2
        } else {
            Write-Host "       run again with -Repair to fix (then Reload Window in Devin)" -ForegroundColor Yellow
        }
    }
}

# 5. Host memory context (starved host kills Electron/WSL processes)
$os = Get-CimInstance Win32_OperatingSystem
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
if ($freeGB -lt 2) { $warn += "host memory low: ${freeGB} GB free - memory starvation can kill devin-server" }
Write-Host "[ OK ] host free memory: $freeGB GB" -ForegroundColor Green

foreach ($w in $warn) { Write-Host "[WARN] $w" -ForegroundColor Yellow }
if ($fail.Count -eq 0) {
    Write-Host "=== HEALTHY ===" -ForegroundColor Cyan
    exit 0
}
Write-Host "=== PROBLEMS: $($fail -join '; ') ===" -ForegroundColor Red
exit 1
