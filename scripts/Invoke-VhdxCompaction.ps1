<#
.SYNOPSIS
    DevOptimizer automation script: Invoke-VhdxCompaction.
.DESCRIPTION
    DevOptimizer automation script: Invoke-VhdxCompaction.
#>

# Invoke-VhdxCompaction.ps1 - Devin-safe nightly WSL/Docker vhdx compaction.
# CATEGORY: maintenance
#
# Scheduled daily 03:45 via \DevOptimizer\WSL-Vhdx-Compact (Register-VhdxCompaction.ps1)
# and called in-library by elevated-complete-cleanup.ps1 (Part 1).
#
# DEVIN PROTECTION (the whole point): never touches WSL while Devin could be
# using it. Gates, checked BEFORE anything is stopped:
#   1. Any Devin.exe process  -> DEFERRED (exit 2). Retried by Task Scheduler.
#   2. devin-server alive in Ubuntu-24.04 -> DEFERRED (Devin's remote-auto-shutdown
#      clears it shortly after the app closes, unblocking a later run).
# UNC folders (\\wsl.localhost\Ubuntu-24.04\home\...) are only served while the VM
# runs, so gating on the app + server means an active session can never be killed.
#
# Robust unlock (fixes the 0x80070020 file-in-use failure of 2026-09-27):
#   graceful Docker Desktop quit -> wsl --shutdown -> poll until vmmemWSL is gone
#   AND each vhdx opens exclusively (no blind sleep) -> Optimize-VHD -Mode Full.
#
# Growth threshold: compacts a vhdx only on first run or when it grew >= 10 GB
# since the last successful compaction (state: logs\vhdx-compaction-state.json).
#
# Restart after: Docker Desktop (containers return via restart policies) and the
# Ubuntu-24.04 distro (UNC paths resolve again immediately).
#
# Exit codes: 0 = compacted or skipped-by-threshold, 1 = failure (system restored),
# 2 = deferred (Devin active). Pass -AsLibrary to reuse from another script
# (sets $global:LAST_VHDX_COMPACTION instead of exiting).
param(
    [int]$MinGrowthGB = 10,
    [string]$StatePath = 'D:\DevOptimizer\logs\vhdx-compaction-state.json',
    [switch]$ForceAll,
    [switch]$AsLibrary
)

$distro = 'Ubuntu-24.04'
# Per-user install on this host; Program Files path does not exist (2026-11-11).
$dockerDesktopExe = "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
if (-not (Test-Path $dockerDesktopExe)) { $dockerDesktopExe = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe" }

function Invoke-Wsl([string]$cmd) {
    $out = & wsl.exe -d $distro -- bash -c $cmd 2>$null
    $joined = (@($out) -join "`n") -replace "`0", ''
    return ($joined -split "`r?`n") | Where-Object { $_ -ne '' }
}

function Test-VhdxUnlocked([string]$path) {
    try {
        $fs = [System.IO.File]::Open($path, 'Open', 'Read', 'None')
        $fs.Close()
        return $true
    } catch { return $false }
}

function Get-VhdxTargets {
    $targets = @()
    Get-ChildItem "$env:LOCALAPPDATA\wsl" -Recurse -Filter *.vhdx -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $targets += $_.FullName }
    # Ubuntu-24.04 lives at C:\WSL (custom install location) - outside LOCALAPPDATA\wsl
    Get-ChildItem 'C:\WSL' -Recurse -Filter *.vhdx -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $targets += $_.FullName }
    $dockerDisk = "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx"
    if (Test-Path $dockerDisk) { $targets += $dockerDisk }
    return $targets | Select-Object -Unique
}

