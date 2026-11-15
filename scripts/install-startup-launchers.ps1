<#
.SYNOPSIS
    Installs the Startup-folder launchers so logon scripts run with NO
    console window. Moves the canonical .bat files out of the Startup
    folder into %USERPROFILE%\startup-hidden and replaces them with
    wscript .vbs launchers (Run ..., 0, False = hidden, detached).
.DESCRIPTION
    Startup-folder .bat files flash a console window at every logon;
    dmr-tunnel.bat's infinite ssh retry loop kept one open all session
    (2026-11-13). Canonical copies live in scripts\startup\ - this script
    syncs them to %USERPROFILE%\startup-hidden and (re)writes the .vbs
    launchers. Idempotent; safe to re-run after editing the .bat files.
    NOTE: start-chrome-debug.bat is intentionally NOT installed - it
    binds :9222 which Lenovo Vantage WebView2 permanently owns; the
    debug lane is :9229 via cdp-launch.bat + ChromeDebugBind task.
#>
#requires -Version 5.1
# CATEGORY: maintenance

$ErrorActionPreference = 'Stop'
$src      = 'D:\DevOptimizer\scripts\startup'
$hidden   = "$env:USERPROFILE\startup-hidden"
$startup  = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$bats     = 'cdp-launch','dmr-tunnel','win_agent','ntfy-bridge'

New-Item -ItemType Directory -Path $hidden -Force | Out-Null

foreach ($b in $bats) {
    Copy-Item "$src\$b.bat" "$hidden\$b.bat" -Force

    # Remove any raw .bat left in the Startup folder (would flash a window)
    $stale = "$startup\$b.bat"
    if (Test-Path $stale) { Remove-Item $stale -Force; Write-Host "removed stale $stale" }

    # Disable-marker copy in repo stays untouched; write hidden launcher
    $vbs = "$startup\$b-hidden.vbs"
    $line = 'CreateObject("Wscript.Shell").Run "cmd /c ""' + "$hidden\$b.bat" + '""", 0, False'
    Set-Content -Path $vbs -Value $line -Encoding ASCII
    Write-Host "installed $vbs -> $hidden\$b.bat (hidden)"
}

Write-Host "Done. Launchers take effect at next logon (or run the .vbs manually)."
