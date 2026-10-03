<#
.SYNOPSIS
    DevOptimizer automation script: wsl-deep-clean.
.DESCRIPTION
    DevOptimizer automation script: wsl-deep-clean.
#>

# WSL Ubuntu Deep Clean
# Run this to thoroughly clean WSL Ubuntu environment

$Distro = "Ubuntu-26.04"
Write-Host "=== WSL Deep Clean: $Distro ===" -ForegroundColor Cyan

# Ensure distro is running
$running = wsl -l --running 2>$null
if ($running -notlike "*$Distro*") {
    Write-Host "Starting $Distro..." -ForegroundColor Yellow
    wsl -d "$Distro" -e true 2>$null | Out-Null
    Start-Sleep 2
}

# Show before
Write-Host "`n--- Disk Usage BEFORE ---" -ForegroundColor Green
wsl -d "$Distro" -e bash -c "df -h / | tail -1"
Write-Host "--- Top Space Consumers BEFORE ---" -ForegroundColor Green
wsl -d "$Distro" -e bash -c "du -sh /home/*/.cache /home/*/.npm /home/*/.cargo /home/*/go/pkg /var/cache/apt /var/log /tmp /var/tmp 2>/dev/null | sort -hr"

# Run cleanups
$CleanupCommands = @(
    @{ Cmd = "apt-get clean -y 2>/dev/null"; Desc = "apt clean" },
    @{ Cmd = "apt-get autoclean -y 2>/dev/null"; Desc = "apt autoclean" },
    @{ Cmd = "apt-get autoremove -y 2>/dev/null"; Desc = "apt autoremove" },
    @{ Cmd = "rm -rf /tmp/* /var/tmp/* 2>/dev/null"; Desc = "temp folders" },
    @{ Cmd = "journalctl --vacuum-time=3d 2>/dev/null"; Desc = "journald (3 days)" },
    @{ Cmd = "docker system prune -f --volumes 2>/dev/null"; Desc = "docker system prune" },
    
    @{ Cmd = "npm cache clean --force 2>/dev/null"; Desc = "npm cache" },
    @{ Cmd = "pip cache purge 2>/dev/null"; Desc = "pip cache" },
    @{ Cmd = "yarn cache clean 2>/dev/null"; Desc = "yarn cache" },
    @{ Cmd = "pnpm store prune 2>/dev/null"; Desc = "pnpm store" },
    @{ Cmd = "cargo clean 2>/dev/null"; Desc = "cargo cache" },
    @{ Cmd = "go clean -cache 2>/dev/null"; Desc = "go cache" },
    
    @{ Cmd = "rm -rf /home/*/.cache/pip /home/*/.cache/pipx 2>/dev/null"; Desc = "pip user cache" },
    @{ Cmd = "rm -rf /home/*/.cache/yarn /home/*/.cache/pnpm 2>/dev/null"; Desc = "yarn/pnpm user cache" },
    @{ Cmd = "rm -rf /home/*/.cache/pre-commit 2>/dev/null"; Desc = "pre-commit cache" },
    @{ Cmd = "rm -rf /home/*/.ccache 2>/dev/null"; Desc = "ccache" },
    @{ Cmd = "flatpak uninstall --unused -y 2>/dev/null"; Desc = "flatpak unused" },
    @{ Cmd = "snap list --all 2>/dev/null | awk '/disabled/{print \$1}' | xargs -r snap remove 2>/dev/null"; Desc = "snap disabled revisions" },
    @{ Cmd = "rm -rf /var/lib/apt/lists/* 2>/dev/null; apt-get update 2>/dev/null"; Desc = "apt lists refresh" },
    
    @{ Cmd = "rm -rf /home/*/.vscode-server/data/CachedData 2>/dev/null"; Desc = "VS Code CachedData" },
    @{ Cmd = "rm -rf /home/*/.vscode-server/data/User/workspaceStorage 2>/dev/null"; Desc = "VS Code workspaceStorage" },
    @{ Cmd = "rm -rf /home/*/.vscode-server/data/logs 2>/dev/null"; Desc = "VS Code logs" },
    @{ Cmd = "rm -rf /home/*/.vscode-server/extensionsCache 2>/dev/null"; Desc = "VS Code extensions cache" },
    @{ Cmd = "rm -rf /home/*/.vscode-server/bin/*/node_modules 2>/dev/null"; Desc = "VS Code server node_modules" },
    
    @{ Cmd = "rm -rf /home/*/.cache/typescript 2>/dev/null"; Desc = "TypeScript language server cache" },
    @{ Cmd = "rm -rf /home/*/.cache/pylint 2>/dev/null"; Desc = "pylint cache" },
    @{ Cmd = "rm -rf /home/*/.cache/mypy 2>/dev/null"; Desc = "mypy cache" },
    @{ Cmd = "rm -rf /home/*/.cache/ruff 2>/dev/null"; Desc = "ruff cache" },
    @{ Cmd = "rm -rf /home/*/.cache/jedi 2>/dev/null"; Desc = "jedi cache" },
    @{ Cmd = "rm -rf /home/*/.cache/gopls 2>/dev/null"; Desc = "gopls cache" },
    @{ Cmd = "rm -rf /home/*/.cache/rust-analyzer 2>/dev/null"; Desc = "rust-analyzer cache" },
    @{ Cmd = "rm -rf /home/*/.cache/clangd 2>/dev/null"; Desc = "clangd cache" },
    
    @{ Cmd = "find /home -name '.git' -type d -execdir git -C {} gc --aggressive --prune=now \\; 2>/dev/null"; Desc = "Git GC (aggressive)" }
)

