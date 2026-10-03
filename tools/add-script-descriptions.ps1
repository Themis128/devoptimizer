<#
.SYNOPSIS
    One-shot sweep: adds descriptions to every hub script missing one.
.DESCRIPTION
    Reads config\hub-registry.json for entries whose description is empty, then inserts
    comment-based help into each file:
      - .ps1          -> comment-based help block (.SYNOPSIS/.DESCRIPTION), inserted into an existing block or prepended
      - .bat / .cmd   -> a ":: SYNOPSIS: description" line at the top
    Uses byte-level insertion so original encoding, BOM, and line endings are preserved.
    Every modified file is backed up to logs\description-backups\<relative-path>.
    Descriptions come from a curated table (scripts with known purpose) with a
    verb-based heuristic fallback derived from the file name.
.PARAMETER DryRun
    Report planned changes without writing anything.
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = 'D:\DevOptimizer'
$reg = Get-Content (Join-Path $root 'config\hub-registry.json') -Raw | ConvertFrom-Json
$missing = @($reg.commands | Where-Object { -not $_.description -or $_.description -eq 'No description available' })
Write-Host ("Missing descriptions: {0}" -f $missing.Count)

# Curated descriptions (relative path -> description)
$curated = @{
    'scripts/check-cleanup-status.ps1'            = 'Read-only Win11 cleanup status assessment: drives, temp, dev caches, browser data, VHDX sizes, Docker usage.'
    'scripts/win11-safe-cleanup.ps1'              = 'User-level safe cleanup: user/Windows temp, dev caches, crash dumps, browser-cache subsets, Docker safe subset. No admin required.'
    'scripts/extended-cleanup.ps1'                = 'Extended cleanup (weekly): deeper user-level sweeps beyond the daily safe cleanup.'
    'scripts/elevated-complete-cleanup.ps1'       = 'Elevated complete cleanup: DISM component store, WU cache, Delivery Optimization, shadow copies, VHDX compaction. Requires admin.'
    'scripts/admin-cleanup-elevated.ps1'          = 'Admin cleanup suite run elevated: DISM, update caches, shadow-copy pruning.'
    'scripts/win11-admin-cleanup-elevated.ps1'    = 'Windows 11 admin cleanup (elevated): component store, update cache, Delivery Optimization, oldest shadow copy.'
    'scripts/win11-admin-cleanup.ps1'             = 'Windows 11 admin cleanup prep/wrapper (non-elevated side of the elevated cleanup pair).'
    'scripts/dev-cleanup.ps1'                     = 'Developer environment cleanup: package-manager caches, WSL, VS Code, leftover dev ports.'
    'scripts/windows-update-cleanup.ps1'          = 'Windows Update cache and component cleanup.'
    'scripts/enhanced-system-health.ps1'          = 'Enhanced system health report: hardware, services, event logs, performance counters.'
    'scripts/win11-health-snapshot.ps1'           = 'Windows 11 health snapshot: SMART, Defender, PnP devices, services, event-log errors.'
    'scripts/devin/Check-DevinHealth.ps1'         = 'Devin Desktop health check: bundles, tasks, MCP servers, maintenance-report status.'
    'modules/ollama-analytics.ps1'                = 'Ollama usage analytics module for the DevOptimizer hub.'
}

# Verb-based heuristic for the long tail
$verbMap = @{
    apply = 'Applies'; check = 'Checks'; start = 'Starts'; monitor = 'Monitors'
    cleanup = 'Cleans up'; clean = 'Cleans up'; verify = 'Verifies'; create = 'Creates'
    fix = 'Fixes'; remove = 'Removes'; uninstall = 'Uninstalls'; register = 'Registers'
    test = 'Tests'; bootstrap = 'Bootstraps'; configure = 'Configures'; config = 'Configures'
    audit = 'Audits'; collect = 'Collects'; rollback = 'Rolls back'; install = 'Installs'
    setup = 'Sets up'; update = 'Updates'; reorganize = 'Reorganizes'; discover = 'Discovers'
    build = 'Builds'; run = 'Runs'; demo = 'Demonstrates'
}

