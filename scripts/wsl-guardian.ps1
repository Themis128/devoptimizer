# wsl-guardian.ps1 - WSL2 Ubuntu liveness guardian (1Helm-pattern, DevOptimizer task)
# Runs every 5 min via conhost --headless scheduled task. Pure ASCII only (PS 5.1
# reads BOM-less UTF-8 as ANSI - no em-dashes/smart quotes).
#
# Layers:
#   1. probe   - `wsl -d Ubuntu-26.04 -e true` (vsock liveness) + deep check
#                (social-api health inside WSL)
#   2. guard   - .deploy.lock honoured: never terminates while a deploy runs
#   3. recover - only after MAX_FAIL consecutive deep failures: targeted
#                `wsl --terminate Ubuntu-26.04` (NEVER wsl --shutdown - that
#                would kill docker-desktop and every other distro), then prewarm.
#
# State: %ProgramData%\wsl-guardian\state.json + guardian.log

[CmdletBinding()]
param(
    [string]$Distro          = 'Ubuntu-26.04',
    [int]$ProbeTimeoutSec    = 20,
    [int]$DeepCheckEvery     = 3,       # deep-check every Nth probe (~15 min)
    [int]$MaxDeepFailures    = 4,       # ~20 min of sustained failure before terminate
    [int]$CooldownMin        = 60,      # min minutes between terminates
    [string]$DeepHealthCmd   = 'curl -sf -m8 -o /dev/null -w "%{http_code}" http://localhost:8083/health',
    [string]$DeployLock      = '/home/tbaltzakis/cu130-slim/.deploy.lock',
    [int]$DeployLockMaxAgeSec= 3600,
    [string]$NtfyTopic       = '',      # optional: https://ntfy.cloudless.gr/<topic> alert
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$StateDir = "$env:ProgramData\wsl-guardian"
$LogFile  = "$StateDir\guardian.log"
$StateFile= "$StateDir\state.json"
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

function Log($msg, $lvl = 'INFO') {
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $lvl, $msg
    Add-Content -Path $LogFile -Value $line -Encoding ASCII
    if ($lvl -ne 'INFO') { Write-Output $line }
}

function Notify($title, $body) {
    Log "ALERT: $title -- $body" 'WARN'
    if ($NtfyTopic) {
        try {
            Invoke-RestMethod -Uri "https://ntfy.cloudless.gr/$NtfyTopic" -Method Post `
                -Body $body -Headers @{ Title = $title; Priority = 'high' } -TimeoutSec 10 | Out-Null
        } catch { Log "ntfy send failed: $($_.Exception.Message)" 'WARN' }
    }
}

function Get-State { if (Test-Path $StateFile) { Get-Content $StateFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{ deepFails=0; lastTerminate=''; tick=0 } } }
function Set-State($s) { $s | ConvertTo-Json | Set-Content $StateFile -Encoding ASCII }

function Invoke-WslProbe([int]$timeoutSec) {
    # Returns $true if wsl.exe reaches the distro and the command exits 0.
    $p = Start-Process -FilePath 'wsl.exe' -ArgumentList @('-d', $Distro, '-e', 'true') `
        -NoNewWindow -PassThru -Wait:$false
    if (-not $p.WaitForExit($timeoutSec * 1000)) {
        try { $p.Kill() } catch {}
        return $false
    }
    return ($p.ExitCode -eq 0)
}

function Invoke-WslDeepHealth([int]$timeoutSec) {
    # Runs the health curl INSIDE the distro. Returns http code or 'DEAD'.
    $tmp = "$StateDir\deep-out.txt"
    $p = Start-Process -FilePath 'wsl.exe' -ArgumentList @('-d', $Distro, '-e', 'bash','-c', $DeepHealthCmd) `
        -NoNewWindow -PassThru -RedirectStandardOutput $tmp -RedirectStandardError "$StateDir\deep-err.txt"
    if (-not $p.WaitForExit($timeoutSec * 1000)) { try { $p.Kill() } catch {}; return 'DEAD' }
    $out = (Get-Content $tmp -ErrorAction SilentlyContinue) -join ''
    return ($out.Trim())
}

function Test-DeployLock {
    # Fresh deploy lock = hands off.
    $r = Invoke-WslBash "if [ -f $DeployLock ]; then age=\$(( \$(date +%s) - \$(stat -c %Y $DeployLock) )); [ \$age -lt $DeployLockMaxAgeSec ] && echo FRESH || echo STALE; else echo NONE; fi"
    return ($r -eq 'FRESH')
}

function Invoke-WslBash([string]$cmd) {
    $tmp = "$StateDir\lock-out.txt"
    $p = Start-Process -FilePath 'wsl.exe' -ArgumentList @('-d', $Distro, '-e', 'bash','-c', $cmd) `
        -NoNewWindow -PassThru -RedirectStandardOutput $tmp
    if (-not $p.WaitForExit(15000)) { try { $p.Kill() } catch {}; return 'DEAD' }
    return ((Get-Content $tmp -ErrorAction SilentlyContinue) -join '').Trim()
}

# --- main ---
$st = Get-State
$st.tick = [int]$st.tick + 1

$alive = Invoke-WslProbe $ProbeTimeoutSec
if (-not $alive) {
    $st.deepFails = [int]$st.deepFails + 1
    Log "probe FAIL (vsock/distro unreachable) consecutive=$($st.deepFails)" 'WARN'
} elseif ($st.tick % $DeepCheckEvery -eq 0) {
    $code = Invoke-WslDeepHealth $ProbeTimeoutSec
    if ($code -match '^[23]') {
        if ($st.deepFails -gt 0) { Log "recovered: deep health $code after $($st.deepFails) fails"; Notify 'wsl-guardian recovered' "social-api healthy ($code) after $($st.deepFails) failures" }
        $st.deepFails = 0
    } else {
        $st.deepFails = [int]$st.deepFails + 1
        Log "deep FAIL (probe ok, stack dead) http=$code consecutive=$($st.deepFails)" 'WARN'
        if ($st.deepFails -eq 3) { Notify 'wsl-guardian: WSL stack degraded' "Ubuntu-26.04 alive but social-api /health failing (http=$code) for ~$($st.deepFails * 15)min" }
    }
} else {
    # shallow probe OK, not a deep-check tick: decay nothing, just report
    Log "probe OK (tick $($st.tick), deepFails=$($st.deepFails))"
}

# --- recovery ---
if ([int]$st.deepFails -ge $MaxDeepFailures) {
    $last = [datetime]::MinValue
    if ($st.lastTerminate) { [datetime]::TryParse($st.lastTerminate, [ref]$last) | Out-Null }
    $cooling = ((Get-Date) - $last).TotalMinutes -lt $CooldownMin
    if ($cooling) {
        Log "terminate suppressed by cooldown (last=$($st.lastTerminate))" 'WARN'
    } elseif (Test-DeployLock) {
        Log "terminate suppressed by FRESH .deploy.lock" 'WARN'
    } else {
        Log "ACTION: wsl --terminate $Distro after $($st.deepFails) sustained failures" 'WARN'
        if (-not $DryRun) {
            Notify 'wsl-guardian: terminating WSL distro' "wsl --terminate $Distro after $($st.deepFails) consecutive failures (~$($st.deepFails * 15)min). Restart policies will recover containers."
            wsl.exe --terminate $Distro | Out-Null
            Start-Sleep -Seconds 15
            wsl.exe -d $Distro -e true | Out-Null   # prewarm: bring distro + docker-desktop back
            $st.lastTerminate = (Get-Date).ToString('o')
            $st.deepFails = 0
        } else {
            Log "DryRun: would run wsl --terminate $Distro + prewarm"
        }
    }
}

Set-State $st
