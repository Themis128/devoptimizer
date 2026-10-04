<#
.SYNOPSIS
    NextCloud desktop client fine-tune status -- Windows 11 integration health and safe tuning.

.DESCRIPTION
    Read-only assessment of the NextCloud desktop client on this host:
      1. Client version, install path, running state
      2. Account server URL and per-folder sync mode from nextcloud.cfg (secrets filtered)
      3. Sync root location with a bounded VFS placeholder sample (never a full recursive walk)
      4. cldflt (Cloud Files mini-filter) driver state
      5. Autostart entry and Explorer navigation-pane flag
      6. Microsoft Defender exclusion state (path + process) -- readable only when elevated
      7. Client log/cache footprint
    Safe to run any time; makes no changes by default.

.PARAMETER ApplySafeTuning
    Apply the documented Windows-side tunings (nextcloud/desktop issue #10871 and
    help.nextcloud.com reports: the client's periodic local traversal makes Defender
    rescan tens of thousands of files each cycle):
      - Defender path exclusions: sync root, %LOCALAPPDATA%\Nextcloud, %APPDATA%\NextCloud
      - Defender process exclusion: nextcloud.exe
      - Ensure the cldflt cloud-files mini-filter starts automatically
    Self-elevates via UAC RunAs when needed. Idempotent: existing exclusions are kept.
    Sync behavior settings (VFS on/off, bandwidth, size limits) are intentionally
    NOT changed -- they are user choices, reported only.

.EXAMPLE
    .\fine-tune-nextcloud.ps1
    .\fine-tune-nextcloud.ps1 -ApplySafeTuning
#>
[CmdletBinding()]
param(
    [switch]$ApplySafeTuning
)

$ErrorActionPreference = 'SilentlyContinue'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host "=== NextCloud Fine-Tune -- $stamp ==="

# --- Client install & process ------------------------------------------------
$clientExe = Join-Path $env:ProgramFiles 'Nextcloud\nextcloud.exe'
if (Test-Path $clientExe) {
    $ver = (Get-Item $clientExe).VersionInfo.FileVersion
    Write-Host ("[1] Client          : v{0} at {1}" -f $ver, $clientExe)
} else {
    Write-Host "[1] Client          : NOT FOUND at $clientExe (nothing to tune)"
    exit 1
}
$proc = Get-Process nextcloud -ErrorAction SilentlyContinue | Select-Object -First 1
Write-Host ("    Running         : " + $(if ($proc) { "yes (pid $($proc.Id))" } else { "no" }))

# --- Config (secrets filtered) ------------------------------------------------
$cfgPath = Join-Path $env:APPDATA 'NextCloud\nextcloud.cfg'
$serverUrl = $null; $syncRoot = $null; $vfsMode = $null
if (Test-Path $cfgPath) {
    $cfg = Get-Content $cfgPath
    $serverUrl = ($cfg | Where-Object { $_ -match '^0\\url=' }) -replace '^0\\url=', '' | Select-Object -First 1
    $syncRoot  = ($cfg | Where-Object { $_ -match 'localPath=' }) -replace '^.*?localPath=', '' | Select-Object -First 1
    $vfsMode   = ($cfg | Where-Object { $_ -match 'virtualFilesMode=' }) -replace '^.*?virtualFilesMode=', '' | Select-Object -First 1
    $vfsGeneral = ($cfg | Where-Object { $_ -match '^isVfsEnabled=' }) -replace '^isVfsEnabled=', '' | Select-Object -First 1
    $trash = ($cfg | Where-Object { $_ -match '^moveToTrash=' }) -replace '^moveToTrash=', '' | Select-Object -First 1
    $navPane = ($cfg | Where-Object { $_ -match '^showInExplorerNavigationPane=' }) -replace '^showInExplorerNavigationPane=', '' | Select-Object -First 1
    $bigLimit = ($cfg | Where-Object { $_ -match 'newBigFolderSizeLimit=' }) -replace '^.*?newBigFolderSizeLimit=', '' | Select-Object -First 1
    $upLimit = ($cfg | Where-Object { $_ -match 'networkUploadLimitSetting=' }) -replace '^.*?networkUploadLimitSetting=', '' | Select-Object -First 1
    $downLimit = ($cfg | Where-Object { $_ -match 'networkDownloadLimitSetting=' }) -replace '^.*?networkDownloadLimitSetting=', '' | Select-Object -First 1
    Write-Host ("[2] Server          : {0}" -f $serverUrl)
    Write-Host ("    Sync folder     : {0} (vfs mode: {1}; general isVfsEnabled: {2})" -f $syncRoot, $vfsMode, $vfsGeneral)
    Write-Host ("    Behavior        : moveToTrash={0}; navPane={1}; bigFolderLimit={2} MB; upLimit={3}; downLimit={4} (0=unlimited, report-only)" -f $trash, $navPane, $bigLimit, $upLimit, $downLimit)
} else {
    Write-Host "[2] Config          : nextcloud.cfg not found (client not configured)"
}
if (-not $syncRoot) { $syncRoot = Join-Path $env:USERPROFILE 'Nextcloud' }
$syncRoot = $syncRoot.TrimEnd('/')