function Invoke-VhdxCompactionMain {
    $result = [ordered]@{ status = 'unknown'; details = @() }
    $log = { param($m) Write-Host $m; $result.details += $m }

    # --- Admin gate (Task Scheduler runs this as SYSTEM; interactive use needs UAC) ---
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $result.status = 'not-admin'
        & $log '[FAIL] not elevated - Optimize-VHD requires admin. Nothing was touched.'
        return $result
    }

    # --- DEVIN GATE 1: the app itself ---
    if (Get-Process -Name 'Devin' -ErrorAction SilentlyContinue) {
        $result.status = 'deferred'
        & $log '[DEFERRED] Devin is active - WSL untouched. Will retry on the next scheduled run.'
        return $result
    }

    # --- DEVIN GATE 2: a lingering devin-server in the distro (auto-shutdown not fired yet) ---
    $server = Invoke-Wsl "pgrep -f 'server-mai[n]' || true"
    if ($server -match '\d') {
        $result.status = 'deferred'
        & $log '[DEFERRED] devin-server still alive in Ubuntu-24.04 - WSL untouched. Its auto-shutdown clears this gate shortly after Devin closes.'
        return $result
    }
    & $log '[ OK ] Devin gates passed (no app, no server)'

    $targets = Get-VhdxTargets
    if (-not $targets) {
        $result.status = 'no-targets'
        & $log '[FAIL] no vhdx files found - nothing to do'
        return $result
    }

    # --- Growth threshold (per vhdx; first run always qualifies) ---
    $state = if (Test-Path $StatePath) { Get-Content $StatePath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json } else { $null }
    $toCompact = @()
    foreach ($t in $targets) {
        $sizeGB = [math]::Round((Get-Item $t).Length / 1GB, 2)
        $prev = if ($state) { $state.$t } else { $null }
        if ($ForceAll -or -not $prev -or (($sizeGB - $prev.lastSizeAfterGB) -ge $MinGrowthGB)) {
            $reason = if ($ForceAll) { 'forced' } elseif (-not $prev) { 'first run' } else { "grew $([math]::Round($sizeGB - $prev.lastSizeAfterGB, 2)) GB" }
            & $log ("[ OK ] {0} ({1} GB) qualifies: {2}" -f $t, $sizeGB, $reason)
            $toCompact += $t
        } else {
            & $log ("[SKIP] {0}: grew only {1} GB since last compaction (threshold {2} GB)" -f $t, [math]::Round($sizeGB - $prev.lastSizeAfterGB, 2), $MinGrowthGB)
        }
    }
    if (-not $toCompact) {
        $result.status = 'skipped'
        & $log '[SKIP] no vhdx grew enough to justify a compaction'
        return $result
    }

    # --- Graceful Docker Desktop quit (releases docker_data.vhdx cleanly) ---
    $dd = Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue
    if ($dd) {
        & $log '[ .. ] quitting Docker Desktop gracefully...'
        $dd | ForEach-Object { [void]$_.CloseMainWindow() }
        $waited = 0
        while ((Get-Process -Name 'com.docker.backend' -ErrorAction SilentlyContinue) -and $waited -lt 90) {
            Start-Sleep 3; $waited += 3
        }
        foreach ($n in 'com.docker.backend', 'Docker Desktop') {
            Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        & $log "[ OK ] Docker Desktop stopped (waited $waited s)"
    }

    # --- wsl --shutdown + poll until the disks are truly released ---
    & $log '[ .. ] wsl --shutdown'
    wsl --shutdown 2>&1 | Out-Null
    $deadline = (Get-Date).AddSeconds(120)
    do {
        Start-Sleep 3
        $vmGone = -not (Get-Process -Name 'vmmemWSL' -ErrorAction SilentlyContinue)
        $allUnlocked = ($toCompact | Where-Object { -not (Test-VhdxUnlocked $_) }).Count -eq 0
        if (-not ($vmGone -and $allUnlocked)) {
            & $log "[ .. ] waiting for WSL disks to release (vmmemWSL gone: $vmGone, vhdx unlocked: $allUnlocked)..."
        }
    } while ((-not ($vmGone -and $allUnlocked)) -and (Get-Date) -lt $deadline)

    if (-not ($vmGone -and $allUnlocked)) {
        $result.status = 'failed-locked'
        & $log '[FAIL] WSL disks still locked after 120 s - restoring WSL/Docker and aborting compaction.'
        Start-Process $dockerDesktopExe
        [void](Invoke-Wsl 'echo ok')
        return $result
    }
    & $log '[ OK ] WSL fully stopped, vhdx files unlocked'

    # --- Convert distro disks to sparse VHD while stopped (idempotent; sparse
    #     auto-releases freed blocks so manual compaction stops being needed) ---
    foreach ($d in 'docker-desktop','Ubuntu-24.04') {
        & $log ("[ .. ] set-sparse {0}" -f $d)
        wsl --manage $d --set-sparse true 2>&1 | Out-Null
    }

    # --- Compact + record state ---
    $state = if ($state) { $state } else { [pscustomobject]@{} }
    $compacted = 0; $freedTotal = 0
    foreach ($t in $toCompact) {
        if (-not (Test-VhdxUnlocked $t)) { & $log "[FAIL] $t re-locked - skipping"; continue }
        # Sparse VHDs reject Optimize-VHD ("must not be sparse") and self-reclaim.
        if ((& fsutil sparse queryflag $t 2>&1) -match 'set as sparse') {
            & $log "[SKIP] $t is sparse - auto-reclaims, no Optimize-VHD needed"
            continue
        }
        $before = (Get-Item $t).Length
        & $log ("[ .. ] Optimize-VHD: {0} ({1} GB)..." -f $t, [math]::Round($before / 1GB, 2))
        try {
            Optimize-VHD -Path $t -Mode Full -ErrorAction Stop | Out-Null
            $after = (Get-Item $t).Length
            $freed = [math]::Round(($before - $after) / 1GB, 2)
            $freedTotal += $freed; $compacted++
            & $log ("[ OK ] {0}: {1} GB -> {2} GB (freed {3} GB)" -f $t, [math]::Round($before / 1GB, 2), [math]::Round($after / 1GB, 2), $freed)
            $state | Add-Member -NotePropertyName $t -NotePropertyValue ([pscustomobject]@{ lastSizeAfterGB = [math]::Round($after / 1GB, 2); lastRun = (Get-Date).ToString('o') }) -Force
        } catch {
            & $log "[FAIL] Optimize-VHD on ${t}: $($_.Exception.Message)"
        }
    }
    $state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StatePath -Encoding UTF8

    # --- Restart WSL + Docker (UNC paths and containers come back) ---
    & $log '[ .. ] restarting Ubuntu-24.04 and Docker Desktop...'
    [void](Invoke-Wsl 'echo ok')
    if (Test-Path $dockerDesktopExe) { Start-Process $dockerDesktopExe }
    & $log ("[ OK ] done: {0} vhdx compacted, {1} GB freed. Devin will reconnect cleanly on next open." -f $compacted, $freedTotal)

    $result.status = 'compacted'
    $result.compacted = $compacted
    $result.freedGB = $freedTotal
    return $result
}

$script:LAST_VHDX_COMPACTION = Invoke-VhdxCompactionMain
if (-not $AsLibrary) {
    switch ($script:LAST_VHDX_COMPACTION.status) {
        'compacted' { exit 0 }
        'skipped'   { exit 0 }
        'no-targets'{ exit 0 }
        'deferred'  { exit 2 }
        default     { exit 1 }
    }
}