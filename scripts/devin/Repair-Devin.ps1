# Repair-Devin.ps1 - guarded repair actions for Devin Desktop's WSL remote
# CATEGORY: maintenance
<#
.SYNOPSIS
    Opt-in repair actions for Devin Desktop's WSL remote (devin-server in Ubuntu-24.04).

.DESCRIPTION
    Companion to Check-DevinHealth.ps1 (which detects problems and can repair a corrupt
    bundle). This script performs the individual repair actions with a dry-run default:
    with no switches it only prints what each repair WOULD do and changes nothing.

    Never touches: extensions/, data/, settings, the live commit dir, or .installation_lock.
    The rule from the field notes: check WSL health FIRST - stale .devin-server state is
    rarely the issue. The one exception is a corrupt bundle (ERR_MODULE_NOT_FOUND in
    server-main.js or extensionHostProcess.js), which -FixBundle handles.

.PARAMETER FixBundle
    Kill devin-server and delete the current commit's bundle dir so the next
    'Reload Window' in Devin re-downloads a fresh one (~700 MB). Only runs when the
    bundle actually fails the integrity test, unless -Commit names a specific commit
    or -Force is given.

.PARAMETER Commit
    40-hex commit dir to target with -FixBundle instead of the auto-detected one.

.PARAMETER CleanLeftovers
    Delete superseded commit dirs in ~/.devin-server/bin/ (everything except the live
    commit) plus their stale .log/.pid/.token sidecar files. Repairs leave the previous
    commit's dir behind; it is dead weight once the client has moved on.

.PARAMETER PruneServerLogs
    Delete files in ~/.devin-server/data/logs/ older than -Days days (pre-repair
    session logs accumulate here).

.PARAMETER Days
    Age threshold in days for -PruneServerLogs. Default 14.

.PARAMETER Confirm
    Accepted for explicitness; confirmation prompts appear by default before every
    destructive step.

.PARAMETER Force
    Skip the confirmation prompts and (for -FixBundle) the intact-bundle refusal.

.EXAMPLE
    .\Repair-Devin.ps1
    Dry-run: shows what each repair would do right now. Changes nothing.

.EXAMPLE
    .\Repair-Devin.ps1 -FixBundle
    Repair a corrupt bundle (then click 'Reload Window' in Devin).

.EXAMPLE
    .\Repair-Devin.ps1 -CleanLeftovers -PruneServerLogs -Days 7

.NOTES
    Exit codes: 0 = done (dry-run or repairs completed); 1 = refused/not applicable
    (WSL down, bundle intact without -Force); 2 = -FixBundle executed (finish with
    Reload Window in Devin). See memory: devin-desktop-install.
#>
param(
    [switch]$FixBundle,
    [string]$Commit,
    [switch]$CleanLeftovers,
    [switch]$PruneServerLogs,
    [int]$Days = 14,
    [switch]$Confirm,
    [switch]$Force
)

$distro = 'Ubuntu-24.04'

function Invoke-Wsl([string]$cmd) {
    $out = & wsl.exe -d $distro -- bash -c $cmd 2>$null
    $joined = (@($out) -join "`n") -replace "`0", ''
    # wsl.exe can deliver multi-line output as ONE element with embedded
    # newlines; split so callers always get real lines.
    return ($joined -split "`r?`n") | Where-Object { $_ -ne '' }
}

function Approve([string]$what) {
    if ($Force) { return $true }
    Write-Host "[ASK ] about to: $what" -ForegroundColor Yellow
    $answer = Read-Host "       type YES to continue (anything else skips)"
    return ($answer -ceq 'YES')
}

Write-Host "=== Devin Repair ($distro) ===" -ForegroundColor Cyan

# --- Guard: WSL must be up (the check-WSL-first rule) ---
$ping = Invoke-Wsl 'echo ok'
if ($ping -notmatch 'ok') {
    Write-Host "[FAIL] WSL distro '$distro' unreachable - check WSL FIRST (Docker VM state, vmmemWSL memory, wsl --shutdown recovery) before touching Devin." -ForegroundColor Red
    exit 1
}
Write-Host "[ OK ] WSL distro reachable" -ForegroundColor Green

