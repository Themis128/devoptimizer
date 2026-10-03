<#
.SYNOPSIS
    Registers bat sync task.
.DESCRIPTION
    Registers bat sync task.
#>

param(
    [string]$Root = "D:\DevOptimizer",
    [string]$TaskName = "DevOptimizer\\BAT-Sync",
    [string]$StartupLauncherName = "DevOptimizer-BAT-Sync.cmd"
)

$syncScript = Join-Path $Root "scripts\sync-bat-ps1.ps1"
if (-not (Test-Path $syncScript)) {
    throw "Sync script not found at $syncScript"
}

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
$powershell = Get-Command powershell -ErrorAction SilentlyContinue

if ($pwsh) {
    $exec = $pwsh.Source
} elseif ($powershell) {
    $exec = $powershell.Source
} else {
    throw "Neither pwsh nor powershell executable was found on PATH."
}

$command = '"' + $exec + '" -NoProfile -ExecutionPolicy Bypass -File "' + $syncScript + '"'

$deleteArgs = @("/Delete", "/TN", $TaskName, "/F")
& schtasks.exe $deleteArgs *> $null

$createArgs = @("/Create", "/TN", $TaskName, "/TR", $command, "/SC", "DAILY", "/ST", "03:00", "/RL", "LIMITED", "/F")
$createResult = & schtasks.exe $createArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create scheduled task. schtasks exited with $LASTEXITCODE. Message: $createResult"
}

$startupFolder = [Environment]::GetFolderPath('Startup')
if (-not (Test-Path $startupFolder)) {
    throw "Unable to locate Startup folder."
}

$launcherPath = Join-Path $startupFolder $StartupLauncherName
$launcherContent = "@echo off`r`ncall ""D:\DevOptimizer\portable\sync-bat-ps1.bat""`r`n"
Set-Content -Path $launcherPath -Value $launcherContent -Encoding ASCII

Write-Host "Scheduled task '$TaskName' registered and startup launcher created at $launcherPath."