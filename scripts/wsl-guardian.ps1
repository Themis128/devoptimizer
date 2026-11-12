# wsl-guardian.ps1 v2.1 - WSL2 Ubuntu self-healing ladder (DevOptimizer task)
# v2.1 2026-11-02: Get-State normalizes old-schema state files (cooldown writes
#   were silently dropped -> T2 fired every 4th fail forever); T3 now fires on
#   postT2Fails (post-terminate counter) instead of deepFails, which the T2 reset
#   made unreachable; Wsl-Run uses -WindowStyle Hidden (-NoNewWindow hangs under
#   conhost --headless) and quotes space-containing args (bash -c payloads were
#   split into argv pieces -> deep check and deploy-lock test never worked).
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
    [string]$Distro           = 'Ubuntu-24.04',
    [int]$ProbeTimeoutSec     = 20,
    [int]$DeepCheckEvery      = 3,        # deep-check every Nth probe (~15 min)
    [int]$T1After             = 2,        # container restart after N deep fails
    [int]$T2After             = 4,        # distro terminate after N deep fails
    [int]$T3After             = 6,        # VM bounce after N deep fails (post-T2)
    [int]$T1CooldownMin       = 15,
    [int]$T2CooldownMin       = 60,
    [int]$T3CooldownMin       = 240,
    [string]$DeepHealthCmd    = 'curl -sf -m30 -o /dev/null -w "%{http_code}" http://localhost:8083/health',
    [int]$DeepCheckTimeoutSec = 45,        # wrapper must exceed curl -m inside DeepHealthCmd
    [string]$T1RepairCmd      = 'docker restart social-api',
    [string]$VerifyCmd        = 'curl -sf -m30 -o /dev/null -w "%{http_code}" http://localhost:8083/health',
    [string]$DeployLock       = '/home/tbaltzakis/cu130-slim/.deploy.lock',
    [int]$DeployLockMaxAgeSec = 3600,
    [string]$NtfyTopic        = 'devoptimizer-alerts',
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$StateDir  = "$env:ProgramData\wsl-guardian"
$LogFile   = "$StateDir\guardian.log"
$StateFile = "$StateDir\state.json"
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

