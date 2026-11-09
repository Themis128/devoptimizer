<#
.SYNOPSIS
    DevOptimizer repo housekeeping - archives transient reports, quarantines NT-native junk names
.DESCRIPTION
    Safe, idempotent cleanup of D:\DevOptimizer root clutter:
      1. Moves stale transient reports (script-validation-report-*, TEST-RESULTS-*,
         event-log-report-*, invalid-scripts-*, cleanup-log.txt, stderr/stdout.log)
         older than -OlderThanDays into archive\housekeeping-<timestamp>\reports\
      2. Quarantines NT-native filenames invisible to Win32 (names containing ':'
         such as flattened 'D:DevOptimizer...' paths, ':TEMP', 'NUL') into
         archive\housekeeping-<timestamp>\nt-names\ via Git Bash (MSYS sees them,
         PowerShell/cmd do not). Original names recorded in manifest-nt-names.tsv.
      3. Quarantines tiny stub docs (*.md/*.txt < 100 bytes in root, e.g.
         IMPROVEMENTS-v2.0.md) into archive\housekeeping-<timestamp>\tiny-files\
      4. Writes summary.md + manifest into the archive folder and appends
         logs\housekeeping.log.
    Nothing is deleted - everything is moved to archive\ (gitignored).
.NOTES
    - CATEGORY: cleanup
    - Use -DryRun to preview without moving anything.
    - Git Bash required only for step 2; skipped with a warning if absent.
#>
#requires -Version 5.1
# CATEGORY: cleanup

[CmdletBinding()]
param(
    [int]$OlderThanDays = 14,
    [string]$Root = 'D:\DevOptimizer',
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$archRel = "archive\housekeeping-$stamp"
$archAbs = Join-Path $Root $archRel
$reportsDir = Join-Path $archAbs 'reports'
$ntDir      = Join-Path $archAbs 'nt-names'
$tinyDir    = Join-Path $archAbs 'tiny-files'
$logFile    = Join-Path $Root 'logs\housekeeping.log'

function Log {
    param([string]$msg)
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
    Write-Host $line
}

function To-BashPath {
    param([string]$WinPath)
    # D:\DevOptimizer\archive\x -> /d/DevOptimizer/archive/x
    $p = $WinPath -replace '\\', '/'
    return '/' + $p.Substring(0,1).ToLower() + $p.Substring(2)
}

Log "=== DevOptimizer Housekeeping (dryRun=$DryRun, olderThan=${OlderThanDays}d) ==="

$cutoff = (Get-Date).AddDays(-$OlderThanDays)
$reportPatterns = @(
    'script-validation-report-*.txt',
    'TEST-RESULTS-*.txt',
    'event-log-report-*.html',
    'invalid-scripts-*.txt',
    'cleanup-log.txt',
    'high-priority-invalid.txt',
    'stderr.log',
    'stdout.log'
)

# --- 1. Stale transient reports ---
$stale = @()
foreach ($pat in $reportPatterns) {
    $stale += Get-ChildItem -LiteralPath $Root -Filter $pat -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }
}
$stale = $stale | Sort-Object Name -Unique
Log ("[1] Stale report files found: {0} ({1:N1} KB)" -f $stale.Count, (($stale | Measure-Object Length -Sum).Sum / 1KB))

$reportMoves = @()
if ($stale.Count -gt 0) {
    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null }
    foreach ($f in $stale) {
        $dest = Join-Path $reportsDir $f.Name
        if ($DryRun) {
            $reportMoves += [pscustomobject]@{ Name = $f.Name; Action = 'would move'; KB = [math]::Round($f.Length/1KB,1) }
        } else {
            try {
                Move-Item -LiteralPath $f.FullName -Destination $dest -Force -ErrorAction Stop
                $reportMoves += [pscustomobject]@{ Name = $f.Name; Action = 'moved'; KB = [math]::Round($f.Length/1KB,1) }
            } catch {
                Log "  WARN move failed '$($f.Name)': $_"
                $reportMoves += [pscustomobject]@{ Name = $f.Name; Action = "FAILED: $_"; KB = 0 }
            }
        }
    }
}

# --- 2. NT-native names via Git Bash ---
$bashCandidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe'
)
$bashExe = $bashCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bashExe) {
    $cmd = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -notmatch 'System32|WindowsApps') { $bashExe = $cmd.Source }
}

$ntMoves = @()
if (-not $bashExe) {
    Log '[2] SKIP: Git Bash not found - NT-native name sweep unavailable'
} else {
    $rootBash  = To-BashPath $Root
    $destBash  = To-BashPath $ntDir
    $dryVal    = if ($DryRun) { '1' } else { '0' }

    $bashScript = @'
set -u
cd "$HK_ROOT" || { echo "HK_ROOT_MISSING"; exit 1; }
mkdir -p "$HK_DEST"
MAN="$HK_DEST/manifest-nt-names.tsv"
shopt -s dotglob nullglob
for path in *; do
  name="${path##*/}"
  case "$name" in
    *:*|NUL) ;;
    *) continue ;;
  esac
  san="${name//:/__}"
  target="$HK_DEST/$san"
  i=2
  while [ -e "$target" ]; do target="$HK_DEST/$san.$i"; i=$((i+1)); done
  if [ -d "$path" ]; then kind=dir; else kind=file; fi
  size=$(stat -c %s "$path" 2>/dev/null || echo 0)
  if [ "$HK_DRY" = "1" ]; then
    printf 'DRY\t%s\t%s\t%s\n' "$kind" "$name" "$size"
  else
    if mv -- "$path" "$target" 2>/dev/null; then
      printf '%s\t%s\t%s\t%s\n' "$name" "$(basename "$target")" "$kind" "$size" >> "$MAN"
      printf 'MOVED\t%s\t%s\n' "$kind" "$name"
    else
      printf 'FAIL\t%s\t%s\n' "$kind" "$name"
    fi
  fi
