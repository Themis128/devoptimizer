# wsl-vsock-watchdog.ps1 - detect a wedged WSL utility VM and bounce it.
#
# Signature: wsl.exe -e calls hang / die with Wsl/Service/WSAETIMEDOUT while
# the distro still reports Running (vsock degradation under VM memory pressure,
# observed 2026-11-01: 30+ queued wsl.exe, calls timing out for ~40 min).
#
# Probe: wsl -d Ubuntu-24.04 -e true with a hard 45s timeout, every 2 min via
# the WSL-Vsock-Watchdog scheduled task (user context, conhost --headless).
# 5 consecutive probe failures (~10 min wedged) triggers the sanctioned
# \DevOptimizer\WSL-GPU-Rebind task (shutdown -> prewarm -> GPU verify) rather
# than duplicating that logic. Skips while that task is already Running, while
# inside a 25-min post-bounce cooldown, or when the distro is deliberately
# Stopped (never boot a VM somebody turned off on purpose).
#
# Pure ASCII only - PowerShell 5.1 mis-decodes UTF-8 punctuation.

$ErrorActionPreference = 'Continue'

$distro          = 'Ubuntu-24.04'
$threshold       = 5
$probeTimeoutSec = 45
$cooldownMin     = 25
$stateDir        = 'D:\DevOptimizer\state'
$stateFile       = Join-Path $stateDir 'wsl-vsock-watchdog.state'
$log             = 'D:\DevOptimizer\logs\wsl-vsock-watchdog.log'

New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

function Log($m) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    Add-Content -Path $log -Value $line -ErrorAction SilentlyContinue
}

function Get-State {
    if (Test-Path $stateFile) {
        $j = Get-Content $stateFile -Raw -ErrorAction SilentlyContinue |
             ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($j) { return $j }
    }
    return [pscustomobject]@{ fails = 0; lastBounce = $null }
}

function Save-State($fails, $lastBounce) {
    @{ fails = [int]$fails; lastBounce = $lastBounce } |
        ConvertTo-Json -Compress | Set-Content $stateFile -ErrorAction SilentlyContinue
}

function Test-DistroRunning {
    # wsl -l -v is a service-level query - it answers even when the VM is wedged.
    try {
        $out = & wsl.exe -l -v 2>&1 | Out-String
    } catch { return $false }
    return ($out -match 'Running') -and ($out -match [regex]::Escape($distro))
}

function Invoke-Probe {
    $p = Start-Process -FilePath 'wsl.exe' `
        -ArgumentList '-d', $distro, '-e', 'true' `
        -PassThru -WindowStyle Hidden
    if ($p.WaitForExit($probeTimeoutSec * 1000) -and $p.ExitCode -eq 0) { return $true }
    try { if (-not $p.HasExited) { $p.Kill() } } catch {}
    return $false
}

$st = Get-State

# Cooldown after we triggered a bounce - give the VM time to come back.
if ($st.lastBounce) {
    $since = (New-TimeSpan -Start ([datetime]$st.lastBounce) -End (Get-Date)).TotalMinutes
    if ($since -lt $cooldownMin) { exit 0 }
}

# Never double-bounce: if the rebind task is already healing, hands off.
$rebind = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'WSL-GPU-Rebind' `
    -ErrorAction SilentlyContinue
if ($rebind -and $rebind.State -eq 'Running') { Save-State 0 $st.lastBounce; exit 0 }

# Deliberately stopped distro = not a wedge. A probe would boot it, so skip.
if (-not (Test-DistroRunning)) { Save-State 0 $st.lastBounce; exit 0 }

if (Invoke-Probe) {
    if ([int]$st.fails -gt 0) { Log "probe recovered after $($st.fails) consecutive fail(s)" }
    Save-State 0 $st.lastBounce
    exit 0
}

$fails = [int]$st.fails + 1
Log "probe FAIL #$fails (wsl -e true did not exit cleanly within ${probeTimeoutSec}s)"

if ($fails -ge $threshold) {
    Log "wedged $threshold consecutive probes - triggering \DevOptimizer\WSL-GPU-Rebind"
    try {
        Start-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'WSL-GPU-Rebind' `
            -ErrorAction Stop
        Log 'bounce triggered'
        Save-State 0 (Get-Date)
    } catch {
        Log "bounce trigger failed: $($_.Exception.Message)"
        Save-State $fails $st.lastBounce
    }
    exit 0
}

Save-State $fails $st.lastBounce
exit 0
