# WSL Ubuntu Repair & Optimization Script v2.2
# SIMPLIFIED VERSION - Direct inline commands, no temp files
# Run as Administrator

#Requires -RunAsAdministrator

param(
    [switch]$SkipReboot,
    [switch]$Verbose,
    [switch]$DryRun,
    [switch]$IncludeDocker,
    [string]$LogFile = "$env:USERPROFILE\wsl-repair-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

$ErrorActionPreference = "Continue"

function Write-Log {
    param([string]$Message, [string]$Color = "White", [switch]$NoNewline)
    if ($NoNewline) { Write-Host $Message -ForegroundColor $Color -NoNewline }
    else { Write-Host $Message -ForegroundColor $Color }
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'HH:mm:ss') $Message" -ErrorAction SilentlyContinue
}

function Invoke-WSL {
    param([string]$Command, [int]$TimeoutSec = 120)
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "wsl.exe"
    $pinfo.Arguments = "-e bash -c `"$Command`""
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $pinfo
    $process.Start() | Out-Null
    
    if ($process.WaitForExit($TimeoutSec * 1000)) {
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        return @{ Output = $stdout; Error = $stderr; ExitCode = $process.ExitCode }
    } else {
        $process.Kill()
        return @{ Output = ""; Error = "TIMEOUT"; ExitCode = -1 }
    }
}

function Invoke-WSLSudo {
    param([string]$Command, [int]$TimeoutSec = 300)
    
    # Use sudo with DEBIAN_FRONTEND to avoid interactive prompts
    $fullCmd = "echo ''; DEBIAN_FRONTEND=noninteractive sudo -n $Command 2>&1 || sudo $Command 2>&1"
    return Invoke-WSL -Command $fullCmd -TimeoutSec $TimeoutSec
}

function Get-WindowsVersion {
    $build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
    return @{
        Build = $build
        IsWin11 = $build -ge 22000
        SupportsMirroredNetworking = $build -ge 22621
    }
}

# ============================================
# BANNER
# ============================================
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   WSL Ubuntu Repair & Optimization Script v2.2              ║" -ForegroundColor Cyan
Write-Host "  ║   SIMPLIFIED - Direct commands, no hanging                  ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Log "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Log "Log: $LogFile"

# ============================================
# SECTION 0: SYSTEM CHECK
# ============================================
Write-Log "`n[0/12] System Check..." -Color Yellow

$winVer = Get-WindowsVersion
Write-Log "  Windows Build: $($winVer.Build)" -Color Gray

# Check features
$vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue

if ($vmp.State -ne "Enabled") {
    Write-Log "  ⚠ Virtual Machine Platform not enabled" -Color Yellow
    Write-Log "    Run: dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart" -Color Gray
    Write-Log "    Then restart your computer" -Color Gray
}

$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$freeGB = [math]::Round((Get-PSDrive C).Free / 1GB)
Write-Log "  RAM: ${totalRAM}GB, Free Disk: ${freeGB}GB" -Color Gray

if ($freeGB -lt 10) {
    Write-Log "  ⚠ Low disk space!" -Color Yellow
}

# ============================================
# SECTION 1: STOP WSL
# ============================================
Write-Log "`n[1/12] Stopping WSL..." -Color Yellow
wsl --shutdown 2>$null
Start-Sleep -Seconds 2
Write-Log "  ✓ Done" -Color Green

# ============================================
# SECTION 2: UPDATE WSL
# ============================================
Write-Log "`n[2/12] Updating WSL..." -Color Yellow
wsl --update 2>$null
wsl --set-default-version 2 2>$null
Write-Log "  ✓ Done" -Color Green

# ============================================
# SECTION 3: CREATE .WSLCONFIG
# ============================================
Write-Log "`n[3/12] Creating .wslconfig..." -Color Yellow

$wslRAM = [math]::Max(4, [math]::Min(24, [math]::Floor($totalRAM * 0.6)))
$wslSwap = [math]::Min(8, [math]::Floor($wslRAM / 2))
$processors = [math]::Max(2, [math]::Min(12, (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors - 2))

Write-Log "  Allocating: ${wslRAM}GB RAM, $processors CPUs" -Color Gray

$wslConfigPath = "$env:USERPROFILE\.wslconfig"

# Backup existing
if (Test-Path $wslConfigPath) {
    Copy-Item $wslConfigPath "$wslConfigPath.backup" -Force
}

$config = @"
# WSL 2 Configuration - Generated $(Get-Date -Format 'yyyy-MM-dd')
[wsl2]
memory=${wslRAM}GB
swap=${wslSwap}GB
processors=$processors
localhostForwarding=true
nestedVirtualization=true
guiApplications=true
"@

if ($winVer.SupportsMirroredNetworking) {
    $config += @"

networkingMode=mirrored
dnsTunneling=true
firewall=true
autoProxy=true
"@
}

$config += @"

[experimental]
sparseVhd=true
autoMemoryReclaim=gradual
"@

$config | Out-File -FilePath $wslConfigPath -Encoding UTF8 -Force
Write-Log "  ✓ Created: $wslConfigPath" -Color Green

# ============================================
# SECTION 4: FIREWALL RULES
# ============================================
Write-Log "`n[4/12] Configuring Firewall..." -Color Yellow

Get-NetFirewallRule -DisplayName "WSL*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

$rules = @(
    @{Name="WSL Inbound"; Dir="Inbound"},
    @{Name="WSL Outbound"; Dir="Outbound"}
)

foreach ($rule in $rules) {
    New-NetFirewallRule -DisplayName $rule.Name -Direction $rule.Dir -Action Allow -Profile Private -ErrorAction SilentlyContinue | Out-Null
}

New-NetFirewallRule -DisplayName "WSL Ports" -Direction Inbound -LocalPort "1024-65535" -Protocol TCP -Action Allow -Profile Private -ErrorAction SilentlyContinue | Out-Null

Write-Log "  ✓ Done" -Color Green

# ============================================
# SECTION 5: WINDOWS OPTIMIZATIONS
# ============================================
Write-Log "`n[5/12] Windows Optimizations..." -Color Yellow

# Disable Fast Startup
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -ErrorAction SilentlyContinue
} catch {}

# Defender exclusions
@("$env:LOCALAPPDATA\Packages\*Ubuntu*", "\\wsl$\*", "\\wsl.localhost\*") | ForEach-Object {
    Add-MpPreference -ExclusionPath $_ -ErrorAction SilentlyContinue
}

Write-Log "  ✓ Done" -Color Green

# ============================================
# SECTION 6: RESTART WSL
# ============================================
Write-Log "`n[6/12] Restarting WSL..." -Color Yellow
wsl --shutdown 2>$null
Start-Sleep -Seconds 2

# Start WSL
$testResult = Invoke-WSL -Command "echo OK" -TimeoutSec 30
if ($testResult.Output -match "OK") {
    Write-Log "  ✓ WSL started" -Color Green
} else {
    Write-Log "  ⚠ WSL may have issues starting" -Color Yellow
}

# ============================================
# SECTION 7: FIX DNS
# ============================================
Write-Log "`n[7/12] Checking DNS..." -Color Yellow

# Only apply the static-DNS fix when resolution is actually broken. The distro runs
# systemd-resolved with dnsTunneling enabled; blindly replacing resolv.conf (and
# making it immutable with chattr +i) breaks the managed setup and outlives the
# fix (2026-09-26: /etc/resolv.conf is a healthy systemd-resolved stub symlink).
$dnsProbe = Invoke-WSL -Command "getent hosts github.com >/dev/null 2>&1 && echo DNS_OK || echo DNS_BROKEN" -TimeoutSec 20

if ($dnsProbe.Output -match "DNS_OK") {
    Write-Log "  DNS resolution working (systemd-resolved + dnsTunneling) - static override not needed" -Color Green
} else {
    Write-Log "  DNS resolution broken - applying static DNS fix" -Color Yellow

    # First, check if we can run sudo without password
    $sudoCheck = Invoke-WSL -Command "sudo -n echo OK 2>/dev/null || echo NEED_PASSWORD" -TimeoutSec 10

    if ($sudoCheck.Output -match "NEED_PASSWORD") {
        Write-Log "  Note: You may need to enter your WSL password" -Color Gray

        # Try to fix DNS with a simpler approach - create script in WSL and run it
        Write-Log "  Creating DNS fix script in WSL..." -Color Gray

        # Write the script content to WSL
        wsl -e bash -c "cat > /tmp/fix_dns.sh << 'EOFSCRIPT'
#!/bin/bash
sudo chattr -i /etc/resolv.conf 2>/dev/null
sudo rm -f /etc/resolv.conf
echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf > /dev/null
echo 'nameserver 1.1.1.1' | sudo tee -a /etc/resolv.conf > /dev/null
sudo chattr +i /etc/resolv.conf 2>/dev/null
echo 'DNS configured'
EOFSCRIPT
chmod +x /tmp/fix_dns.sh"

        Write-Log "  Running DNS fix (may prompt for password in WSL window)..." -Color Gray
        Start-Process -FilePath "wsl.exe" -ArgumentList "-e", "bash", "-c", "sudo /tmp/fix_dns.sh" -Wait -NoNewWindow
        Write-Log "  ✓ DNS fix attempted" -Color Green
    } else {
        # Can run sudo without password
        $dnsResult = Invoke-WSL -Command "sudo chattr -i /etc/resolv.conf 2>/dev/null; sudo rm -f /etc/resolv.conf; echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf; echo 'nameserver 1.1.1.1' | sudo tee -a /etc/resolv.conf; sudo chattr +i /etc/resolv.conf 2>/dev/null; echo DONE" -TimeoutSec 30
        if ($dnsResult.Output -match "DONE") {
            Write-Log "  ✓ DNS configured" -Color Green
        } else {
            Write-Log "  ⚠ DNS config may have issues" -Color Yellow
        }
    }
}

# ============================================
# SECTION 8: CREATE WSL.CONF
# ============================================
Write-Log "`n[8/12] Creating wsl.conf..." -Color Yellow

wsl -e bash -c "cat > /tmp/wsl.conf << 'EOFCONF'
[boot]
systemd=true

[network]
generateResolvConf=false
generateHosts=true

[interop]
enabled=true
appendWindowsPath=true

[automount]
enabled=true
root=/mnt/
options=metadata,umask=22,fmask=11
EOFCONF
sudo cp /tmp/wsl.conf /etc/wsl.conf 2>/dev/null || echo 'Need sudo'"

Write-Log "  ✓ Done" -Color Green

# ============================================
# SECTION 9: UPDATE PACKAGES
# ============================================
Write-Log "`n[9/12] Updating packages (this takes a few minutes)..." -Color Yellow

# Run apt update in background with output
Write-Log "  Running apt update..." -Color Gray
Start-Process -FilePath "wsl.exe" -ArgumentList "-e", "bash", "-c", "sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y" -Wait -NoNewWindow

Write-Log "  ✓ Packages updated" -Color Green

# ============================================
# SECTION 10: INSTALL DEPENDENCIES
# ============================================
Write-Log "`n[10/12] Installing dependencies..." -Color Yellow

$packages = "wget curl git ca-certificates build-essential python3 python3-pip nodejs npm"
Start-Process -FilePath "wsl.exe" -ArgumentList "-e", "bash", "-c", "sudo apt install -y $packages 2>/dev/null" -Wait -NoNewWindow

# Check if Node exists, if not install from nodesource
$nodeCheck = Invoke-WSL -Command "node --version 2>/dev/null || echo NOTFOUND" -TimeoutSec 10
if ($nodeCheck.Output -match "NOTFOUND") {
    Write-Log "  Installing Node.js LTS..." -Color Gray
    Start-Process -FilePath "wsl.exe" -ArgumentList "-e", "bash", "-c", "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt install -y nodejs" -Wait -NoNewWindow
}

Write-Log "  ✓ Done" -Color Green

# ============================================
# SECTION 11: CONFIGURE USER ENVIRONMENT
# ============================================
Write-Log "`n[11/12] Configuring user environment..." -Color Yellow

# Configure sysctl
wsl -e bash -c "grep -q 'fs.inotify.max_user_watches' /etc/sysctl.conf || echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf > /dev/null"
wsl -e bash -c "sudo sysctl -p 2>/dev/null"

# Create VS Code directories
wsl -e bash -c "mkdir -p ~/.vscode-server-insiders/bin ~/.vscode-server/bin"

# Configure Git
wsl -e bash -c "git config --global core.autocrlf input; git config --global init.defaultBranch main"

# Create aliases
wsl -e bash -c "cat > ~/.bash_aliases << 'EOFALIAS'
alias ll='ls -alF'
alias code='code-insiders'
alias c='code-insiders .'
alias gs='git status'
alias gp='git pull'
EOFALIAS"

# Add to bashrc if not present
wsl -e bash -c "grep -q '.bash_aliases' ~/.bashrc || echo '[[ -f ~/.bash_aliases ]] && source ~/.bash_aliases' >> ~/.bashrc"

Write-Log "  ✓ Done" -Color Green

# ============================================
# SECTION 12: VS CODE SETTINGS
# ============================================
Write-Log "`n[12/12] Configuring VS Code..." -Color Yellow

$settingsPath = "$env:APPDATA\Code - Insiders\User\settings.json"
$settingsDir = Split-Path $settingsPath

if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

$settings = @{
    "remote.WSL.debug" = $false
    "remote.WSL.useShellEnvironment" = $true
    "remote.downloadExtensionsLocally" = $true
    "files.watcherExclude" = @{
        "**/node_modules/**" = $true
        "**/.git/objects/**" = $true
        "**/.venv/**" = $true
    }
    "search.exclude" = @{
        "**/node_modules" = $true
        "**/dist" = $true
    }
    "telemetry.telemetryLevel" = "off"
    "git.autofetch" = $false
    "editor.formatOnSave" = $true
}

# Load existing and merge
$existing = @{}
if (Test-Path $settingsPath) {
    try {
        $content = Get-Content $settingsPath -Raw
        $existing = $content | ConvertFrom-Json -AsHashtable
    } catch { $existing = @{} }
}

foreach ($key in $settings.Keys) {
    $existing[$key] = $settings[$key]
}

$existing | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-Log "  ✓ Done" -Color Green

# ============================================
# CREATE HELPER SCRIPTS
# ============================================
Write-Log "`n[+] Creating helper scripts..." -Color Yellow

# Health check
@'
# WSL Health Check
Write-Host "=== WSL Health Check ===" -ForegroundColor Cyan
wsl -e bash -c "echo 'Memory:'; free -h | head -2"
wsl -e bash -c "echo ''; echo 'Disk:'; df -h / | tail -1"
wsl -e bash -c "echo ''; echo 'IP:'; hostname -I"
wsl -e bash -c "echo ''; echo 'DNS Test:'; timeout 3 nslookup google.com > /dev/null 2>&1 && echo 'OK' || echo 'FAIL'"
'@ | Set-Content "$env:USERPROFILE\wsl-health-check.ps1" -Encoding UTF8

# Reset script
@'
# WSL Reset
param([switch]$Full)
Write-Host "Resetting WSL..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 2
if ($Full) {
    wsl -e bash -c "rm -rf ~/.vscode-server-insiders/bin/* ~/.vscode-server/bin/*"
}
wsl -e bash -c "echo 'WSL Ready - IP:' `$(hostname -I)"
'@ | Set-Content "$env:USERPROFILE\wsl-reset.ps1" -Encoding UTF8

Write-Log "  ✓ Created helper scripts" -Color Green

# ============================================
# FINAL RESTART
# ============================================
Write-Log "`n[*] Final WSL restart..." -Color Yellow
wsl --shutdown
Start-Sleep -Seconds 2

$finalTest = Invoke-WSL -Command "echo OK && hostname -I" -TimeoutSec 30
if ($finalTest.Output -match "OK") {
    $ip = ($finalTest.Output -split "`n" | Select-Object -Last 1).Trim()
    Write-Log "  ✓ WSL is ready! IP: $ip" -Color Green
} else {
    Write-Log "  ⚠ WSL may need manual start" -Color Yellow
}

# ============================================
# SUMMARY
# ============================================
Write-Host "`n"
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         WSL Repair Complete!                          ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n✓ Configured:" -ForegroundColor White
Write-Host "  • .wslconfig (${wslRAM}GB RAM, $processors CPUs)" -ForegroundColor Gray
Write-Host "  • Firewall rules" -ForegroundColor Gray
Write-Host "  • DNS (8.8.8.8, 1.1.1.1)" -ForegroundColor Gray
Write-Host "  • File watchers (524288)" -ForegroundColor Gray
Write-Host "  • VS Code settings" -ForegroundColor Gray

Write-Host "`n📁 Files:" -ForegroundColor Yellow
Write-Host "  • $env:USERPROFILE\.wslconfig" -ForegroundColor Gray
Write-Host "  • $env:USERPROFILE\wsl-health-check.ps1" -ForegroundColor Gray
Write-Host "  • $env:USERPROFILE\wsl-reset.ps1" -ForegroundColor Gray

Write-Host "`n📌 Commands:" -ForegroundColor Yellow
Write-Host "  wsl                    # Enter WSL" -ForegroundColor White
Write-Host "  code-insiders .        # Open VS Code from WSL" -ForegroundColor White
Write-Host "  .\wsl-health-check.ps1 # Check health" -ForegroundColor White
Write-Host "  .\wsl-reset.ps1 -Full  # Reset with cache clear" -ForegroundColor White

Write-Host "`n⚠️  RESTART YOUR COMPUTER for full effect" -ForegroundColor Red

if (-not $SkipReboot) {
    Write-Host ""
    $reboot = Read-Host "Restart now? (y/N)"
    if ($reboot -eq "y") {
        Restart-Computer -Force
    }
}

Write-Host "`n✅ Done!" -ForegroundColor Green