# --- Sync root: bounded sample (full walk over VFS is minutes-slow) -----------
if (Test-Path $syncRoot) {
    $top = Get-ChildItem $syncRoot -Force -ErrorAction SilentlyContinue
    $sample = $top | ForEach-Object {
        if ($_.PSIsContainer) { Get-ChildItem $_.FullName -Force -File -ErrorAction SilentlyContinue } else { $_ }
    } | Select-Object -First 300
    $ph = ($sample | Where-Object { $_.Attributes -match 'Offline|RecallOnDataAccess|Sparse' } | Measure-Object).Count
    $local = ($sample | Where-Object { $_.Attributes -notmatch 'Offline|RecallOnDataAccess|Sparse' } | Measure-Object).Count
    Write-Host ("[3] Sync root       : present; {0} top-level entries; sample {1} files -> {2} local / {3} cloud-placeholders" -f ($top | Measure-Object).Count, ($sample | Measure-Object).Count, $local, $ph)
} else {
    Write-Host "[3] Sync root       : MISSING ($syncRoot)"
}

# --- cldflt mini-filter --------------------------------------------------------
$cldflt = Get-Service cldflt -ErrorAction SilentlyContinue
if ($cldflt) {
    Write-Host ("[4] cldflt driver   : {0} / {1}" -f $cldflt.Status, $cldflt.StartType)
} else {
    Write-Host "[4] cldflt driver   : not present (VFS unavailable)"
}

# --- Autostart ------------------------------------------------------------------
$run = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
$auto = $run -and $run.PSObject.Properties.Name -contains 'Nextcloud'
Write-Host ("[5] Autostart       : " + $(if ($auto) { "registered (HKCU Run)" } else { "NOT registered" }))

# --- Defender exclusions (read; elevated-only values) ---------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$exPaths = $null; $exProcs = $null
if ($isAdmin) {
    $mp = Get-MpPreference -ErrorAction SilentlyContinue
    $exPaths = $mp.ExclusionPath; $exProcs = $mp.ExclusionProcess
    if ($exPaths) { Write-Host "[6] Defender paths  : $($exPaths -join '; ')" } else { Write-Host "[6] Defender paths  : (none)" }
    if ($exProcs) { Write-Host ("    Defender procs  : " + ($exProcs -join '; ')) } else { Write-Host "    Defender procs  : (none)" }
} else {
    Write-Host "[6] Defender        : run elevated (or -ApplySafeTuning) to read/apply exclusions"
}

# --- Client data footprint -------------------------------------------------------
$dataDirs = @((Join-Path $env:APPDATA 'NextCloud'), (Join-Path $env:LOCALAPPDATA 'Nextcloud'))
foreach ($d in $dataDirs) {
    if (Test-Path $d) {
        $mb = [math]::Round((Get-ChildItem $d -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB, 1)
        Write-Host ("[7] Data dir        : {0} = {1} MB" -f $d, $mb)
    }
}

# --- Apply safe tuning ------------------------------------------------------------
if (-not $ApplySafeTuning) {
    Write-Host "`n=== Status only (use -ApplySafeTuning to apply Defender exclusions + cldflt check) ==="
    exit 0
}

Write-Host "`n=== Applying safe tuning ==="
if (-not $isAdmin) {
    # Self-elevate via UAC RunAs (repo convention) and re-run with the switch.
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ApplySafeTuning')
    Start-Process powershell -ArgumentList $argList -Verb RunAs -Wait
    exit $LASTEXITCODE
}

$targets = @($syncRoot, (Join-Path $env:LOCALAPPDATA 'Nextcloud'), (Join-Path $env:APPDATA 'NextCloud'))
foreach ($t in $targets) {
    $have = $exPaths -contains $t
    if ($have) {
        Write-Host ("[ok] exclusion already present: {0}" -f $t)
    } else {
        Add-MpPreference -ExclusionPath $t -ErrorAction Stop
        Write-Host ("[added] Defender path exclusion: {0}" -f $t)
    }
}
if ($exProcs -notcontains 'nextcloud.exe') {
    Add-MpPreference -ExclusionProcess 'nextcloud.exe' -ErrorAction Stop
    Write-Host "[added] Defender process exclusion: nextcloud.exe"
} else {
    Write-Host "[ok] process exclusion already present: nextcloud.exe"
}
if ($cldflt -and $cldflt.StartType -ne 'Automatic') {
    Set-Service cldflt -StartupType Automatic
    Write-Host "[changed] cldflt StartType -> Automatic (was $($cldflt.StartType))"
} else {
    Write-Host "[ok] cldflt StartType already Automatic"
}
$mp2 = Get-MpPreference -ErrorAction SilentlyContinue
Write-Host ("`nPost-state path exclusions : " + ($mp2.ExclusionPath -join '; '))
Write-Host ("Post-state process exclusions: " + ($mp2.ExclusionProcess -join '; '))
Write-Host "=== Done ==="
