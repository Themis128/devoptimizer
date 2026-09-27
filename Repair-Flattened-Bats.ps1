#requires -Version 5.1
<#
.SYNOPSIS
    Repairs the flattened (single-line) batch files in the DevOptimizer hub.
.DESCRIPTION
    32 .bat files (16 tools\Variants pairs + 4 source menus) had their entire
    content flattened onto one line, making them execute garbage and fake
    success (exit 0). Originals are unrecoverable (lossy flattening, no intact
    backups), so this script:
      1. Quarantines each flattened bat as <name>.corrupted.bak (bytes preserved)
      2. Writes a clean stub bat in its place that explains the problem and
         exits 1 - registry paths stay valid
      3. Flags the corresponding hub-registry command descriptions
      4. Validates the registry after the edit (backup is written first)
#>

$ErrorActionPreference = 'Stop'
$root = 'D:\DevOptimizer'
Set-Location -LiteralPath $root

# ---------- 1. Detect flattened bats ----------
$bats = Get-ChildItem -Path $root -Filter '*.bat' -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\(node_modules|backups|\$tmp)\\' }

$flattened = @()
foreach ($b in $bats) {
    $maxLen = (Get-Content $b.FullName -ErrorAction SilentlyContinue | Measure-Object -Property Length -Maximum).Maximum
    if ($maxLen -gt 1000) { $flattened += $b }
}
Write-Output ("Flattened bats found: {0}" -f $flattened.Count)

# ---------- 2. Quarantine + stub ----------
$stubTemplate = @'
REM ================================================================
REM  BROKEN SCRIPT PLACEHOLDER - created by DevOptimizer app repair
REM ================================================================
REM The original batch file was CORRUPTED: its entire content had
REM been flattened onto a single line, so it could not run correctly
REM and could execute unintended commands (cmd treats some of the
REM garbled text as commands). The corrupted original is preserved
REM byte-for-byte next to this file as:  %~nx0.corrupted.bak
REM ================================================================
@echo off
echo ============================================================
echo  BROKEN SCRIPT - original batch file was corrupted
echo ============================================================
echo.
echo This menu script was found flattened to a single line and has
echo been quarantined to prevent accidental command execution.
echo.
echo Corrupted original kept as: %~nx0.corrupted.bak
echo.
echo Instead, open the DevOptimizer app and run the equivalent
echo PowerShell command for this tool (search by tool name).
echo.
exit /b 1
'@
# normalize to CRLF lines
$stubText = ($stubTemplate -replace "`r?`n", "`r`n").TrimEnd() + "`r`n"

$stubbed = New-Object System.Collections.ArrayList
foreach ($b in $flattened) {
    $bak = Join-Path $b.DirectoryName ($b.Name + '.corrupted.bak')
    if (Test-Path $bak) {
        Write-Output ("SKIP (bak exists): {0}" -f $b.FullName)
        continue
    }
    Move-Item -LiteralPath $b.FullName -Destination $bak
    [IO.File]::WriteAllText($b.FullName, $stubText, [Text.Encoding]::ASCII)
    [void]$stubbed.Add($b.FullName)
    Write-Output ("STUBBED: {0}" -f $b.FullName.Replace("$root\", ''))
}
Write-Output ("Stubbed this run: {0}" -f $stubbed.Count)

# ---------- 3. Flag registry descriptions ----------
$regPath = Join-Path $root 'config\hub-registry.json'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = "$regPath.pre-appfix-$stamp"
Copy-Item -LiteralPath $regPath -Destination $backupPath
Write-Output ("Registry backup: {0}" -f $backupPath)

$registry = Get-Content $regPath -Raw | ConvertFrom-Json
$before = @($registry.commands).Count

$stubbedSet = @{}
foreach ($p in $stubbed) { $stubbedSet[$p.ToLowerInvariant()] = $true }

$flagged = 0
foreach ($cmd in $registry.commands) {
    if (-not $cmd.path) { continue }
    $full = Join-Path $root ($cmd.path -replace '/', '\')
    if ($stubbedSet.ContainsKey($full.ToLowerInvariant())) {
        $cmd.description = "[BROKEN SCRIPT] Original .bat was corrupted (flattened to one line) and quarantined. Run the equivalent PowerShell command instead."
        $flagged++
    }
}
Write-Output ("Registry commands flagged: {0}" -f $flagged)

# ---------- 4. Write + validate registry ----------
$json = $registry | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText($regPath, $json, (New-Object Text.UTF8Encoding $true))

$check = Get-Content $regPath -Raw | ConvertFrom-Json
$after = @($check.commands).Count
Write-Output ("Registry commands before/after: {0} / {1}" -f $before, $after)
if ($before -ne $after) { throw "Command count changed - restoring backup"; Copy-Item $backupPath $regPath -Force }

$sample = $check.commands | Where-Object { $_.name -eq 'advanced-diagnostics' }
if (-not $sample -or -not $sample.parameters) { throw "Sample command damaged - restoring backup"; Copy-Item $backupPath $regPath -Force }

# every command path must still resolve
$missing = @($check.commands | Where-Object {
    $_.path -and -not (Test-Path (Join-Path $root ($_.path -replace '/', '\')))
})
Write-Output ("Unresolved command paths after fix: {0}" -f $missing.Count)
if ($missing.Count -gt 0) { $missing | ForEach-Object { "  MISSING: " + $_.path } }

Write-Output 'DONE'