$dryRun = (-not ($FixBundle -or $CleanLeftovers -or $PruneServerLogs))
if ($dryRun) { Write-Host "[ DRY ] no action switches given - dry-run, nothing will change" -ForegroundColor Cyan }

# --- State: live commit + bundle integrity ---
$procs = Invoke-Wsl "pgrep -af 'server-mai[n]' || true"
$liveCommit = $null
if ($procs -match '\.devin-server/bin/([a-f0-9]{40})/') { $liveCommit = $Matches[1] }

$allDirs = @(Invoke-Wsl "ls -1 `$HOME/.devin-server/bin/ 2>/dev/null || true") | Where-Object { $_ -match '^[a-f0-9]{40}$' }
if (-not $liveCommit -and $allDirs.Count -gt 0) {
    # Server down: newest commit dir by mtime is the one the client will bootstrap
    $liveCommit = (Invoke-Wsl "ls -1t `$HOME/.devin-server/bin/ | head -1").Trim()
}
if ($liveCommit -notmatch '^[a-f0-9]{40}$') { $liveCommit = $null }

$bundleBroken = $false
if ($liveCommit) {
    $base = "`$HOME/.devin-server/bin/$liveCommit/node_modules"
    $check = Invoke-Wsl "test -d $base/minimist -a -d $base/@vscode && echo intact || echo broken"
    $bundleBroken = ($check -match 'broken')
}
$exitCode = 0

# --- -FixBundle ---
if ($FixBundle) {
    if (-not $liveCommit) {
        Write-Host "[FAIL] -FixBundle: no commit dir found in ~/.devin-server/bin and no server running - nothing to fix." -ForegroundColor Red
        exit 1
    }
    $allowed = $bundleBroken -or ($Commit -and $Commit -match '^[a-f0-9]{40}$') -or $Force
    if (-not $allowed) {
        Write-Host "[FAIL] -FixBundle refused: bundle for $liveCommit is INTACT. Nothing suggests corruption." -ForegroundColor Red
        Write-Host "       Use -Commit <40hex> to target a specific dir or -Force to override." -ForegroundColor Yellow
        exit 1
    }
    if ($dryRun -eq $false) {
        if (-not (Approve "kill devin-server and delete ~/.devin-server/bin/$liveCommit (~700 MB re-download on next Reload Window)")) {
            Write-Host "[SKIP] -FixBundle cancelled" -ForegroundColor Yellow
        } else {
            Write-Host "[FIX ] killing server + deleting bundle dir $liveCommit ..." -ForegroundColor Yellow
            [void](Invoke-Wsl "pkill -f 'server-mai[n]'; rm -rf `$HOME/.devin-server/bin/$liveCommit; echo done")
            Write-Host "[FIX ] done. NOW CLICK 'Reload Window' in Devin (or reopen) - a fresh bundle downloads automatically." -ForegroundColor Yellow
            $exitCode = 2
        }
    } else {
        Write-Host "[ DRY ] -FixBundle would delete: ~/.devin-server/bin/$liveCommit (bundleBroken=$bundleBroken)" -ForegroundColor Cyan
    }
}

