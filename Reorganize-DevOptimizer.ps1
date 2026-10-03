#Requires -Version 5.1
<#
.SYNOPSIS
    DevOptimizer Folder Reorganization Script
.DESCRIPTION
    Archives stale reports, consolidates duplicate scripts, creates clean structure.
    Non-destructive: moves files to organized subfolders, never deletes.
.PARAMETER DryRun
    Show what would be moved without actually moving
.PARAMETER Confirm
    Skip confirmation prompts
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$AutoConfirm
)

$root = "D:\DevOptimizer"
$moved = 0
$logFile = "$root\logs\reorganize-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Status {
    param([string]$Msg, [string]$Color = 'White')
    Write-Host $Msg -ForegroundColor $Color
    Add-Content -Path $logFile -Value $Msg -ErrorAction SilentlyContinue
}

function Move-Safely {
    param([string]$Source, [string]$DestDir)
    if (!(Test-Path $Source)) { return $false }
    if (!(Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force | Out-Null }
    $destFile = Join-Path $DestDir (Split-Path $Source -Leaf)
    if (Test-Path $destFile) {
        $destFile = Join-Path $DestDir ("$(Get-Date -Format 'yyyyMMdd')_$(Split-Path $Source -Leaf)")
    }
    if (!$DryRun) {
        Move-Item -Path $Source -Destination $destFile -Force -ErrorAction SilentlyContinue
    }
    $script:moved++
    return $true
}

Clear-Host
Write-Status "╔════════════════════════════════════════════════════════════════╗" Cyan
Write-Status "║       DevOptimizer Folder Reorganization                     ║" Cyan
Write-Status "╚════════════════════════════════════════════════════════════════╝`n" Cyan
Write-Status "Mode: $(if($DryRun){'DRY RUN'}else{'LIVE'})`n"

$rootFiles = Get-ChildItem $root -File
Write-Status "Current root: $($rootFiles.Count) files`n" Yellow

# ═══════════════════════════════════════════════════════════════
# 1. Archive stale reports & validations
# ═══════════════════════════════════════════════════════════════
Write-Status "━━━ 1/5: ARCHIVE STALE REPORTS ━━━" Yellow
$archiveDir = "$root\archive\reports-$(Get-Date -Format 'yyyyMM')"

$reportPatterns = @(
    'bat-validation-report-*.json',
    'script-validation-report-*.txt',
    'fix-report-*.json',
    'TEST-RESULTS-*.txt',
    'validation-*.txt',
    'validation-*.html',
    'event-log-report-*.html',
    '*-report.json',
    'all-scripts-*.txt',
    'menu-test-*.txt',
    'test-results-summary.txt',
    'modernization-summary.txt',
    'modernized-scripts-test-log.txt',
    'duplicate-removal-log.txt',
    'cleanup-log.txt',
    'verification-results.txt',
    'high-priority-invalid.txt',
    'invalid-scripts-*.txt',
    'script-update-log-*.txt',
    'Memory-Analysis-*.md'
)

foreach ($pattern in $reportPatterns) {
    $files = Get-ChildItem "$root\$pattern" -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Write-Status "  → $($f.Name) → archive/reports/" Gray
        Move-Safely -Source $f.FullName -DestDir $archiveDir
    }
}

# ═══════════════════════════════════════════════════════════════
# 2. Archive superseded documentation
# ═══════════════════════════════════════════════════════════════
Write-Status "`n━━━ 2/5: ARCHIVE OLD DOCS ━━━" Yellow
$docsArchive = "$root\archive\docs-$(Get-Date -Format 'yyyyMM')"

