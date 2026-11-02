# wsl-guardian.ps1 v2 - WSL2 Ubuntu self-healing ladder (DevOptimizer task)
# Every 5 min via conhost --headless scheduled task. Pure ASCII (PS 5.1).
#
# Recovery ladder (each tier guarded by .deploy.lock + cooldowns):
#   T1 container - distro alive but stack dead: docker restart the unhealthy
#                  container(s) inside the distro. Cheapest fix first.
#   T2 distro    - 4+ sustained deep fails or T1 didn't recover: targeted
#                  `wsl --terminate <distro>` + prewarm (docker-desktop stays).
#   T3 vm        - post-terminate still dead (VM-level wedge): `wsl --shutdown`
#                  + prewarm + verify. The automated equivalent of
#                  wsl-safe-bounce.ps1, with a long cooldown.
# Alerts: optional -NtfyTopic. State/log: %ProgramData%\wsl-guardian\.

[CmdletBinding()]
param(
    [string]$Distro           = 'Ubuntu-26.04',
    [int]$ProbeTimeoutSec     = 20,
    [int]$DeepCheckEvery      = 3,        # deep-check every Nth probe (~15 min)
    [int]$T1After             = 2,        # container restart after N deep fails
    [int]$T2After             = 4,        # distro terminate after N deep fails
    [int]$T3After             = 6,        # VM bounce after N deep fails (post-T2)
    [int]$T1CooldownMin       = 15,
    [int]$T2CooldownMin       = 60,
    [int]$T3CooldownMin       = 240,
    [string]$DeepHealthCmd    = 'curl -sf -m8 -o /dev/null -w "%{http_code}" http://localhost:8083/health',
    [string]$T1RepairCmd      = 'docker restart social-api',
    [string]$VerifyCmd        = 'curl -sf -m8 -o /dev/null -w "%{http_code}" http://localhost:8083/health',
    [string]$DeployLock       = '/home/tbaltzakis/cu130-slim/.deploy.lock',
    [int]$DeployLockMaxAgeSec = 3600,
    [string]$NtfyTopic        = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$StateDir  = "$env:ProgramData\wsl-guardian"
$LogFile   = "$StateDir\guardian.log"
$StateFile = "$StateDir\state.json"
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

function Log($m,$l='INFO'){ $line="{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$l,$m; Add-Content $LogFile $line -Encoding ASCII; if($l -ne 'INFO'){Write-Output $line} }
function Notify($t,$b){ Log "ALERT: $t -- $b" 'WARN'; if($NtfyTopic){try{Invoke-RestMethod -Uri "https://ntfy.cloudless.gr/$NtfyTopic" -Method Post -Body $b -Headers @{Title=$t;Priority='high'} -TimeoutSec 10|Out-Null}catch{Log "ntfy fail: $($_.Exception.Message)" 'WARN'}} }
function Get-State { if(Test-Path $StateFile){Get-Content $StateFile -Raw|ConvertFrom-Json}else{[pscustomobject]@{deepFails=0;lastT1='';lastT2='';lastT3='';tick=0} } }
function Set-State($s){ $s|ConvertTo-Json|Set-Content $StateFile -Encoding ASCII }
function Cooled($iso,$min){ if(-not $iso){return $false}; $d=[datetime]::MinValue; [void][datetime]::TryParse($iso,[ref]$d); return ((Get-Date)-$d).TotalMinutes -lt $min }

function Wsl-Run([string[]]$wslArgs,[int]$toSec,[string]$outFile) {
    $a = @('-d',$Distro,'-e') + $wslArgs
    $p = Start-Process wsl.exe -ArgumentList $a -NoNewWindow -PassThru
    if($outFile){ $p = Start-Process wsl.exe -ArgumentList $a -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError "$outFile.err" }
    if(-not $p.WaitForExit($toSec*1000)){ try{$p.Kill()}catch{}; return $null }
    if($outFile){ return ((Get-Content $outFile -ErrorAction SilentlyContinue) -join '').Trim() }
    return ($p.ExitCode -eq 0)
}

function Test-DeployLock {
    $r = Wsl-Run @('bash','-c',"if [ -f $DeployLock ]; then a=`$(( `$(date +%s) - `$(stat -c %Y $DeployLock) )); [ `$a -lt $DeployLockMaxAgeSec ] && echo FRESH || echo stale; else echo none; fi") 15 "$StateDir\lock.txt"
    return ($r -eq 'FRESH')
}

$st = Get-State; $st.tick = [int]$st.tick + 1
$probe = Wsl-Run @('true') $ProbeTimeoutSec $null
if ($null -eq $probe -or $probe -eq $false) {
    $st.deepFails = [int]$st.deepFails + 1
    Log "probe FAIL (vsock/distro unreachable) consecutive=$($st.deepFails)" 'WARN'
    $deepFail = $true
} else {
    $deepFail = $false
    if ($st.tick % $DeepCheckEvery -eq 0) {
        $code = Wsl-Run @('bash','-c',$DeepHealthCmd) $ProbeTimeoutSec "$StateDir\deep.txt"
        if ($code -match '^[23]') {
            if ($st.deepFails -gt 0) { Log "recovered: deep http=$code after $($st.deepFails)"; Notify 'wsl-guardian recovered' "deep health ok ($code) after $($st.deepFails) fails" }
            $st.deepFails = 0
        } else {
            $st.deepFails = [int]$st.deepFails + 1
            $deepFail = $true
            Log "deep FAIL http=$code consecutive=$($st.deepFails)" 'WARN'
        }
    } else { Log "probe OK tick=$($st.tick) deepFails=$($st.deepFails)" }
}

$df = [int]$st.deepFails
if ($deepFail -and $df -ge $T1After) {
    $locked = Test-DeployLock
    # ---- T1: container-level repair (distro alive) ----
    if ($df -ge $T1After -and $df -lt $T2After -and -not $locked -and -not (Cooled $st.lastT1 $T1CooldownMin)) {
        Log "T1 ACTION: in-distro repair `$T1RepairCmd` (fail #$df)" 'WARN'
        if (-not $DryRun) {
            Wsl-Run @('bash','-c',$T1RepairCmd) 90 $null | Out-Null
            $st.lastT1 = (Get-Date).ToString('o')
        }
    }
    # ---- T2: targeted distro terminate ----
    elseif ($df -ge $T2After -and $df -lt $T3After -and -not $locked -and -not (Cooled $st.lastT2 $T2CooldownMin)) {
        Log "T2 ACTION: wsl --terminate $Distro (fail #$df)" 'WARN'
        if (-not $DryRun) {
            Notify 'wsl-guardian T2: terminating distro' "$Distro terminated after $df sustained failures. Containers recover via restart policies."
            wsl.exe --terminate $Distro | Out-Null
            Start-Sleep -Seconds 15
            Wsl-Run @('true') 30 $null | Out-Null
            $st.lastT2 = (Get-Date).ToString('o'); $st.deepFails = 0
        }
    }
    # ---- T3: full VM bounce ----
    elseif ($df -ge $T3After -and -not $locked -and -not (Cooled $st.lastT3 $T3CooldownMin)) {
        Log "T3 ACTION: wsl --shutdown (fail #$df, post-T2 unrecovered)" 'WARN'
        if (-not $DryRun) {
            Notify 'wsl-guardian T3: VM bounce' "wsl --shutdown after $df failures (T2 did not recover). Applies pending .wslconfig changes; containers recover via policies."
            wsl.exe --shutdown
            Start-Sleep -Seconds 15
            Wsl-Run @('true') 30 $null | Out-Null
            Start-Sleep -Seconds 30
            $v = Wsl-Run @('bash','-c',$VerifyCmd) 60 "$StateDir\verify.txt"
            Log "T3 verify: http=$v"
            $st.lastT3 = (Get-Date).ToString('o'); $st.deepFails = 0
        }
    }
    elseif ($locked) { Log "action suppressed: FRESH .deploy.lock (fail #$df)" 'WARN' }
    else { Log "action suppressed by cooldown (fail #$df)" }
}

Set-State $st