# --- -CleanLeftovers ---
if ($CleanLeftovers) {
    $superseded = @($allDirs | Where-Object { $_ -ne $liveCommit })
    $sidecars = @()
    foreach ($d in $superseded) {
        $sidecars += @(Invoke-Wsl "ls -1 `$HOME/.devin-server/.$d.log `$HOME/.devin-server/.$d.pid `$HOME/.devin-server/.$d.token 2>/dev/null || true") | Where-Object { $_ }
    }
    if ($superseded.Count -eq 0 -and $sidecars.Count -eq 0) {
        Write-Host "[ OK ] -CleanLeftovers: nothing to clean (only the live commit exists)" -ForegroundColor Green
    } elseif ($dryRun) {
        Write-Host "[ DRY ] -CleanLeftovers would delete dirs: $($superseded -join ', '); sidecars: $($sidecars.Count) file(s)" -ForegroundColor Cyan
    } else {
        if (-not (Approve "delete $($superseded.Count) superseded commit dir(s) and $($sidecars.Count) sidecar file(s)")) {
            Write-Host "[SKIP] -CleanLeftovers cancelled" -ForegroundColor Yellow
        } else {
            foreach ($d in $superseded) {
                [void](Invoke-Wsl "rm -rf `$HOME/.devin-server/bin/$d; echo removed")
                Write-Host "[FIX ] deleted dir  ~/.devin-server/bin/$d" -ForegroundColor Yellow
            }
            foreach ($f in $sidecars) {
                $esc = $f.Trim()
                [void](Invoke-Wsl "rm -f '`$HOME/$(Split-Path $esc -Leaf)'; echo removed")
                Write-Host "[FIX ] deleted file $esc" -ForegroundColor Yellow
            }
            Write-Host "[ OK ] .installation_lock, extensions/ and data/ untouched" -ForegroundColor Green
        }
    }
}

# --- -PruneServerLogs ---
if ($PruneServerLogs) {
    $old = @(Invoke-Wsl "find `$HOME/.devin-server/data/logs -type f -mtime +$Days 2>/dev/null || true") | Where-Object { $_ }
    $sizeRaw = (Invoke-Wsl "find `$HOME/.devin-server/data/logs -type f -mtime +$Days -print0 2>/dev/null | xargs -0 -r du -ch 2>/dev/null | tail -1 | cut -f1")
    $size = if ($sizeRaw) { $sizeRaw.Trim() } else { "0" }
    if ($old.Count -eq 0) {
        Write-Host "[ OK ] -PruneServerLogs: no files older than $Days days" -ForegroundColor Green
    } elseif ($dryRun) {
        Write-Host "[ DRY ] -PruneServerLogs would delete $($old.Count) file(s) ($size) older than $Days days" -ForegroundColor Cyan
    } else {
        if (-not (Approve "delete $($old.Count) old server-log file(s) ($size)")) {
            Write-Host "[SKIP] -PruneServerLogs cancelled" -ForegroundColor Yellow
        } else {
            [void](Invoke-Wsl "find `$HOME/.devin-server/data/logs -type f -mtime +$Days -delete; echo pruned")
            Write-Host "[FIX ] pruned $($old.Count) file(s) ($size) from ~/.devin-server/data/logs" -ForegroundColor Yellow
        }
    }
}

# --- Dry-run summary (no switches given) ---
if ($dryRun) {
    if ($liveCommit) {
        Write-Host "[ DRY ] live commit: $liveCommit (bundle $(if ($bundleBroken) { 'BROKEN - -FixBundle applies' } else { 'intact' }))" -ForegroundColor Cyan
    } else {
        Write-Host "[ DRY ] live commit: none (server down, no commit dirs)" -ForegroundColor Cyan
    }
    Write-Host "[ DRY ] -FixBundle: $(if ($liveCommit -and $bundleBroken) { 'WOULD delete ' + $liveCommit } elseif ($liveCommit) { 'nothing (bundle intact)' } else { 'nothing (no commit)' })" -ForegroundColor Cyan
    Write-Host "[ DRY ] -CleanLeftovers: $(if (($allDirs | Where-Object { $_ -ne $liveCommit }).Count -gt 0) { 'WOULD delete ' + (($allDirs | Where-Object { $_ -ne $liveCommit }) -join ', ') } else { 'nothing' })" -ForegroundColor Cyan
    Write-Host "[ DRY ] -PruneServerLogs: run with -Days N to see file candidates" -ForegroundColor Cyan
    Write-Host "=== DRY-RUN COMPLETE - NOTHING CHANGED ===" -ForegroundColor Cyan
} else {
    Write-Host "=== REPAIR RUN COMPLETE ===" -ForegroundColor Cyan
}

exit $exitCode