$oldDocs = @(
    'IMPROVEMENTS-v2.0.md',
    'WHATS-NEW.md',
    'FINAL-MODERNIZATION-REPORT.txt',
    'FINAL-SECURITY-SCAN-REPORT.md',
    'PHASE2-FINAL-SECURITY-REPORT.md',
    'SECURITY-FIXES-SUMMARY.md',
    'SECURITY-SCAN-COMPLETION-SUMMARY.md',
    'SECURITY-VERIFICATION-REPORT.md',
    'security-scan-issues.md',
    'security-scan-plan.md',
    'SCRIPT-FIXING-PROGRESS.md',
    'SCRIPT-VALIDATION-SUMMARY.md',
    'BATCH-PARENTHESES-FIXER.md',
    'MANUAL-FIX-INSTRUCTIONS.txt',
    'INSTALLATION-COMPLETE.md',
    'INSTALLATION-TROUBLESHOOTING.md',
    'INSTALL-NOW.md',
    'OPTIMIZATION-SUMMARY.md',
    'VISUAL-COMPARISON.md',
    'VITEST-CONFIGURATION-COMPLETE.md',
    'VITEST-EXPLORER-CONFIG.md',
    'VITEST-SETUP-COMPLETE.md',
    'NEXT-STEPS.md',
    'QUICK-REFERENCE.txt'
)

foreach ($doc in $oldDocs) {
    $path = Join-Path $root $doc
    if (Test-Path $path) {
        Write-Status "  → $doc → archive/docs/" Gray
        Move-Safely -Source $path -DestDir $docsArchive
    }
}

# ═══════════════════════════════════════════════════════════════
# 3. Consolidate duplicate/superseded scripts
# ═══════════════════════════════════════════════════════════════
Write-Status "`n━━━ 3/5: ARCHIVE SUPERSEDED SCRIPTS ━━━" Yellow
$scriptsArchive = "$root\archive\old-scripts-$(Get-Date -Format 'yyyyMM')"

# Scripts that have been replaced by newer versions
$oldScripts = @(
    # Old VS Code launchers (replaced by Launch-VSCode-Optimized.ps1 v4.0)
    'Launch-VSCode-Enhanced.ps1',
    'Launch-VSCode-Protected.ps1',
    'Start-VSCodeInsidersOptimized.ps1',
    'VS-Code-Cleanup-Launcher.ps1',
    
    # Old monitors (replaced by VSCode-AutoMonitor-Optimized.ps1 v4.0)
    'VSCode-AutoMonitor.ps1',
    'VSCode-AutoMonitor-Enhanced.ps1',
    'VSCode-ProcessMonitor.ps1',
    'Monitor-VSCodeInsiders.ps1',
    'Check-Monitor-Status.ps1',
    'Monitor-Dashboard.ps1',
    'Monitor-Dashboard-PRO.ps1',
    'Start-Dashboard.ps1',
    'Start-Dashboard-PRO.ps1',
    'Test-Dashboard.ps1',
    
    # Old monitor launchers
    'Start-VSCodeMonitor-TEST.ps1',
    'Start-VSCodeMonitor-PROD.ps1',
    'Start-VSCodeMonitor-AGGRESSIVE.ps1',
    
    # Old cleanup scripts (replaced by Cleanup-VSCodeInsiders-Optimized.ps1)
    'Cleanup-VSCodeInsiders.ps1',
    'quick-cleanup.ps1',
    'kill.ps1',
    'vs.ps1',
    
    # Old fixers
    'Fix-VSCodeInsidersTerminal.ps1',
    'Fix-VSCodeInsidersTerminal-v2.ps1',
    
    # Old overclocking scripts (multiple versions)
    'apply-overclocking-config.ps1',
    'apply-overclocking-direct.ps1',
    'apply-msi-xtu-config.ps1',
    'configure-msi-xtu-fixed.ps1',
    'configure-msi-xtu-simple.ps1',
    'configure-overclocking-automated.ps1',
    'configure-overclocking-tools.ps1',
    'configure-overclocking-values.ps1',
    'fix-intel-xtu-installation.ps1',
    'install-and-configure-overclocking.ps1',
    'install-overclocking-manual.ps1',
    'install-overclocking-tools-choco.ps1',
    'install-overclocking-tools.ps1',
    
    # Old batch fixers
    'fix-batch-parentheses.ps1',
    'fix-batch-parentheses-smart.ps1',
    'check-braces.ps1',
    'check-syntax.ps1',
    
    # Old misc
    'debug-line899.ps1',
    'switch-profile.ps1',
    'Verify-CygwinConfig.ps1',
    'check-locked-files.ps1',
    'advanced-script-updater.ps1',
    'validate-all-scripts.ps1',
    'REMOVE-DUPLICATE-BAT-FILES.ps1',
    'organize-hub.ps1',
    'organize-simple.ps1',
    
    # Old desktop shortcut creators
    'copy-menu-to-desktop-now.ps1',
    'copy-to-desktop.ps1',
    'create-desktop-shortcut-admin.ps1',
    'CREATE-CORRECT-DESKTOP-SHORTCUT.ps1',
    'CREATE-DESKTOP-SHORTCUT-OLLAMA.ps1'
)

