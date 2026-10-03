<#
.SYNOPSIS
    Checks broken refs.
.DESCRIPTION
    Checks broken refs.
#>

# Find all broken script references: .bat/.cmd -> .ps1 targets, registry entries -> files
$root = 'D:\DevOptimizer'
$problems = @()

# 1. Batch launchers -> referenced ps1
$bats = Get-ChildItem "$root\portable" -Include '*.bat','*.cmd' -Recurse -File -ErrorAction SilentlyContinue
$bats += Get-ChildItem $root -Include '*.bat','*.cmd' -File -ErrorAction SilentlyContinue
foreach ($b in $bats) {
    $content = [IO.File]::ReadAllText($b.FullName)
    $ps1refs = [regex]::Matches($content, '[A-Za-z0-9_\-\.\\%\$~ ]+\.ps1') | ForEach-Object { $_.Value.Trim() }
    foreach ($ref in $ps1refs) {
        $expanded = $ref -replace '%DEVOPT_HOME%', $root -replace '%~dp0\.\.', $root -replace '%~dp0', $b.DirectoryName
        $expanded = [regex]::Replace($expanded, '%[^%]+%', $root)  # any other env var -> try root
        $candidates = @(
            $expanded,
            (Join-Path $root $expanded),
            (Join-Path $root (Split-Path $expanded -Leaf))
        ) | Where-Object { $_ -and (Test-Path $_) }
        if (-not $candidates) {
            $problems += [pscustomobject]@{ Type='BAT->PS1'; Launcher=$b.FullName.Replace("$root\",''); Target=$ref }
        }
    }
}

# 2. Hub registry -> file paths
$regPath = "$root\config\hub-registry.json"
if (Test-Path $regPath) {
    $reg = Get-Content $regPath -Raw | ConvertFrom-Json
    $cmds = if ($reg.commands) { $reg.commands } else { $reg }
    foreach ($c in $cmds) {
        $p = if ($c.Path) { $c.Path } elseif ($c.FilePath) { $c.FilePath } elseif ($c.Script) { $c.Script }
        if ($p -and -not (Test-Path $p)) {
            $problems += [pscustomobject]@{ Type='REGISTRY'; Launcher=$c.Id; Target=$p }
        }
    }
}

Write-Host "=== Broken references: $($problems.Count) ==="
$problems | Group-Object Type | ForEach-Object { Write-Host ("  {0}: {1}" -f $_.Name, $_.Count) }
Write-Host ""
$problems | Sort-Object Type, Launcher | ForEach-Object {
    Write-Host ("[{0}] {1}" -f $_.Type, $_.Launcher)
    Write-Host ("      -> {0}" -f $_.Target)
}
