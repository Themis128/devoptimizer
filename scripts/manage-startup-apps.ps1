<#
.SYNOPSIS
    Manage startup applications - disable non-mandatory, keep essentials.
.DESCRIPTION
    Disables optional startup entries in HKCU/HKLM Run keys, Startup folders,
    and packaged-app StartupTasks (SystemAppData State=1).
    Keeps: Docker Desktop, Windows SecurityHealth, Tailscale, Nextcloud,
    Telegram, ntfy, and the hidden .vbs automation helpers.
    Run elevated for HKLM changes.
#>
$ErrorActionPreference = 'Continue'

function Write-Warn($msg) { Write-Host "WARN: $msg" -ForegroundColor Yellow }

# --- Mandatory apps to KEEP (case-insensitive partial match) ---
$MandatoryApps = @(
    'Docker Desktop',       # Container runtime
    'SecurityHealth',       # Windows Security Center (HKLM)
    'Tailscale',            # VPN (StartUp folder)
    'Nextcloud',            # Files sync client (user request 2026-11-13)
    'Telegram',             # Store app .lnk in Startup folder
    'ntfy',                 # ntfy.cloudless.gr app-window .lnk
    'cdp-launch',           # hidden automation helpers
    'dmr-tunnel',
    'galaxy_s22_dashboard',
    'win_agent'
)

# --- Apps to explicitly DISABLE (optional/noisy) ---
$DisableApps = @(
    'OneDrive',
    'Microsoft.Lists',
    'Teams',
    'Adobe Acrobat Synchronizer',
    'Adobe Acrobat',
    'EPSDNMON',
    'EPLTarget',
    'WhatsApp',             # user request 2026-11-13 (incl. packaged StartupTask)
    'MicrosoftEdgeAutoLaunch',
    'RtkAudUService',
    'EPPCCMON',
    'DataCollectionAgentController',
    'Logitech Download Assistant',
    'Logi Download Assistant',
    'LogiFetch',
    'Devin-Lower-Priority'
)

function Is-Mandatory($name) {
    foreach ($m in $MandatoryApps) {
        if ($name -like "*$m*") { return $true }
    }
    return $false
}

function Disable-RunKey($root, $keyName) {
    try {
        $item = Get-ItemProperty -Path $root -ErrorAction SilentlyContinue
        if (-not $item) { return }
        $props = $item.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
        foreach ($prop in $props) {
            $name = $prop.Name
            $cmd = $prop.Value
            $shouldDisable = $false
            foreach ($d in $DisableApps) {
                if ($name -like "*$d*" -or $cmd -like "*$d*") { $shouldDisable = $true; break }
            }
            if (Is-Mandatory $name -or Is-Mandatory $cmd) {
                Write-Host "  KEEP: [$name] $cmd" -ForegroundColor Green
            } elseif ($shouldDisable) {
                Write-Host "  DISABLE: [$name] $cmd" -ForegroundColor Yellow
                Remove-ItemProperty -Path $root -Name $name -ErrorAction SilentlyContinue
            } else {
                Write-Host "  UNKNOWN (keeping): [$name] $cmd" -ForegroundColor Cyan
            }
        }
    } catch {
        Write-Warn "Failed $root"
    }
}

function Disable-StartupFolder($path) {
    try {
        $items = Get-ChildItem $path -ErrorAction SilentlyContinue
        foreach ($lnk in $items) {
            if (Is-Mandatory $lnk.Name) {
                Write-Host "  KEEP (StartUp): $($lnk.Name)" -ForegroundColor Green
            } else {
                Write-Host "  DISABLE (StartUp): $($lnk.Name)" -ForegroundColor Yellow
                $lnk | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Warn "Failed $path"
    }
}

Write-Host "=== Startup App Management ===" -ForegroundColor Cyan
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Elevated: $isAdmin" -ForegroundColor $(if ($isAdmin) { 'Green' } else { 'Yellow' })

# HKCU (user)
Write-Host "`n--- HKCU\Run ---"
Disable-RunKey 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'HKCU'

# HKLM (machine) - needs admin
Write-Host "`n--- HKLM\Run ---"
Disable-RunKey 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' 'HKLM'

# Startup folders
Write-Host "`n--- ProgramData StartUp ---"
Disable-StartupFolder 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp'

Write-Host "`n--- User StartUp ---"
Disable-StartupFolder "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"

# Packaged-app StartupTasks (Store apps like WhatsApp register here, not in
# Run keys). State: 2=Enabled, 1=DisabledByUser — same as Task Manager.
function Disable-StartupTasks {
    $sysAppData = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
    Get-ChildItem $sysAppData -ErrorAction SilentlyContinue | ForEach-Object {
        $pkg = $_.PSChildName
        $match = $false
        foreach ($d in $DisableApps) {
            if ($pkg -like "*$d*") { $match = $true; break }
        }
        if (-not $match) { return }
        Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($null -ne $props.State -and $props.State -eq 2) {
                Set-ItemProperty -Path $_.PSPath -Name State -Value 1 -Type DWord
                Write-Host "  DISABLE (StartupTask): $pkg $($_.PSChildName)" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "`n--- Packaged StartupTasks ---"
Disable-StartupTasks

Write-Host "`n=== Done. Reboot to apply. ===" -ForegroundColor Cyan