foreach ($script in $oldScripts) {
    $path = Join-Path $root $script
    if (Test-Path $path) {
        Write-Status "  → $script → archive/old-scripts/" Gray
        Move-Safely -Source $path -DestDir $scriptsArchive
    }
}

# ═══════════════════════════════════════════════════════════════
# 4. Move old bat/cmd files
# ═══════════════════════════════════════════════════════════════
Write-Status "`n━━━ 4/5: ARCHIVE OLD BATCH FILES ━━━" Yellow
$batArchive = "$root\archive\old-batch-$(Get-Date -Format 'yyyyMM')"

$oldBats = @(
    'copy-menu-to-desktop.bat',
    'copy-to-public-desktop-admin.bat',
    'COPY-TO-PUBLIC-DESKTOP.bat',
    'modernize-all-scripts.bat',
    'run-all-portable-scripts.bat',
    'run-overclocking-manager.bat',
    'save-msi-config.bat',
    'test-menu-scripts.bat',
    'test-modernized-scripts.bat',
    'verify-modernized-scripts.bat',
    'SYSTEM-BACKUP-MANAGER.bat'
)

foreach ($bat in $oldBats) {
    $path = Join-Path $root $bat
    if (Test-Path $path) {
        Write-Status "  → $bat → archive/old-batch/" Gray
        Move-Safely -Source $path -DestDir $batArchive
    }
}

# ═══════════════════════════════════════════════════════════════
# 5. Move misc non-essential files
# ═══════════════════════════════════════════════════════════════
Write-Status "`n━━━ 5/5: ARCHIVE MISC FILES ━━━" Yellow
$miscArchive = "$root\archive\misc-$(Get-Date -Format 'yyyyMM')"

$miscFiles = @(
    '3746 dece24.jpg',
    'MSIAfterburner.cfg',
    'dir',
    'global-teardown.ts',
    'nuxt4-optimized.config.ts',
    'package-nuxt4-optimized.json',
    'tailwind-nuxt4-optimized.config.js',
    'playwright-helpers.ps1',
    'playwright-optimizer.ps1',
    'playwright.config.optimized.ts',
    '.goosyignore',
    '.cspell.json',
    'save-msi-config.ps1',
    'apply-and-document-overclocking.ps1',
    'nvidia.ps1',
    'wsl.ps1',
    'schedule-history.json',
    'organization-report.json',
    'vscode-insiders-extensions-20251219.txt',
    'vscode-insiders-extensions-20260104.txt'
)

foreach ($f in $miscFiles) {
    $path = Join-Path $root $f
    if (Test-Path $path) {
        Write-Status "  → $f → archive/misc/" Gray
        Move-Safely -Source $path -DestDir $miscArchive
    }
}

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════
$remainingFiles = (Get-ChildItem $root -File).Count

Write-Status "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" Gray
Write-Status "📊 REORGANIZATION SUMMARY" Cyan
Write-Status "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" Gray
Write-Status "  Files moved: $moved"
Write-Status "  Root files before: $($rootFiles.Count)"
Write-Status "  Root files after: $remainingFiles"
Write-Status "  Mode: $(if($DryRun){'DRY RUN - nothing actually moved'}else{'COMPLETE'})"
Write-Status "`nRemaining essential files in root:" Yellow

if (!$DryRun) {
    Get-ChildItem $root -File | Sort-Object Name | ForEach-Object {
        Write-Status "  📄 $($_.Name)" Gray
    }
}

Write-Status "`nLog: $logFile" Gray
