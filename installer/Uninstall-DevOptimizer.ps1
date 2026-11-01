#Requires -Version 5.1
<#
.SYNOPSIS
    Per-user uninstall of the DevOptimizer Windows 11 application.

.DESCRIPTION
    Removes the Start Menu shortcut, the HKCU Uninstall entry, and the
    autostart Run value. Does not delete any repository files.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File installer\Uninstall-DevOptimizer.ps1
#>

param([switch]$WhatIf)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$startMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'DevOptimizer'
$lnk = Join-Path $startMenuDir 'DevOptimizer.lnk'
$uninstKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DevOptimizer'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

$actions = @(
    @{ Name = 'Start menu shortcut'; If = { Test-Path $lnk };                Do = { Remove-Item -LiteralPath $lnk -Force } },
    @{ Name = 'Start menu folder';   If = { Test-Path $startMenuDir };       Do = { Remove-Item -LiteralPath $startMenuDir -Force } },
    @{ Name = 'Apps list entry';     If = { Test-Path $uninstKey };          Do = { Remove-Item -Path $uninstKey -Recurse -Force } },
    @{ Name = 'Protocol handler';    If = { Test-Path 'HKCU:\Software\Classes\devoptimizer' }; Do = { Remove-Item -Path 'HKCU:\Software\Classes\devoptimizer' -Recurse -Force } },
    @{ Name = 'Autostart value';     If = { (Get-ItemProperty -Path $runKey -Name 'DevOptimizer' -ErrorAction SilentlyContinue) -ne $null }; Do = { Remove-ItemProperty -Path $runKey -Name 'DevOptimizer' -ErrorAction SilentlyContinue } }
)

$performed = 0
foreach ($a in $actions) {
    if (& $a.If) {
        $performed++
        if ($WhatIf) {
            Write-Host ("WhatIf: would remove {0}" -f $a.Name)
        } else {
            & $a.Do
            Write-Host ("Removed {0}" -f $a.Name)
        }
    }
}
if ($performed -eq 0 -and -not $WhatIf) { Write-Host 'Nothing to remove - DevOptimizer is not installed.' }
Write-Host 'Uninstall complete.'
