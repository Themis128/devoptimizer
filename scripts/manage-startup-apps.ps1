<#
.SYNOPSIS
    Manage startup applications - disable non-mandatory, keep essentials.
.DESCRIPTION
    Disables optional startup entries in HKCU/HKLM Run keys and Startup folders.
    Keeps: Docker Desktop, Windows SecurityHealth, Tailscale.
    Run elevated for HKLM changes.
#>
$ErrorActionPreference = 'Continue'

function Write-Warn($msg) { Write-Host "WARN: $msg" -ForegroundColor Yellow }

# --- Mandatory apps to KEEP (case-insensitive partial match) ---
$MandatoryApps = @(
    'Docker Desktop',       # Container runtime
    'SecurityHealth',       # Windows Security Center (HKLM)
    'Tailscale'             # VPN (StartUp folder)
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
    'Nextcloud',
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

Write-Host "`n=== Done. Reboot to apply. ===" -ForegroundColor Cyan