function Get-Desc([string]$rel, [string]$fileName) {
    if ($script:curated.ContainsKey($rel)) { return $script:curated[$rel] }
    $base = [IO.Path]::GetFileNameWithoutExtension($fileName)
    $tokens = @($base -split '[-_.]' | Where-Object { $_ })
    $first = $tokens[0].ToLower()
    if ($tokens.Count -gt 1 -and $verbMap.ContainsKey($first)) {
        $rest = ($tokens | Select-Object -Skip 1) -join ' '
        return ('{0} {1}.' -f $verbMap[$first], $rest.ToLower())
    }
    return ('DevOptimizer automation script: {0}.' -f $base)
}

$done = 0; $skipped = 0; $errors = 0
$backupRoot = Join-Path $root 'logs\description-backups'
foreach ($entry in $missing) {
    try {
        $rel = $entry.path -replace '/', '\'
        $full = Join-Path $root $rel
        if (-not (Test-Path $full)) { Write-Host "SKIP (not found): $rel"; $skipped++; continue }
        $bytes = [IO.File]::ReadAllBytes($full)
        $offset = 0
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $offset = 3 }
        $probeLen = [Math]::Min(8192, $bytes.Length - $offset)
        $head = [Text.Encoding]::ASCII.GetString($bytes, $offset, $probeLen)
        $desc = Get-Desc $entry.path ([IO.Path]::GetFileName($rel))
        $ext = [IO.Path]::GetExtension($rel).ToLower()

        if ($ext -eq '.ps1') {
            if ($head -match '\.SYNOPSIS') { $skipped++; continue }   # content already has help; registry lag
            $syn = ".SYNOPSIS`r`n    $desc`r`n.DESCRIPTION`r`n    $desc`r`n"
            $blockIdx = $head.IndexOf('<#')
            if ($blockIdx -ge 0) {
                # insert directives right after the opening <#
                $insertAt = $offset + $blockIdx + 2
                $insert = [Text.Encoding]::ASCII.GetBytes("`r`n" + $syn)
            } else {
                $insertAt = $offset
                $insert = [Text.Encoding]::ASCII.GetBytes("<#`r`n" + $syn + "#>`r`n`r`n")
            }
        }
        elseif ($ext -in '.bat', '.cmd') {
            if ($head -match '::\s*SYNOPSIS:') { $skipped++; continue }
            $insertAt = $offset
            $insert = [Text.Encoding]::ASCII.GetBytes(":: SYNOPSIS: $desc`r`n")
        }
        else { $skipped++; continue }

        if ($DryRun) {
            Write-Host ("DRY [{0}] {1} -> {2}" -f $ext, $rel, $desc)
        } else {
            # backup
            $backupPath = Join-Path $backupRoot $rel
            $backupDir = Split-Path $backupPath -Parent
            if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
            [IO.File]::WriteAllBytes($backupPath, $bytes)
            # splice: prefix + insertion + remainder
            $new = New-Object byte[] ($bytes.Length + $insert.Length)
            [Array]::Copy($bytes, 0, $new, 0, $insertAt)
            [Array]::Copy($insert, 0, $new, $insertAt, $insert.Length)
            [Array]::Copy($bytes, $insertAt, $new, $insertAt + $insert.Length, $bytes.Length - $insertAt)
            [IO.File]::WriteAllBytes($full, $new)
            $done++
        }
    }
    catch {
        $errors++
        Write-Host ("ERROR on {0}: {1}" -f $entry.path, $_.Exception.Message)
    }
}
Write-Host ""
if ($DryRun) { Write-Host ("DryRun complete: {0} would be modified, {1} skipped" -f ($missing.Count - $skipped), $skipped) }
else { Write-Host ("Sweep complete: {0} modified, {1} skipped, {2} errors" -f $done, $skipped, $errors) }
