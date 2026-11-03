<#
.SYNOPSIS
    Pre-bounce safety checklist - run before any WSL/Docker restart.
.DESCRIPTION
    Checks for active workloads, Devin sessions, running jobs, and estimates downtime.
    Registered as hub command: pre-bounce-check (category: monitoring)
#>
#requires -Version 5.1
# CATEGORY: monitoring
param(
    [switch]$Force,
    [switch]$Quiet,
    [int]$MaxDowntimeMinutes = 10
)

$ErrorActionPreference = 'SilentlyContinue'
$logFile = 'D:\DevOptimizer\logs\pre-bounce-check.log'

function Log { param($msg) Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) }
function Write-Out { param($msg) if (-not $Quiet) { Write-Host $msg }; Log $msg }
function Write-Warn { param($msg) if (-not $Quiet) { Write-Host $msg -ForegroundColor Yellow }; Log "WARN: $msg" }
function Write-Err { param($msg) if (-not $Quiet) { Write-Host $msg -ForegroundColor Red }; Log "ERROR: $msg" }
function Write-Ok { param($msg) if (-not $Quiet) { Write-Host $msg -ForegroundColor Green }; Log "OK: $msg" }

$issues = @()
$warnings = @()
$info = @()

Write-Out "=== Pre-Bounce Safety Checklist ==="
Write-Out ""

# --- 1. Devin.exe check -----------------------------------------------------
Write-Out "[1/8] Checking Devin.exe..."
$devinProc = Get-Process Devin -ErrorAction SilentlyContinue
if ($devinProc) {
    $issues += "Devin.exe is RUNNING (PID $($devinProc.Id), CPU: $([math]::Round($devinProc.CPU,1))s)"
    Write-Err "  BLOCKER: Devin.exe is running. Bounce will disconnect active session."
} else {
    Write-Ok "  Devin.exe: NOT RUNNING"
}

# --- 2. devin-server in WSL -------------------------------------------------
Write-Out "[2/8] Checking devin-server in WSL..."
$devinSrv = wsl.exe -d Ubuntu-24.04 -e sh -lc 'pgrep -fc "out/server-main.js" 2>/dev/null' 2>$null
if ("$devinSrv".Trim() -match '^[1-9]') {
    $warnings += "devin-server alive in WSL ($devinSrv processes). Container recreate won't touch it, but CLI may be affected."
    Write-Warn "  devin-server: RUNNING ($devinSrv processes)"
} else {
    Write-Ok "  devin-server: NOT RUNNING"
}

# --- 3. Critical containers with state --------------------------------------
Write-Out "[3/8] Checking stateful containers..."
$criticalContainers = @(
    @{ Name = 'social-postgres';     Reason = 'Primary database (port 5433)' },
    @{ Name = 'postgres';            Reason = 'Secondary database (port 5432)' },
    @{ Name = 'redis';               Reason = 'Cache/session store' },
    @{ Name = 'minio';               Reason = 'Object storage' },
    @{ Name = 'chroma';              Reason = 'Vector database' },
    @{ Name = 'social-api';          Reason = 'SocialAuto API' },
    @{ Name = 'social-frontend';     Reason = 'SocialAuto Frontend' },
    @{ Name = 'n8n';                 Reason = 'Workflow automation' }
)

$runningCritical = @()
foreach ($c in $criticalContainers) {
    $status = docker ps --filter "name=^/$($c.Name)$" --format '{{.Status}}' 2>$null
    if ($status) {
        $runningCritical += $c.Name
        $info += "$($c.Name): $status - $($c.Reason)"
        Write-Out "  $($c.Name): $status"
    }
}

# --- 4. Long-running jobs (n8n executions) ----------------------------------
Write-Out "[4/8] Checking n8n active executions..."
try {
    $n8nUrl = 'http://localhost:5678/api/v1/executions?status=running&limit=5'
    $resp = curl.exe -s -m 5 $n8nUrl 2>$null
    if ($resp -and $resp -match '"data"') {
        $json = $resp | ConvertFrom-Json
        if ($json.data -and $json.data.Count -gt 0) {
            $warnings += "n8n has $($json.data.Count) running execution(s)"
            Write-Warn "  n8n: $($json.data.Count) RUNNING execution(s)"
            foreach ($exec in $json.data | Select-Object -First 3) {
                Write-Warn "    - $($exec.workflowId) (started: $($exec.startedAt))"
            }
        } else {
            Write-Ok "  n8n: No running executions"
        }
    } else {
        Write-Out "  n8n: API not accessible (may be starting)"
    }
} catch {
    Write-Out "  n8n: Check skipped (error: $_)"
}