function Log($m,$l='INFO'){ $line="{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$l,$m; $f=Get-Item $LogFile -ErrorAction SilentlyContinue; if($f -and $f.Length -gt 1MB){Get-Content $LogFile -Tail 1000|Set-Content $LogFile -Encoding ASCII}; Add-Content $LogFile $line -Encoding ASCII; if($l -ne 'INFO'){Write-Output $line} }
function Notify($t,$b){ Log "ALERT: $t -- $b" 'WARN'; if($NtfyTopic){try{$h=@{Title=$t;Priority='high'};$tf=Join-Path $env:APPDATA 'devin\secrets\ntfy-devoptimizer-token';if(Test-Path $tf){$h['Authorization']='Bearer '+(Get-Content $tf -Raw).Trim()};Invoke-RestMethod -Uri "https://ntfy.cloudless.gr/$NtfyTopic" -Method Post -Body $b -Headers $h -TimeoutSec 10|Out-Null}catch{Log "ntfy fail: $($_.Exception.Message)" 'WARN'}} }
function Get-State {
    # Normalize: a state file written by an older schema lacks the lastT1/lastT2/
    # lastT3/t2Pending/postT2Fails properties. Assigning a missing property on a
    # PSCustomObject throws (statement-terminating; skipped under EAP=Continue),
    # which silently disabled every cooldown and made T3 unreachable. Guarantee
    # all fields exist so Set-State round-trips them.
    $d = [pscustomobject]@{deepFails=0;postT2Fails=0;lastT1='';lastT2='';lastT3='';t2Pending=$false;tick=0}
    if (Test-Path $StateFile) {
        $j = Get-Content $StateFile -Raw | ConvertFrom-Json
        if (-not $j) { return $d }
        foreach ($p in @($d.PSObject.Properties)) {
            if (-not ($j.PSObject.Properties.Name -contains $p.Name)) {
                $j | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
            }
        }
        foreach ($dead in @('lastTerminate')) {
            if ($j.PSObject.Properties[$dead]) { $j.PSObject.Properties.Remove($dead) }
        }
        return $j
    }
    return $d
}
function Set-State($s){ $s|ConvertTo-Json|Set-Content $StateFile -Encoding ASCII }
function Cooled($iso,$min){ if(-not $iso){return $false}; $d=[datetime]::MinValue; [void][datetime]::TryParse($iso,[ref]$d); return ((Get-Date)-$d).TotalMinutes -lt $min }

function Wsl-Run([string[]]$wslArgs,[int]$toSec,[string]$outFile) {
    # NOTE: -WindowStyle Hidden, never -NoNewWindow. Under this task's conhost
    # --headless parent, a -NoNewWindow child inherits a windowless console and
    # wsl.exe hangs on the console handshake (>20s -> every probe 'fails' while
    # the distro is actually fine, seen 2026-11-02: 155 consecutive probe FAILs,
    # 0 passes, terminating a healthy distro every ~20min). Hidden gives the
    # child its own console - same pattern wsl-vsock-watchdog.ps1 uses (probes
    # pass in the same context).
    # NOTE 2: Start-Process joins -ArgumentList with SPACES, so an arg that
    # contains spaces (e.g. a whole 'bash -c' payload) must be pre-quoted or it
    # arrives as separate argv ('bash','-c','curl','-sf'... -> bash runs bare
    # 'curl'; same bug made Test-DeployLock always return not-FRESH).
    $q = foreach ($x in (@('-d',$Distro,'-e') + $wslArgs)) {
        if ($x -match '[\s"]') { '"' + ($x -replace '"','\"') + '"' } else { $x }
    }
    $argLine = $q -join ' '
    $p = Start-Process wsl.exe -ArgumentList $argLine -WindowStyle Hidden -PassThru
    if($outFile){ $p = Start-Process wsl.exe -ArgumentList $argLine -WindowStyle Hidden -PassThru -RedirectStandardOutput $outFile -RedirectStandardError "$outFile.err" }
    if(-not $p.WaitForExit($toSec*1000)){ try{$p.Kill()}catch{}; return $null }
    if($outFile){ return ((Get-Content $outFile -ErrorAction SilentlyContinue) -join '').Trim() }
    return ($p.ExitCode -eq 0)
}

# Bounded admin verbs (--terminate/--shutdown). A wedged LxssManager can hang
# these; an unbounded call would stall this instance and (task policy is
# IgnoreNew) silently disable the guardian until ExecutionTimeLimit (72h).
function Wsl-Admin([string[]]$wslArgs,[int]$toSec) {
    $q = foreach ($x in $wslArgs) {
        if ($x -match '[\s"]') { '"' + ($x -replace '"','\"') + '"' } else { $x }
    }
    $p = Start-Process wsl.exe -ArgumentList ($q -join ' ') -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput "$StateDir\admin.txt" -RedirectStandardError "$StateDir\admin.err"
    if (-not $p.WaitForExit($toSec*1000)) { try{$p.Kill()}catch{}; return $false }
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
    if ($st.t2Pending) { $st.postT2Fails = [int]$st.postT2Fails + 1 }
    Log "probe FAIL (vsock/distro unreachable) consecutive=$($st.deepFails) postT2=$($st.postT2Fails)" 'WARN'
    $deepFail = $true
} else {
    $deepFail = $false
    if ($st.tick % $DeepCheckEvery -eq 0) {
        $code = Wsl-Run @('bash','-c',$DeepHealthCmd) $DeepCheckTimeoutSec "$StateDir\deep.txt"
        if ($code -match '^[23]') {
            if ($st.deepFails -gt 0 -or $st.t2Pending) { Log "recovered: deep http=$code after $($st.deepFails)"; Notify 'wsl-guardian recovered' "deep health ok ($code) after $($st.deepFails) fails" }
            $st.deepFails = 0; $st.postT2Fails = 0; $st.t2Pending = $false
        } else {
            $st.deepFails = [int]$st.deepFails + 1
            if ($st.t2Pending) { $st.postT2Fails = [int]$st.postT2Fails + 1 }
            $deepFail = $true
            Log "deep FAIL http=$code consecutive=$($st.deepFails) postT2=$($st.postT2Fails)" 'WARN'
        }
    } else { Log "probe OK tick=$($st.tick) deepFails=$($st.deepFails) postT2=$($st.postT2Fails)" }
}

$df = [int]$st.deepFails
if ($deepFail -and $df -ge $T1After) {
    $locked = Test-DeployLock
    # ---- T1: container-level repair - only meaningful when the distro itself
    # is reachable (probe ok) but the stack health check fails. On probe-fail
    # (distro unreachable) an in-distro docker restart can only time out. ----
    if ($df -ge $T1After -and $df -lt $T2After -and ($probe -eq $true) -and -not $locked -and -not (Cooled $st.lastT1 $T1CooldownMin)) {
        Log "T1 ACTION: in-distro repair $T1RepairCmd (fail #$df)" 'WARN'
        if (-not $DryRun) {
            Wsl-Run @('bash','-c',$T1RepairCmd) 90 $null | Out-Null
            $st.lastT1 = (Get-Date).ToString('o')
        }
    }
    elseif ($df -lt $T2After -and -not ($probe -eq $true)) {
        Log "distro unreachable at fail #$df - T1 skipped (needs reachable distro); T2 arms at fail #$T2After" 'WARN'
    }
    # ---- T2: targeted distro terminate ----
    elseif ($df -ge $T2After -and $df -lt $T3After -and -not $locked -and -not (Cooled $st.lastT2 $T2CooldownMin)) {
        Log "T2 ACTION: wsl --terminate $Distro (fail #$df)" 'WARN'
        if (-not $DryRun) {
            Notify 'wsl-guardian T2: terminating distro' "$Distro terminated after $df sustained failures. Containers recover via restart policies."
            $null = Wsl-Admin @('--terminate', $Distro) 60
            Start-Sleep -Seconds 15
            Wsl-Run @('true') 30 $null | Out-Null
            # deepFails resets (fresh ladder) but postT2Fails keeps counting
            # post-terminate failures so T3 stays reachable.
            $st.lastT2 = (Get-Date).ToString('o'); $st.deepFails = 0; $st.postT2Fails = 0; $st.t2Pending = $true
        }
    }
    # ---- T3: full VM bounce ----
    elseif ($st.t2Pending -and [int]$st.postT2Fails -ge $T3After -and -not $locked -and -not (Cooled $st.lastT3 $T3CooldownMin)) {
        Log "T3 ACTION: wsl --shutdown (postT2 #$($st.postT2Fails), post-T2 unrecovered)" 'WARN'
        if (-not $DryRun) {
            Notify 'wsl-guardian T3: VM bounce' "wsl --shutdown after $($st.postT2Fails) post-terminate failures (T2 did not recover). Applies pending .wslconfig changes; containers recover via policies."
            $null = Wsl-Admin @('--shutdown') 120
            Start-Sleep -Seconds 15
            Wsl-Run @('true') 30 $null | Out-Null
            Start-Sleep -Seconds 30
            $v = Wsl-Run @('bash','-c',$VerifyCmd) 60 "$StateDir\verify.txt"
            Log "T3 verify: http=$v"
            $st.lastT3 = (Get-Date).ToString('o'); $st.deepFails = 0; $st.postT2Fails = 0; $st.t2Pending = $false
        }
    }
    elseif ($locked) { Log "action suppressed: FRESH .deploy.lock (fail #$df)" 'WARN' }
    else { Log "action suppressed by cooldown (fail #$df)" }
}

Set-State $st