done
'@
    $env:HK_ROOT = $rootBash
    $env:HK_DEST = $destBash
    $env:HK_DRY  = $dryVal
    $shFile = Join-Path $env:TEMP "devopt-housekeeping-$stamp.sh"
    $bashScript | Set-Content -Path $shFile -Encoding ASCII
    $out = & $bashExe $shFile 2>&1
    Remove-Item $shFile -Force -ErrorAction SilentlyContinue
    Remove-Item Env:HK_ROOT, Env:HK_DEST, Env:HK_DRY -ErrorAction SilentlyContinue

    if ($out -contains 'HK_ROOT_MISSING') {
        Log "[2] ERROR: cannot cd to $rootBash"
    } else {
        $movedLines = @($out | Where-Object { $_ -match '^(MOVED|DRY)\t' })
        $failLines  = @($out | Where-Object { $_ -match '^FAIL\t' })
        foreach ($l in $movedLines) {
            $parts = $l -split "`t"
            $ntMoves += [pscustomobject]@{ Kind = $parts[1]; Name = $parts[2]; Action = $(if ($parts[0] -eq 'DRY') { 'would move' } else { 'moved' }) }
        }
        foreach ($l in $failLines) { Log "  WARN nt-move failed: $l" }
        Log ("[2] NT-native entries: {0} moved/quarantined, {1} failed" -f $ntMoves.Count, $failLines.Count)
    }
}

# --- 2b. Tiny stub docs (*.md/*.txt < 100 bytes in root) ---
$tiny = Get-ChildItem -LiteralPath $Root -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.md','.txt') -and $_.Length -lt 100 }
$tinyMoves = @()
if ($tiny.Count -gt 0) {
    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $tinyDir | Out-Null }
    foreach ($f in $tiny) {
        $dest = Join-Path $tinyDir $f.Name
        if ($DryRun) {
            $tinyMoves += [pscustomobject]@{ Name = $f.Name; Bytes = $f.Length; Action = 'would move' }
        } else {
            try {
                Move-Item -LiteralPath $f.FullName -Destination $dest -Force -ErrorAction Stop
                $tinyMoves += [pscustomobject]@{ Name = $f.Name; Bytes = $f.Length; Action = 'moved' }
            } catch {
                Log "  WARN tiny-move failed '$($f.Name)': $_"
            }
        }
    }
    Log ("[2b] Tiny stub files: {0}" -f $tiny.Count)
}

# --- 3. Summary ---
if (-not $DryRun -and ($stale.Count -gt 0 -or $ntMoves.Count -gt 0 -or $tinyMoves.Count -gt 0)) {
    $summary = Join-Path $archAbs 'summary.md'
    $lines = @(
        "# Housekeeping $stamp",
        '',
        "- Root: ``$Root``",
        "- OlderThanDays: $OlderThanDays",
        "- Reports archived: $($reportMoves.Count)",
        "- NT-native names quarantined: $($ntMoves.Count)",
        "- Tiny stub files quarantined: $($tinyMoves.Count)",
        '',
        '## Reports'
    )
    $lines += $reportMoves | ForEach-Object { "- $($_.Name) ($($_.Action), $($_.KB) KB)" }
    $lines += @('', '## NT-native names')
    $lines += $ntMoves | ForEach-Object { "- $($_.Kind): $($_.Name)" }
    if ($tinyMoves.Count -gt 0) {
        $lines += @('', '## Tiny stub files')
        $lines += $tinyMoves | ForEach-Object { "- $($_.Name) ($($_.Bytes) bytes, $($_.Action))" }
    }
    $lines -join "`n" | Set-Content -Path $summary -Encoding UTF8
    Log "[3] Summary written: $archRel\summary.md"
} elseif ($DryRun) {
    Log '[3] DryRun - no files moved, no archive created'
} else {
    Log '[3] Nothing to do - root already clean'
}

Log '=== Housekeeping done ==='
