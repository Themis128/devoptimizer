#Requires -Version 5.1
<#
.SYNOPSIS
    Per-user install of the DevOptimizer Windows 11 application.

.DESCRIPTION
    Registers the app for the current user only (no elevation):
      - Start Menu shortcut (DevOptimizer.lnk) pointing at app\bin\DevOptimizer.exe
      - HKCU Uninstall entry so the app appears in Windows Settings > Apps
    Idempotent: re-running refreshes the registration.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File installer\Install-DevOptimizer.ps1
#>

param(
    [string]$Version = '2.0.0',
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$exe = Join-Path $repo 'app\bin\DevOptimizer.exe'
$ico = Join-Path $repo 'app\DevOptimizer.ico'

if (-not (Test-Path $exe)) {
    throw "Launcher exe not found: $exe. Run scripts\Build-App.ps1 first."
}

$startMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'DevOptimizer'
$lnk = Join-Path $startMenuDir 'DevOptimizer.lnk'
$uninstKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DevOptimizer'
$uninstCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$repo\installer\Uninstall-DevOptimizer.ps1`""

if ($Unregister) {
    if (Test-Path $lnk) { Remove-Item -LiteralPath $lnk -Force }
    if (Test-Path $startMenuDir) { Remove-Item -LiteralPath $startMenuDir -Force -ErrorAction SilentlyContinue }
    if (Test-Path $uninstKey) { Remove-Item -Path $uninstKey -Recurse -Force }
    Write-Host 'DevOptimizer unregistered.'
    return
}

# Start Menu shortcut
if (-not (Test-Path $startMenuDir)) { New-Item -ItemType Directory -Force -Path $startMenuDir | Out-Null }
$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($lnk)
$sc.TargetPath = $exe
$sc.WorkingDirectory = $repo
if (Test-Path $ico) { $sc.IconLocation = "$ico,0" }
$sc.Description = 'DevOptimizer - Windows 11 optimization hub'
$sc.Save()

# Apps list (Windows Settings > Apps) via HKCU Uninstall
if (-not (Test-Path $uninstKey)) { New-Item -Path $uninstKey -Force | Out-Null }
New-ItemProperty -Path $uninstKey -Name 'DisplayName'      -Value 'DevOptimizer'                       -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstKey -Name 'DisplayVersion'   -Value $Version                             -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstKey -Name 'Publisher'        -Value 'DevOptimizer'                       -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstKey -Name 'DisplayIcon'      -Value $exe                                 -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstKey -Name 'InstallLocation'  -Value $repo                                -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstKey -Name 'UninstallString'  -Value $uninstCmd                           -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstKey -Name 'NoModify'         -Value 1                                    -PropertyType DWord  -Force | Out-Null
New-ItemProperty -Path $uninstKey -Name 'NoRepair'         -Value 1                                    -PropertyType DWord  -Force | Out-Null
New-ItemProperty -Path $uninstKey -Name 'SystemComponent'  -Value 0                                    -PropertyType DWord  -Force | Out-Null

# devoptimizer: protocol handler (deep links) — devoptimizer://command/<name>,
# devoptimizer://category/<name>, devoptimizer://settings. Points DIRECTLY at the
# app exe: the launcher's "--" separator breaks single-URL argument passthrough.
$protoKey = 'HKCU:\Software\Classes\devoptimizer'
New-Item -Path $protoKey -Force | Out-Null
New-ItemProperty -Path $protoKey -Name '(Default)'      -Value 'URL:DevOptimizer Protocol' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $protoKey -Name 'URL Protocol'   -Value ''                          -PropertyType String -Force | Out-Null
New-Item -Path "$protoKey\shell\open\command" -Force | Out-Null
$appExe = Join-Path $repo 'app\bin\DevOptimizer.App.exe'
New-ItemProperty -Path "$protoKey\shell\open\command" -Name '(Default)' -Value ('"{0}" "%1"' -f $appExe) -PropertyType String -Force | Out-Null

Write-Host ("DevOptimizer {0} installed (per user)." -f $Version)
Write-Host ("  Start menu : {0}" -f $lnk)
Write-Host ("  Apps list  : HKCU Uninstall\DevOptimizer")
Write-Host ("  Protocol   : devoptimizer:")
