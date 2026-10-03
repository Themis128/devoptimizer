<#
.SYNOPSIS
    DevOptimizer automation script: sync-bat-ps1.
.DESCRIPTION
    DevOptimizer automation script: sync-bat-ps1.
#>

param(
    [string]$Root = "D:\DevOptimizer",
    [string]$OutputFolder = "D:\DevOptimizer\portable"
)

if (-not (Test-Path $Root)) {
    throw "DevOptimizer root '$Root' not found."
}

if (-not (Test-Path $OutputFolder)) {
    Write-Host "Creating portable launcher folder: $OutputFolder"
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

$ps1Files = Get-ChildItem -Path $Root -Filter *.ps1 -Recurse |
    Where-Object {
        $_.FullName -notlike "*\backups\*" -and
        $_.FullName -notlike "*\History\*" -and
        $_.FullName -notlike "*\Temp\*" -and
        $_.FullName -notlike "*\node_modules\*"
    }

$generated = 0

foreach ($ps1 in $ps1Files) {
    $relative = $ps1.FullName.Substring($Root.Length).TrimStart('\\')
    $targetBat = Join-Path $OutputFolder ($ps1.BaseName + ".bat")

    $batLines = @()
    $batLines += '@echo off'
    $batLines += 'setlocal EnableExtensions'
    $batLines += 'if defined DEVOPT_HOME goto rootReady'
    $batLines += ('set "DEVOPT_HOME={0}"' -f $Root)
    $batLines += ':rootReady'
    $batLines += ('set "TARGET_PS1=%DEVOPT_HOME%\{0}"' -f $relative)
    $batLines += 'if not exist "%TARGET_PS1%" ('
    $batLines += '    echo [ERROR] PowerShell script not found: %TARGET_PS1%'
    $batLines += '    exit /b 1'
    $batLines += ')'
    $batLines += 'where pwsh >nul 2>nul'
    $batLines += 'if %errorlevel% EQU 0 ('
    $batLines += '    set "PS_CMD=pwsh"'
    $batLines += ') else ('
    $batLines += '    set "PS_CMD=powershell"'
    $batLines += ')'
    $batLines += '%PS_CMD% -NoProfile -ExecutionPolicy Bypass -File "%TARGET_PS1%" %*'
    $batLines += 'endlocal'

    Set-Content -Path $targetBat -Value ($batLines -join "`r`n") -Encoding ASCII
    $generated++
}

Write-Host "Generated or refreshed $generated launcher(s) in $OutputFolder"
