#requires -Version 5.1
<#
.SYNOPSIS
    Launches the Otter desktop app with CDP enabled for scripts\otter_notes.py.

.DESCRIPTION
    Otter.exe is an Electron app, but the user-level ELECTRON_RUN_AS_NODE=1
    env var makes every Electron binary boot as plain node and exit. This
    launcher strips that var for the child process and adds
    --remote-debugging-port=9333 so the notetaker toggle can drive the
    app's Record/Stop controls (system-audio capture).

    -Register creates scheduled task DevOptimizer-Otter-Desktop (AtLogOn)
    so the app is always available for the toggle. -Unregister removes it.
#>
param(
    [switch]$Register,
    [switch]$Unregister
)

$TaskName = 'DevOptimizer-Otter-Desktop'
$OtterExe = "$env:LOCALAPPDATA\Programs\@otter-aidesktop-app\Otter.exe"
$Launcher = Join-Path $PSScriptRoot 'Start-OtterDesktop.ps1'

if ($Unregister) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output "Removed scheduled task $TaskName"
    return
}

if ($Register) {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Launcher`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Description 'Launch Otter desktop with CDP :9333 for the notes toggle' -Force | Out-Null
    Write-Output "Registered scheduled task $TaskName"
    return
}

if (-not (Test-Path $OtterExe)) {
    Write-Error "Otter.exe not found at $OtterExe"
    exit 1
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $OtterExe
$psi.Arguments = '--remote-debugging-port=9333'
$psi.UseShellExecute = $false
$psi.EnvironmentVariables.Remove('ELECTRON_RUN_AS_NODE') | Out-Null
[void][System.Diagnostics.Process]::Start($psi)
