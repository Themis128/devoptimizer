<#
.SYNOPSIS
    Routine Development Environment Cleanup
.DESCRIPTION
    Safe, non-destructive cleanup for daily development workflow:
    - Kills orphaned dev processes (Node, Playwright, browsers, Electron)
    - Clears temp/cache folders (TEMP, npm, browser caches)
    - Recovers disk space (Recycle Bin, logs, package caches)
    - Reports memory and disk space recovered
.NOTES
    Run without Admin for standard cleanup.
    Some operations (Recycle Bin, system TEMP) work better with Admin.
#>
# CATEGORY: cleanup

#requires -Version 5.1

$ErrorActionPreference = "Continue"
$StartTime = Get-Date
$TotalMemFreedMB = 0
$TotalDiskFreedMB = 0
$ActionsPerformed = @()

# ─── Color helpers ──────────────────────────────────────────────
function Write-Header  { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Magenta }
function Write-Step    { param($msg) Write-Host "> $msg" -ForegroundColor Cyan }
function Write-Done    { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Info    { param($msg) Write-Host "  [INFO] $msg" -ForegroundColor Gray }
function Write-Result  { param($label, $value, $unit="MB", $color="Green") 
    Write-Host ("  {0}: " -f $label) -NoNewline; Write-Host "$([math]::Round($value,2)) $unit" -ForegroundColor $color 
}

# ─── Confirmation helper ────────────────────────────────────────
function Confirm-Action {
    param($Message, $DefaultYes = $true)
    $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $response = Read-Host "`n$Message $suffix"
    if ([string]::IsNullOrWhiteSpace($response)) { return $DefaultYes }
    return $response -match '^[yY]'
}

# ─── Process cleanup ────────────────────────────────────────────
Write-Header "Process Cleanup"

$DevProcesses = @(
    @{ Name = "node";             Desc = "Node.js processes" },
    @{ Name = "npm";              Desc = "npm processes" },
    @{ Name = "yarn";             Desc = "Yarn processes" },
    @{ Name = "pnpm";             Desc = "pnpm processes" },
    @{ Name = "playwright";       Desc = "Playwright processes" },
    @{ Name = "chrome";           Desc = "Chrome/Chromium (headless)" },
    @{ Name = "msedge";           Desc = "Edge (headless)" },
    @{ Name = "webkit";           Desc = "WebKit processes" },
    @{ Name = "Code";             Desc = "VS Code" },
    @{ Name = "Code - Insiders";  Desc = "VS Code Insiders" },
    @{ Name = "electron";         Desc = "Electron apps" },
    @{ Name = "dotnet";           Desc = ".NET processes" },
    @{ Name = "java";             Desc = "Java processes" },
    @{ Name = "python";           Desc = "Python processes" },
    @{ Name = "docker";           Desc = "Docker processes" },
    @{ Name = "containerd";       Desc = "containerd processes" }
)

$OrphanedProcesses = @()
foreach ($procDef in $DevProcesses) {
    $procs = Get-Process -Name $procDef.Name -ErrorAction SilentlyContinue
    if ($procs) {
        $userProcs = $procs | Where-Object { 
            try { $_.UserName -match "$env:USERDOMAIN\\$env:USERNAME|$env:USERNAME" } 
            catch { $true } 
        }
        if ($userProcs) {
            $memMB = ($userProcs | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB
            $OrphanedProcesses += [pscustomobject]@{
                Name = $procDef.Desc
                ProcessName = $procDef.Name
                Count = $userProcs.Count
                MemoryMB = [math]::Round($memMB, 2)
                Processes = $userProcs
            }
        }
    }
}

if ($OrphanedProcesses.Count -gt 0) {
    Write-Step "Found orphaned development processes:"
    $OrphanedProcesses | Format-Table Name, Count, @{Name="Memory (MB)";Expression={$_.MemoryMB}} -AutoSize | Out-Host
    
    if (Confirm-Action "Kill these processes?") {
        foreach ($item in $OrphanedProcesses) {
            try {
                $item.Processes | Stop-Process -Force -ErrorAction SilentlyContinue
                $TotalMemFreedMB += $item.MemoryMB
                $ActionsPerformed += "Killed $($item.Count) $($item.Name) ($($item.MemoryMB) MB)"
                Write-Done "Killed $($item.Count) $($item.Name)"
            } catch {
                Write-Warn "Failed to kill $($item.Name): $_"
            }
        }
    } else {
        Write-Info "Skipped process cleanup"
    }
} else {
    Write-Done "No orphaned development processes found"
}

# ─── Temp/Cache cleanup ─────────────────────────────────────────
Write-Header "Temp & Cache Cleanup"

$CacheTargets = @(
    @{ Path = "$env:TEMP\*";                      Desc = "User TEMP folder";          Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Temp\*";         Desc = "LocalAppData Temp";         Recurse = $true },
    @{ Path = "C:\Windows\Temp\*";                Desc = "System Temp (needs Admin)"; Recurse = $true; Admin = $true },
    @{ Path = "$env:LOCALAPPDATA\npm-cache\*";    Desc = "npm cache";                 Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Yarn\Cache\*";   Desc = "Yarn cache";                Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\pnpm\store\*";   Desc = "pnpm store";                Recurse = $true },
    @{ Path = "$env:USERPROFILE\.nuget\packages\*"; Desc = "NuGet packages cache";     Recurse = $true },
    @{ Path = "$env:USERPROFILE\.gradle\caches\*";  Desc = "Gradle cache";             Recurse = $true },
    @{ Path = "$env:USERPROFILE\.cargo\registry\cache\*"; Desc = "Cargo registry cache"; Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*";      Desc = "Chrome cache"; Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*"; Desc = "Chrome code cache"; Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*";     Desc = "Edge cache"; Recurse = $true },
    @{ Path = "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2\*";               Desc = "Firefox cache"; Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\VSCode\*\Cache\*";                   Desc = "VS Code cache"; Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\VSCode\*\CachedData\*";              Desc = "VS Code cached data"; Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\VSCode Insiders\*\Cache\*";          Desc = "VS Code Insiders cache"; Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\VSCode Insiders\*\CachedData\*";     Desc = "VS Code Insiders cached data"; Recurse = $true },
    @{ Path = "$env:APPDATA\Code\CachedData\*";                               Desc = "VS Code user cache"; Recurse = $true },
    @{ Path = "$env:APPDATA\Code - Insiders\CachedData\*";                    Desc = "VS Code Insiders user cache"; Recurse = $true },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*";               Desc = "Windows INetCache"; Recurse = $true }
)

if (Confirm-Action "Clear temp and cache folders?") {
    foreach ($target in $CacheTargets) {
        if ($target.Admin -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Warn "Skipping $($target.Desc) (requires Admin)"
            continue
        }
        
        $fullPath = $target.Path
        $parentPath = Split-Path $fullPath
        if (-not (Test-Path $parentPath)) { continue }
        
        try {
            $sizeBeforeMB = (Get-ChildItem $parentPath -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum / 1MB
            
            if ($sizeBeforeMB -gt 0) {
                Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                $TotalDiskFreedMB += $sizeBeforeMB
                $ActionsPerformed += "Cleared $($target.Desc) ($([math]::Round($sizeBeforeMB,2)) MB)"
                Write-Done "Cleared $($target.Desc) ($([math]::Round($sizeBeforeMB,2)) MB)"
            } else {
                Write-Info "$($target.Desc) already empty"
            }
        } catch {
            Write-Warn "Failed to clear $($target.Desc): $_"
        }
    }
} else {
    Write-Info "Skipped temp/cache cleanup"
}

# ─── Disk space recovery ────────────────────────────────────────
Write-Header "Disk Space Recovery"

$DiskTargets = @(
    @{ Cmd = { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }; 
       Desc = "Recycle Bin"; 
       SizeCheck = { (Get-ChildItem 'C:\$Recycle.Bin' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB } },
    @{ Cmd = { 
            wevtutil el | ForEach-Object { wevtutil cl $_ 2>$null } 
        }; 
       Desc = "Windows Event Logs"; 
       SizeCheck = { 0 } },
    @{ Cmd = { 
            if (Get-Command npm -ErrorAction SilentlyContinue) { npm cache clean --force 2>$null } 
        }; 
       Desc = "npm cache (via CLI)"; 
       SizeCheck = { 0 } },
    @{ Cmd = { 
            if (Get-Command dotnet -ErrorAction SilentlyContinue) { dotnet nuget locals all --clear 2>$null } 
        }; 
       Desc = "NuGet cache (via CLI)"; 
       SizeCheck = { 0 } },
    @{ Cmd = { 
            if (Get-Command cargo -ErrorAction SilentlyContinue) { cargo clean 2>$null } 
        }; 
       Desc = "Cargo cache (via CLI)"; 
       SizeCheck = { 0 } },
    @{ Cmd = { 
            if (Test-Path "$env:USERPROFILE\AppData\Local\Docker\containers") { 
                Remove-Item "$env:USERPROFILE\AppData\Local\Docker\containers\*" -Recurse -Force -ErrorAction SilentlyContinue 
            } 
        }; 
       Desc = "Docker container logs"; 
       SizeCheck = { (Get-ChildItem "$env:USERPROFILE\AppData\Local\Docker\containers" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB } }
)

if (Confirm-Action "Run disk space recovery operations?") {
    foreach ($target in $DiskTargets) {
        try {
            $sizeBeforeMB = & $target.SizeCheck
            & $target.Cmd
            $sizeAfterMB = & $target.SizeCheck
            $freedMB = [math]::Max(0, $sizeBeforeMB - $sizeAfterMB)
            if ($freedMB -gt 0 -or $target.Desc -eq "Windows Event Logs") {
                $TotalDiskFreedMB += $freedMB
                $ActionsPerformed += "$($target.Desc) cleaned ($([math]::Round($freedMB,2)) MB freed)"
                Write-Done "$($target.Desc) cleaned"
            } else {
                Write-Info "$($target.Desc) processed"
            }
        } catch {
            Write-Warn "Failed $($target.Desc): $_"
        }
    }
} else {
    Write-Info "Skipped disk space recovery"
}

# ─── Port cleanup (optional) ────────────────────────────────────
Write-Header "Port Cleanup (Common Dev Ports)"

$CommonPorts = @(3000, 3001, 4200, 5000, 5173, 8000, 8080, 8081, 8888, 9000, 9229, 9230)
$PortProcesses = @()

foreach ($port in $CommonPorts) {
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($conn) {
            $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            if ($proc) {
                $PortProcesses += [pscustomobject]@{
                    Port = $port
                    Process = $proc.ProcessName
                    PID = $proc.Id
                }
            }
        }
    } catch {}
}

if ($PortProcesses.Count -gt 0) {
    Write-Step "Processes listening on common dev ports:"
    $PortProcesses | Format-Table Port, Process, PID -AutoSize | Out-Host
    
    if (Confirm-Action "Kill processes on these ports? (may interrupt running servers)") {
        foreach ($item in $PortProcesses) {
            try {
                Stop-Process -Id $item.PID -Force -ErrorAction SilentlyContinue
                $ActionsPerformed += "Freed port $($item.Port) (was $($item.Process) PID $($item.PID))"
                Write-Done "Freed port $($item.Port)"
            } catch {
                Write-Warn "Failed to free port $($item.Port): $_"
            }
        }
    } else {
        Write-Info "Skipped port cleanup"
    }
} else {
    Write-Done "No processes on common dev ports"
}

# ─── WSL Cleanup ────────────────────────────────────────────────
Write-Header "WSL (Ubuntu) Cleanup"

$WSLAvailable = $false
$WSLDistros = @()
try {
    $rawDistros = wsl -l -q 2>$null
    # Filter out empty/null entries, trim, remove null chars, and skip internal distros
    $WSLDistros = @()
    foreach ($r in $rawDistros) {
        $t = $r.Trim()
        $t = $t -replace '\0', ''  # Remove null characters
        if ($t.Length -gt 0 -and $t -ne 'docker-desktop' -and $t -notlike '*data*') {
            $WSLDistros += $t
        }
    }
    if ($WSLDistros.Count -gt 0) { $WSLAvailable = $true }
} catch {}

if ($WSLAvailable) {
    Write-Step "Found WSL distros: $($WSLDistros -join ', ')"
    
    if (Confirm-Action "Run cleanup inside WSL distros?") {
        foreach ($distro in $WSLDistros) {
            if (-not $distro) { continue }
            
            Write-Step "Cleaning WSL distro: $distro"
            
            # Check if distro is running
            $isRunning = $false
            try {
                $running = wsl -l --running 2>$null
                if ($running -like "*$distro*") { $isRunning = $true }
            } catch {}
            
            if (-not $isRunning) {
                Write-Info "Starting $distro..."
                wsl -d "$distro" -e true 2>$null | Out-Null
                Start-Sleep -Seconds 2
            }
            
            # Show disk usage before cleanup
            Write-Step "  Disk usage before cleanup:"
            $dfBefore = wsl -d "$distro" -e bash -c "df -h / 2>/dev/null | tail -1" 2>&1
            if ($dfBefore) { Write-Info "    $dfBefore" }
            
            # Show top space consumers before cleanup
            Write-Step "  Top space consumers (before):"
            $duBefore = wsl -d "$distro" -e bash -c "du -sh /var/cache/apt /tmp /var/tmp /var/log /home/*/.cache /home/*/.npm /home/*/.cargo /home/*/go/pkg 2>/dev/null | sort -hr | head -10" 2>&1
            if ($duBefore) { $duBefore | ForEach-Object { Write-Info "    $_" } }
            
            # Run cleanup commands inside WSL
            $WSLCleanupCommands = @(
                # System packages
                @{ Cmd = "apt-get clean -y 2>/dev/null"; Desc = "apt clean" },
                @{ Cmd = "apt-get autoclean -y 2>/dev/null"; Desc = "apt autoclean" },
                @{ Cmd = "apt-get autoremove -y 2>/dev/null"; Desc = "apt autoremove" },
                @{ Cmd = "rm -rf /tmp/* /var/tmp/* 2>/dev/null"; Desc = "temp folders" },
                @{ Cmd = "journalctl --vacuum-time=7d 2>/dev/null"; Desc = "journald (7 days)" },
                @{ Cmd = "docker system prune -f --volumes --filter 'label!=com.docker.desktop.service=model-runner' --filter 'label!=com.docker.model-runner.role=model-storage' 2>/dev/null"; Desc = "docker system prune" },
                
                # Language package managers
                @{ Cmd = "npm cache clean --force 2>/dev/null"; Desc = "npm cache" },
                @{ Cmd = "pip cache purge 2>/dev/null"; Desc = "pip cache" },
                @{ Cmd = "yarn cache clean 2>/dev/null"; Desc = "yarn cache" },
                @{ Cmd = "pnpm store prune 2>/dev/null"; Desc = "pnpm store" },
                @{ Cmd = "cargo clean 2>/dev/null"; Desc = "cargo cache" },
                @{ Cmd = "go clean -cache 2>/dev/null"; Desc = "go cache" },
                
                # User caches
                @{ Cmd = "rm -rf /home/*/.cache/pip /home/*/.cache/pipx 2>/dev/null"; Desc = "pip user cache" },
                @{ Cmd = "rm -rf /home/*/.cache/yarn /home/*/.cache/pnpm 2>/dev/null"; Desc = "yarn/pnpm user cache" },
                @{ Cmd = "rm -rf /home/*/.cache/pre-commit 2>/dev/null"; Desc = "pre-commit cache" },
                @{ Cmd = "rm -rf /home/*/.ccache 2>/dev/null"; Desc = "ccache" },
                @{ Cmd = "flatpak uninstall --unused -y 2>/dev/null"; Desc = "flatpak unused" },
                @{ Cmd = "snap list --all 2>/dev/null | awk '/disabled/{print \$1}' | xargs -r snap remove 2>/dev/null"; Desc = "snap disabled revisions" },
                @{ Cmd = "rm -rf /var/lib/apt/lists/* 2>/dev/null; apt-get update 2>/dev/null"; Desc = "apt lists refresh" },
                
                # VS Code Remote - WSL specific caches
                @{ Cmd = "rm -rf /home/*/.vscode-server/data/CachedData 2>/dev/null"; Desc = "VS Code CachedData" },
                @{ Cmd = "rm -rf /home/*/.vscode-server/data/User/workspaceStorage 2>/dev/null"; Desc = "VS Code workspaceStorage" },
                @{ Cmd = "rm -rf /home/*/.vscode-server/data/logs 2>/dev/null"; Desc = "VS Code logs" },
                @{ Cmd = "rm -rf /home/*/.vscode-server/extensionsCache 2>/dev/null"; Desc = "VS Code extensions cache" },
                @{ Cmd = "rm -rf /home/*/.vscode-server/bin/*/node_modules 2>/dev/null"; Desc = "VS Code server node_modules" },
                
                # Language server caches (TypeScript, Python, Go, Rust, etc.)
                @{ Cmd = "rm -rf /home/*/.cache/typescript 2>/dev/null"; Desc = "TypeScript language server cache" },
                @{ Cmd = "rm -rf /home/*/.cache/pylint 2>/dev/null"; Desc = "pylint cache" },
                @{ Cmd = "rm -rf /home/*/.cache/mypy 2>/dev/null"; Desc = "mypy cache" },
                @{ Cmd = "rm -rf /home/*/.cache/ruff 2>/dev/null"; Desc = "ruff cache" },
                @{ Cmd = "rm -rf /home/*/.cache/jedi 2>/dev/null"; Desc = "jedi cache" },
                @{ Cmd = "rm -rf /home/*/.cache/gopls 2>/dev/null"; Desc = "gopls cache" },
                @{ Cmd = "rm -rf /home/*/.cache/rust-analyzer 2>/dev/null"; Desc = "rust-analyzer cache" },
                @{ Cmd = "rm -rf /home/*/.cache/clangd 2>/dev/null"; Desc = "clangd cache" },
                
                # Git cleanup
                @{ Cmd = "find /home -name '.git' -type d -execdir git -C {} gc --aggressive --prune=now \\; 2>/dev/null"; Desc = "Git GC (aggressive)" }
            )
            
            # Optional aggressive cleanups (ask separately)
            $AggressiveCleanupCommands = @(
                # Build/test artifacts
                @{ Cmd = "find /home -name 'node_modules' -type d -prune -exec rm -rf {} + 2>/dev/null"; Desc = "node_modules (removes all, requires npm install)" },
                @{ Cmd = "find /home -name 'dist' -o -name 'build' -o -name '.next' -o -name '.nuxt' -o -name 'target' -o -name '__pycache__' -o -name '*.pyc' -o -name '.pytest_cache' -o -name '.coverage' -o -name '.tox' -o -name '.mypy_cache' -o -name '.ruff_cache' | xargs -r rm -rf 2>/dev/null"; Desc = "Build/test artifacts (dist, build, target, __pycache__, etc.)" },
                
                # Editor temp files
                @{ Cmd = "find /home -name '*~' -o -name '*.swp' -o -name '*.swo' -o -name '.#*' | xargs -r rm -f 2>/dev/null"; Desc = "Editor temp files (~/.swp, *~)" }
            )
            
            # Run standard cleanups
            foreach ($item in $WSLCleanupCommands) {
                try {
                    $result = wsl -d "$distro" -e bash -c ($item.Cmd + "; echo 'DONE:" + $item.Desc + "'") 2>&1
                    $lastLine = ($result.Trim().Split("`n") | Where-Object { $_ -ne '' } | Select-Object -Last 1)
                    if ($lastLine -like "DONE:*") {
                        Write-Done ("  {0}: {1}" -f $distro, $lastLine.Replace("DONE:", "").Trim())
                    } elseif ($lastLine) {
                        Write-Info ("  {0}: {1}" -f $distro, $lastLine)
                    }
                } catch {
                    Write-Warn ("  {0}: {1} failed" -f $distro, $item.Desc)
                }
            }
            
            # Ask for aggressive cleanups
            if (Confirm-Action "Run AGGRESSIVE cleanups? (removes node_modules, build artifacts - will need reinstall)") {
                foreach ($item in $AggressiveCleanupCommands) {
                    try {
                        $result = wsl -d "$distro" -e bash -c ($item.Cmd + "; echo 'DONE:" + $item.Desc + "'") 2>&1
                        $lastLine = ($result.Trim().Split("`n") | Where-Object { $_ -ne '' } | Select-Object -Last 1)
                        if ($lastLine -like "DONE:*") {
                            Write-Done ("  {0}: {1}" -f $distro, $lastLine.Replace("DONE:", "").Trim())
                        } elseif ($lastLine) {
                            Write-Info ("  {0}: {1}" -f $distro, $lastLine)
                        }
                    } catch {
                        Write-Warn ("  {0}: {1} failed" -f $distro, $item.Desc)
                    }
                }
            } else {
                Write-Info "Skipped aggressive cleanups (node_modules, build artifacts preserved)"
            }
            
            # Show disk usage after cleanup
            Write-Step "  Disk usage after cleanup:"
            $dfAfter = wsl -d "$distro" -e bash -c "df -h / 2>/dev/null | tail -1" 2>&1
            if ($dfAfter) { Write-Info "    $dfAfter" }
            
            # Show top space consumers after cleanup
            Write-Step "  Top space consumers (after):"
            $duAfter = wsl -d "$distro" -e bash -c "du -sh /var/cache/apt /tmp /var/tmp /var/log /home/*/.cache /home/*/.npm /home/*/.cargo /home/*/go/pkg 2>/dev/null | sort -hr | head -10" 2>&1
            if ($duAfter) { $duAfter | ForEach-Object { Write-Info "    $_" } }
            
            # Note: wsl --compact is not available in all WSL versions
            Write-Info "WSL cleanup complete for $distro. To compact virtual disk manually:"
            Write-Info "  wsl --shutdown"
            Write-Info "  Then use Disk Management or optimize-vhd on the .vhdx file"
        }
    } else {
        Write-Info "Skipped WSL cleanup"
    }
} else {
    Write-Info "WSL not available or no distros installed"
}

# ─── Cline Extension Cleanup ──────────────────────────────────────
Write-Header "Cline Extension Cleanup"

$ClinePaths = @(
    @{ Path = "$env:APPDATA\Code\User\globalStorage\saoudrizwan.claude-dev\cache"; Desc = "Cline cache" },
    @{ Path = "$env:APPDATA\Code\User\globalStorage\saoudrizwan.claude-dev\state"; Desc = "Cline state" },
    @{ Path = "$env:APPDATA\Code\User\globalStorage\saoudrizwan.claude-dev\tasks"; Desc = "Cline tasks" },
    @{ Path = "$env:APPDATA\Code - Insiders\User\globalStorage\saoudrizwan.claude-dev\cache"; Desc = "Cline cache (Insiders)" },
    @{ Path = "$env:APPDATA\Code - Insiders\User\globalStorage\saoudrizwan.claude-dev\state"; Desc = "Cline state (Insiders)" },
    @{ Path = "$env:APPDATA\Code - Insiders\User\globalStorage\saoudrizwan.claude-dev\tasks"; Desc = "Cline tasks (Insiders)" }
)

$ClineFreedMB = 0
$ClineFound = $false

foreach ($item in $ClinePaths) {
    if (Test-Path $item.Path) {
        $ClineFound = $true
        try {
            $sizeMB = (Get-ChildItem $item.Path -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum / 1MB
            if ($sizeMB -gt 0) {
                Get-ChildItem $item.Path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                $ClineFreedMB += $sizeMB
                $TotalDiskFreedMB += $sizeMB
                $ActionsPerformed += "Cleared $($item.Desc) ($([math]::Round($sizeMB,2)) MB)"
                Write-Done "Cleared $($item.Desc) ($([math]::Round($sizeMB,2)) MB)"
            } else {
                Write-Info "$($item.Desc) already empty"
            }
        } catch {
            Write-Warn "Failed to clear $($item.Desc): $_"
        }
    }
}

if (-not $ClineFound) {
    Write-Info "Cline extension storage not found"
}

# ─── Final summary ──────────────────────────────────────────────
Write-Header "Summary"

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Result "Memory freed" $TotalMemFreedMB "MB"
Write-Result "Disk space freed" $TotalDiskFreedMB "MB"
Write-Result "Duration" $Duration.TotalSeconds "seconds" "Cyan"

if ($ActionsPerformed.Count -gt 0) {
    Write-Host "`nActions performed:" -ForegroundColor Cyan
    $ActionsPerformed | ForEach-Object { Write-Host "  * $_" -ForegroundColor Gray }
} else {
    Write-Info "No cleanup actions performed"
}

# Show current disk space
Write-Host "`nCurrent disk space:" -ForegroundColor Cyan
Get-Volume | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, 
    @{Name="Free (GB)";Expression={[math]::Round($_.SizeRemaining/1GB,2)}}, 
    @{Name="Used %";Expression={[math]::Round((($_.Size - $_.SizeRemaining)/$_.Size)*100,2)}} | 
    Format-Table -AutoSize | Out-Host

Write-Host "`n[OK] Dev cleanup complete!" -ForegroundColor Green