Write-Host "`n--- Running Standard Cleanups ---" -ForegroundColor Yellow
foreach ($item in $CleanupCommands) {
    try {
        $result = wsl -d "$Distro" -e bash -c ($item.Cmd + "; echo 'DONE:" + $item.Desc + "'") 2>&1
        $lastLine = ($result.Trim().Split("`n") | Where-Object { $_ -ne '' } | Select-Object -Last 1)
        if ($lastLine -like "DONE:*") {
            Write-Host "  [OK] $($item.Desc)" -ForegroundColor Green
        } elseif ($lastLine) {
            Write-Host "  [INFO] $($item.Desc): $lastLine" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [WARN] $($item.Desc) failed" -ForegroundColor Yellow
    }
}

# Aggressive cleanups
Write-Host "`n--- Aggressive Cleanups (removes build artifacts) ---" -ForegroundColor Yellow
$AggressiveCommands = @(
    @{ Cmd = "find /home -name 'node_modules' -type d -prune -exec rm -rf {} + 2>/dev/null"; Desc = "node_modules (requires npm install)" },
    @{ Cmd = "find /home -name 'dist' -o -name 'build' -o -name '.next' -o -name '.nuxt' -o -name 'target' -o -name '__pycache__' -o -name '*.pyc' -o -name '.pytest_cache' -o -name '.coverage' -o -name '.tox' -o -name '.mypy_cache' -o -name '.ruff_cache' | xargs -r rm -rf 2>/dev/null"; Desc = "Build/test artifacts" },
    @{ Cmd = "find /home -name '*~' -o -name '*.swp' -o -name '*.swo' -o -name '.#*' | xargs -r rm -f 2>/dev/null"; Desc = "Editor temp files" }
)

foreach ($item in $AggressiveCommands) {
    try {
        $result = wsl -d "$Distro" -e bash -c ($item.Cmd + "; echo 'DONE:" + $item.Desc + "'") 2>&1
        $lastLine = ($result.Trim().Split("`n") | Where-Object { $_ -ne '' } | Select-Object -Last 1)
        if ($lastLine -like "DONE:*") {
            Write-Host "  [OK] $($item.Desc)" -ForegroundColor Green
        } else {
            Write-Host "  [INFO] $($item.Desc)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [WARN] $($item.Desc) failed" -ForegroundColor Yellow
    }
}

# Show after
Write-Host "`n--- Disk Usage AFTER ---" -ForegroundColor Green
wsl -d "$Distro" -e bash -c "df -h / | tail -1"
Write-Host "--- Top Space Consumers AFTER ---" -ForegroundColor Green
wsl -d "$Distro" -e bash -c "du -sh /home/*/.cache /home/*/.npm /home/*/.cargo /home/*/go/pkg /var/cache/apt /var/log /tmp /var/tmp 2>/dev/null | sort -hr"

Write-Host "`n--- WSL vhdx Compaction ---" -ForegroundColor Cyan
Write-Host "To compact the virtual disk:" -ForegroundColor Yellow
Write-Host "  1. wsl --shutdown"
Write-Host "  2. optimize-vhd -Path '\\wsl.localhost\$Distro\ext4.vhdx' -Mode Full" -ForegroundColor Yellow
Write-Host "     (Run in Administrator PowerShell)" -ForegroundColor Gray
Write-Host "`nWSL Deep Clean Complete!" -ForegroundColor Green