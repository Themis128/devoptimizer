# dmr-ram-guard.ps1 - evict Docker Model Runner residents under host RAM pressure
# 2026-11-14: host hit 0.4-0.9GB free with ~10.5GB in com.docker.llama-server
#   processes (6 resident models). keep_alive already decays transients
#   (60s-15m) but under an active caller mix the decay can lag the dive.
#   wsl-guardian's T2/T3 ladder only reacts to probe FAILURES - by then the
#   host is already swapping. This is the gentle tier below that ladder.
# Every 5 min via conhost --headless scheduled task. Pure ASCII (PS 5.1).
#
# Tiers (set ABOVE Host Guard's ~1GB pri-5 crit line so eviction lands first;
# model loads come from real traffic so the load->crunch->evict loop is
# structural - the guard's job is to keep free RAM above the alarm line):
#   free < 1800MB : evict non-pinned residents (transients reload on demand)
#   free < 1000MB : also evict the pinned set (4B mid + 0.6B embedding) - a
#                   20-40s cold reload beats a host stall.
# Pinned = DMR_MID_MODEL (chatbot latency, 30m keep_alive by design) +
#          DMR_EMBEDDING_MODEL (keep-warm tier). Everything else is fair game.
param(
    [int]$WarnMb   = 1800,
    [int]$CritMb   = 1000,
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$LogFile = 'D:\DevOptimizer\logs\dmr-ram-guard.log'
New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null

function Log($m,$l='INFO'){ $line="{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$l,$m; $f=Get-Item $LogFile -ErrorAction SilentlyContinue; if($f -and $f.Length -gt 1MB){Get-Content $LogFile -Tail 500|Set-Content $LogFile -Encoding ASCII}; Add-Content $LogFile $line -Encoding ASCII; if($l -ne 'INFO'){Write-Output $line} }
function Notify($t,$b){ Log "ALERT: $t -- $b" 'WARN'; try{$h=@{Title=$t;Priority='default'};$tf=Join-Path $env:APPDATA 'devin\secrets\ntfy-devoptimizer-token';if(Test-Path $tf){$h['Authorization']='Bearer '+(Get-Content $tf -Raw).Trim()};Invoke-RestMethod -Uri 'https://ntfy.cloudless.gr/devoptimizer-alerts' -Method Post -Body $b -Headers $h -TimeoutSec 10|Out-Null}catch{Log "ntfy fail: $($_.Exception.Message)" 'WARN'} }

# Patterns matching the pinned residents - keep unless critical.
$Pinned = @('qwen3-4b-instruct', 'embedding-0.6b')

$freeMb = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB)
if ($freeMb -ge $WarnMb) { exit 0 }   # headroom ok - nothing to do

$ps = docker model ps 2>$null
if ($LASTEXITCODE -ne 0 -or -not $ps) { Log "free=${freeMb}MB but 'docker model ps' failed - engine flap?" 'WARN'; exit 1 }

$models = @()
foreach ($line in $ps | Select-Object -Skip 1) {
    $name = ($line -split '\s{2,}')[0].Trim()
    if ($name) { $models += $name }
}
if ($models.Count -eq 0) { Log "free=${freeMb}MB - no resident models to evict"; exit 0 }

$crit = $freeMb -lt $CritMb
$evict = @()
foreach ($m in $models) {
    $isPinned = $false
    foreach ($p in $Pinned) { if ($m -like "*$p*") { $isPinned = $true; break } }
    if ($crit -or -not $isPinned) { $evict += $m }
}
if ($evict.Count -eq 0) { Log "free=${freeMb}MB - only pinned residents left ($(($models -join ', ')))"; exit 0 }

Log "free=${freeMb}MB crit=$crit - evicting $($evict.Count)/$($models.Count): $($evict -join ', ')" 'WARN'
if ($DryRun) { exit 0 }
foreach ($m in $evict) {
    docker model unload $m 2>&1 | Out-Null
    Log "unloaded $m rc=$LASTEXITCODE"
}
Start-Sleep -Seconds 5
$afterMb = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB)
Log "free ${freeMb}MB -> ${afterMb}MB"

# Stage 2: docker model unload marks models inactive but the Windows-side
# com.docker.llama-server processes can linger holding GBs (observed 2026-11-15:
# 7-model eviction left free at 298MB until the procs were killed by hand ->
# +4GB instantly). Kill stragglers; DMR respawns them on demand.
if ($afterMb -lt $WarnMb) {
    $strays = @(Get-Process com.docker.llama-server -ErrorAction SilentlyContinue)
    if ($strays.Count -gt 0) {
        $strayMb = [int](($strays | Measure-Object WorkingSet64 -Sum).Sum/1MB)
        Log "still ${afterMb}MB - killing $($strays.Count) stray llama-server proc(s), ~${strayMb}MB" 'WARN'
        if (-not $DryRun) { $strays | Stop-Process -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 3
        $afterMb = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB)
        Log "post-kill free ${afterMb}MB"
    }
}
if ($crit) { Notify 'dmr-ram-guard CRIT' "host RAM ${freeMb}MB -> evicted $($evict.Count) model(s) incl. pinned set; now ${afterMb}MB free" }
exit 0
