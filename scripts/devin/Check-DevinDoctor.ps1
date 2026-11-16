<#
.SYNOPSIS
    Devin Doctor data-store health check (read-only): pipx + devin-doctor installer and hub wrapper.
.DESCRIPTION
    Wraps the community "devin-doctor" tool (github.com/Icaro0310/devin-doctor), which
    diagnoses Devin Desktop's local data stores: sessions.db / acp-messages / state.vscdb,
    schema version, credentials.toml, .devin/ hooks and MCP config, and disk usage.
    Strictly read-only against Devin's data; this wrapper writes only its own logs.
    First run auto-installs pipx and devin-doctor (README route: python -m pip install
    --user pipx, ensurepath, pipx install from GitHub) unless -SkipInstall is given.
    Saves a dated JSON snapshot under logs\devin-doctor\ for disk-trend tracking and
    writes a DevOptimizer event 1005 (Error) when the check reports FAIL findings.
    Note: if Devin Desktop is running, its DBs may be locked (SQLITE_BUSY warnings);
    close Devin and re-run for the cleanest report. Schema-bound to store versions
    v15-v17; a newer Devin schema reports FAIL by design.
#>
#requires -Version 5.1
# CATEGORY: maintenance
param(
    [switch]$SkipInstall,     # never install anything; just locate and run
    [switch]$JsonOnly,        # print raw JSON to console (still logged + snapshotted)
    [string]$DataDir,         # override Devin data dir (default: %APPDATA%\devin)
    [string]$ConfigDir        # override Devin UI config root (default: %APPDATA%\Devin)
)

$ErrorActionPreference = 'SilentlyContinue'
$logFile = 'D:\DevOptimizer\logs\devin-doctor-check.log'
$snapshotDir = 'D:\DevOptimizer\logs\devin-doctor'

function Log { param($msg)
    Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
}

Log '--- devin-doctor run started ---'

# --- [1] Python host -----------------------------------------------------------
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Source }
if (-not $py) {
    Log 'FAIL: no python interpreter found (needed for pipx/devin-doctor)'
    Write-Host 'FAIL: python not found' -ForegroundColor Red
    exit 2
}

# --- [2] Locate (or install) devin-doctor ---------------------------------------
function Find-Doctor {
    $c = @()
    $cmd = Get-Command devin-doctor -ErrorAction SilentlyContinue
    if ($cmd) { $c += $cmd.Source }
    $binDir = $env:PIPX_BIN_DIR
    if (-not $binDir) { $binDir = Join-Path $env:USERPROFILE '.local\bin' }
    $exe = Join-Path $binDir 'devin-doctor.exe'
    if (Test-Path $exe) { $c += $exe }
    return $c | Select-Object -First 1
}

$doctor = Find-Doctor
if (-not $doctor) {
    if ($SkipInstall) {
        Log 'devin-doctor not found and -SkipInstall given (exiting)'
        Write-Host 'devin-doctor not installed (run without -SkipInstall to install)' -ForegroundColor Yellow
        exit 2
    }
    Log 'devin-doctor not found - installing pipx + devin-doctor (documented route)'
    & $py -m pip install --user pipx 2>&1 | Select-Object -Last 2 | ForEach-Object { Log "  pip: $_" }
    & $py -m pipx ensurepath 2>&1 | ForEach-Object { Log "  pipx: $_" }
    & $py -m pipx install 'git+https://github.com/Icaro0310/devin-doctor.git' 2>&1 | Select-Object -Last 3 | ForEach-Object { Log "  pipx: $_" }
    $doctor = Find-Doctor
    if (-not $doctor) {
        Log 'FAIL: devin-doctor still not found after install attempt (see lines above)'
        Write-Host 'FAIL: devin-doctor install did not produce an executable - check log' -ForegroundColor Red
        exit 2
    }
    Log "installed: $doctor"
} else {
    Log "using: $doctor"
}

# --- [3] Build arguments ---------------------------------------------------------
$doctorArgs = @('check')
if ($DataDir)   { $doctorArgs += @('--data-dir', $DataDir) }
if ($ConfigDir) { $doctorArgs += @('--config-dir', $ConfigDir) }

# --- [4] Human-readable check ----------------------------------------------------
$checkOut = & $doctor @doctorArgs 2>&1
$checkExit = $LASTEXITCODE
$checkOut | ForEach-Object { Log "  check: $_" }
$checkOut | Where-Object { $_ -match 'PASS|WARN|FAIL|health|overall' } | Write-Host

# --- [5] JSON snapshot (for disk-trend tracking) -----------------------------------
$jsonOut = & $doctor @doctorArgs '--json' 2>&1
$jsonText = ($jsonOut | Out-String).Trim()
try {
    if (-not (Test-Path $snapshotDir)) { New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null }
    $snapPath = Join-Path $snapshotDir ("devin-doctor-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date))
    $jsonText | Out-File -FilePath $snapPath -Encoding utf8
    Log "snapshot: $snapPath"
    $parsed = $jsonText | ConvertFrom-Json
    $overall = $parsed.overall
    if ($overall) { Log "overall: $overall" }
} catch {
    Log "snapshot/parse issue: $($_.Exception.Message)"
}

# --- [6] Verdict + event -----------------------------------------------------------
if ($checkExit -eq 0) {
    Log 'devin-doctor: no FAIL findings (exit 0)'
    Write-Host 'devin-doctor check complete: no FAIL findings' -ForegroundColor Green
    exit 0
} else {
    Log "devin-doctor reported FAIL findings (exit $checkExit) - see check lines above"
    Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1005 -EntryType Error `
        -Message "devin-doctor reported FAIL findings (exit $checkExit). Run 'scripts\devin\Check-DevinDoctor.ps1' for details; fix suggestions are printed per finding." `
        -ErrorAction SilentlyContinue
    Write-Host 'devin-doctor check complete: FAIL findings present (event 1005 written)' -ForegroundColor Red
    exit 1
}
