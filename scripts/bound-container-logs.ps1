<#
.SYNOPSIS
    Bound json-file logs on existing containers by force-recreating their compose
    projects (downtime-bearing - report-only unless -Apply).
.DESCRIPTION
    daemon.json caps log sizes only for containers created AFTER it was written;
    the 40 existing containers still write unbounded json-file logs. This script
    snapshots which containers have restart=no (the deliberate trims), groups
    unbounded containers by compose project, and with -Apply runs
    'docker compose up -d --force-recreate' per project from inside Ubuntu-26.04
    (the compose files live there), then re-applies restart=no and stops those
    trimmed containers again. Gates: defers while Devin.exe or devin-server is
    alive - recreate bounces the stack Devin works against.
    ALWAYS run once without -Apply first to review the plan.
#>
#requires -Version 5.1
# CATEGORY: docker
param(
    [switch]$Apply,
    [string]$Distro = 'Ubuntu-26.04'
)
$ErrorActionPreference = 'SilentlyContinue'
$logFile = 'D:\DevOptimizer\logs\bound-container-logs.log'
function Log { param($msg) Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) }

Log ("--- bound-container-logs run started (Apply={0}) ---" -f [bool]$Apply)

# --- [1] Gates -----------------------------------------------------------------
if (Get-Process Devin -ErrorAction SilentlyContinue) { Log 'Devin.exe running - DEFERRED (exit 2)'; exit 2 }
$devinSrv = & wsl.exe -d $Distro -e sh -lc 'pgrep -fc "devin-server" 2>/dev/null' 2>$null
if ("$devinSrv".Trim() -match '^[1-9]') { Log 'devin-server alive in distro - DEFERRED (exit 2)'; exit 2 }
docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Log 'docker engine not reachable (skipped)'; exit 0 }

# --- [2] Snapshot the deliberate restart=no trims --------------------------------
$restartNo = @()
foreach ($line in (docker ps -a --format '{{.Names}}' 2>$null)) {
    $pol = (docker inspect $line --format '{{.HostConfig.RestartPolicy.Name}}' 2>$null) -replace "`r", ''
    if ($pol -eq 'no') { $restartNo += $line }
}
Log ("restart=no snapshot ({0}): {1}" -f $restartNo.Count, ($restartNo -join ', '))

# --- [3] Find unbounded containers + their compose projects -----------------------
$unbounded = @()
foreach ($line in (docker ps -a --format '{{.Names}}' 2>$null)) {
    $lc = (docker inspect $line --format '{{.HostConfig.LogConfig.Config}}' 2>$null) -replace "`r", ''
    if ($lc -notmatch 'max-size') { $unbounded += $line }
}
Log ("unbounded containers: {0} of {1}" -f $unbounded.Count, ((docker ps -a --format '{{.Names}}' 2>$null | Measure-Object).Count))
$projects = @{}
foreach ($c in $unbounded) {
    $proj = (docker inspect $c --format '{{index .Labels "com.docker.compose.project"}}' 2>$null) -replace "`r", ''
    $dir  = (docker inspect $c --format '{{index .Labels "com.docker.compose.project.working_dir"}}' 2>$null) -replace "`r", ''
    if ($proj -and $dir) { $projects[$proj] = $dir }
}
foreach ($k in $projects.Keys) { Log ("project {0} -> {1}" -f $k, $projects[$k]) }
if (-not $Apply) { Log 'report-only (no -Apply). Review the plan above, then re-run with -Apply.'; exit 0 }

# --- [4] Recreate per project ------------------------------------------------------
$failed = 0
foreach ($k in $projects.Keys) {
    Log ("recreating project {0}..." -f $k)
    & wsl.exe -d $Distro -e sh -lc ("cd '{0}' && docker compose up -d --force-recreate 2>&1 | tail -3" -f $projects[$k]) 2>$null |
        ForEach-Object { Log ("  {0}" -f $_) }
    if ($LASTEXITCODE -ne 0) { $failed++; Log ("project {0} recreate FAILED (exit {1})" -f $k, $LASTEXITCODE) }
}

# --- [5] Re-apply restart=no trims --------------------------------------------------
foreach ($c in $restartNo) {
    $pol = (docker inspect $c --format '{{.HostConfig.RestartPolicy.Name}}' 2>$null) -replace "`r", ''
    if ($pol -ne 'no') {
        docker update --restart=no $c 2>$null | Out-Null
        docker stop $c 2>$null | Out-Null
        Log ("re-applied restart=no + stopped: {0}" -f $c)
    }
}

# --- [6] Verify ----------------------------------------------------------------------
$stillUnbounded = 0
foreach ($line in (docker ps -a --format '{{.Names}}' 2>$null)) {
    $lc = (docker inspect $line --format '{{.HostConfig.LogConfig.Config}}' 2>$null) -replace "`r", ''
    if ($lc -notmatch 'max-size') { $stillUnbounded++ }
}
$unhealthy = (docker ps --filter 'health=unhealthy' --format '{{.Names}}' 2>$null | Measure-Object).Count
$probe = curl.exe -s -o NUL -w '%{http_code}' -m 8 'http://localhost:9390/metrics' 2>$null
Log ("verify: still-unbounded={0} unhealthy={1} 9390/metrics={2} failed-projects={3}" -f $stillUnbounded, $unhealthy, $probe, $failed)
Log '--- run complete ---'
exit $(if ($failed -gt 0) { 1 } else { 0 })