# --- 5. Docker build/run operations -----------------------------------------
Write-Out "[5/8] Checking Docker operations..."
$building = docker ps --filter "status=created" --filter "status=restarting" --format '{{.Names}}' 2>$null
if ($building) {
    $warnings += "Containers in transitional state: $($building -join ', ')"
    Write-Warn "  Transitional containers: $($building -join ', ')"
} else {
    Write-Ok "  No containers in created/restarting state"
}

# --- 6. Host memory pressure ------------------------------------------------
Write-Out "[6/8] Checking host memory pressure..."
try {
    $availMB = [int](Get-Counter '\Memory\Available MBytes' -ErrorAction Stop).CounterSamples[0].CookedValue
    if ($availMB -lt 1200) {
        $issues += "CRITICAL: Host available memory ${availMB} MB (<1200 MB)"
        Write-Err "  Available: ${availMB} MB (CRITICAL)"
    } elseif ($availMB -lt 2500) {
        $warnings += "LOW: Host available memory ${availMB} MB (<2500 MB)"
        Write-Warn "  Available: ${availMB} MB (LOW)"
    } else {
        Write-Ok "  Available: ${availMB} MB (OK)"
    }
} catch {
    Write-Out "  Memory check: unavailable"
}

# --- 7. VRAM pressure -------------------------------------------------------
Write-Out "[7/8] Checking VRAM pressure..."
$nsmi = nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>$null
if ($nsmi -match '(\d+)\s*,\s*(\d+)') {
    $vramUsed = [int]$Matches[1]; $vramTotal = [int]$Matches[2]
    $vramPct = [int](100 * $vramUsed / $vramTotal)
    if ($vramPct -gt 90) {
        $issues += "CRITICAL: VRAM ${vramPct}% (${vramUsed}/${vramTotal} MB)"
        Write-Err "  VRAM: ${vramPct}% (${vramUsed}/${vramTotal} MB) - CRITICAL"
    } elseif ($vramPct -gt 80) {
        $warnings += "HIGH: VRAM ${vramPct}% (${vramUsed}/${vramTotal} MB)"
        Write-Warn "  VRAM: ${vramPct}% (${vramUsed}/${vramTotal} MB) - HIGH"
    } else {
        Write-Ok "  VRAM: ${vramPct}% (${vramUsed}/${vramTotal} MB) - OK"
    }
} else {
    Write-Out "  VRAM: nvidia-smi unavailable"
}

# --- 8. Estimate downtime ---------------------------------------------------
Write-Out "[8/8] Estimating downtime..."
$containerCount = (docker ps -q 2>$null | Measure-Object).Count
$downCount = (docker ps -a --filter "status=exited" --format '{{.Names}}' 2>$null | Measure-Object).Count
$restartPolicyAlways = (docker ps -a --format '{{.Names}} {{.HostConfig.RestartPolicy.Name}}' 2>$null | Where-Object { $_ -match 'always|unless-stopped' } | Measure-Object).Count

$estSeconds = 30 + ($containerCount * 2) + ($restartPolicyAlways * 5)
$estMinutes = [math]::Ceiling($estSeconds / 60)

Write-Out "  Running containers: $containerCount"
Write-Out "  Auto-restart containers: $restartPolicyAlways"
Write-Out "  Estimated bounce time: ~$estMinutes minute(s)"

if ($estMinutes -gt $MaxDowntimeMinutes) {
    $warnings += "Estimated downtime ($estMinutes min) exceeds threshold ($MaxDowntimeMinutes min)"
    Write-Warn "  WARNING: Estimated downtime ($estMinutes min) > threshold ($MaxDowntimeMinutes min)"
}

# --- Summary ----------------------------------------------------------------
Write-Out ""
Write-Out "=== SUMMARY ==="
if ($issues.Count -gt 0) {
    Write-Err "BLOCKERS ($($issues.Count)):"
    foreach ($i in $issues) { Write-Err "  - $i" }
}
if ($warnings.Count -gt 0) {
    Write-Warn "WARNINGS ($($warnings.Count)):"
    foreach ($w in $warnings) { Write-Warn "  - $w" }
}
if ($info.Count -gt 0) {
    Write-Out "INFO ($($info.Count)):"
    foreach ($i in $info) { Write-Out "  - $i" }
}

Write-Out ""
if ($issues.Count -gt 0 -and -not $Force) {
    Write-Err "BOUNCE BLOCKED: $($issues.Count) blocker(s) found. Use -Force to override."
    exit 2
} elseif ($issues.Count -gt 0 -and $Force) {
    Write-Warn "BOUNCE ALLOWED (forced): $($issues.Count) blocker(s) overridden."
    exit 1
} elseif ($warnings.Count -gt 0) {
    Write-Warn "BOUNCE CAUTION: $($warnings.Count) warning(s). Review before proceeding."
    exit 1
} else {
    Write-Ok "BOUNCE SAFE: No blockers or warnings."
    exit 0
}