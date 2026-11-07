<#
.SYNOPSIS
    Checks all syntax.
.DESCRIPTION
    Checks all syntax.

.PARAMETER RootPath
    Root directory to scan for .ps1 files. Defaults to current directory.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RootPath = (Get-Location).Path
)

$files = Get-ChildItem $RootPath -Recurse -Include '*.ps1' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch 'backups|backup-|logs|node_modules|\.zcode' }

$bad = @()
foreach ($f in $files) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        $bad += [pscustomobject]@{
            File   = $f.FullName.Replace($RootPath + '\', '')
            Errors = ($errs | ForEach-Object { "L$($_.Extent.StartLineNumber): $($_.Message)" }) -join ' | '
        }
    }
}

Write-Host "Scanned $($files.Count) .ps1 files"
if ($bad.Count -eq 0) {
    Write-Host 'ALL SYNTAX OK'
} else {
    Write-Host "$($bad.Count) files with syntax errors:`n"
    foreach ($b in $bad) { Write-Host "[$($b.File)]"; Write-Host "  $($b.Errors)`n" }
    exit 1
}
