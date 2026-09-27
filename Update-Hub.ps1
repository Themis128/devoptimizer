<#
.SYNOPSIS
    Self-update with rollback for DevOptimizer Script Hub

.DESCRIPTION
    Updates the DevOptimizer Script Hub from a source (Git, local path, or release).
    Creates automatic backups for rollback capability.

.PARAMETER Source
    Update source: 'git', 'local', 'release' (default: git)

.PARAMETER GitRemote
    Git remote name (default: origin)

.PARAMETER GitBranch
    Git branch to pull (default: main)

.PARAMETER LocalPath
    Local source path (for Source=local)

.PARAMETER ReleaseUrl
    Release download URL (for Source=release)

.PARAMETER BackupDir
    Backup directory (default: backups)

.PARAMETER Rollback
    Rollback to previous version

.PARAMETER ListBackups
    List available backups

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER PassThru
    Return result object instead of exiting

.EXAMPLE
    Update-Hub.ps1
    Update-Hub.ps1 -Source git -GitBranch develop
    Update-Hub.ps1 -Source local -LocalPath "C:\DevOptimizer-New"
    Update-Hub.ps1 -Rollback
    Update-Hub.ps1 -ListBackups
#>

[CmdletBinding(DefaultParameterSetName="UpdateGit")]
param(
    [Parameter(ParameterSetName="UpdateGit")]
    [Parameter(ParameterSetName="UpdateLocal")]
    [Parameter(ParameterSetName="UpdateRelease")]
    [ValidateSet("git", "local", "release")]
    [string]$Source = "git",

    [Parameter(ParameterSetName="UpdateGit")]
    [string]$GitRemote = "origin",

    [Parameter(ParameterSetName="UpdateGit")]
    [string]$GitBranch = "main",

    [Parameter(ParameterSetName="UpdateLocal", Mandatory=$true)]
    [string]$LocalPath,

    [Parameter(ParameterSetName="UpdateRelease", Mandatory=$true)]
    [string]$ReleaseUrl,

    [Parameter(ParameterSetName="UpdateGit")]
    [Parameter(ParameterSetName="UpdateLocal")]
    [Parameter(ParameterSetName="UpdateRelease")]
    [Parameter(ParameterSetName="Rollback")]
    [Parameter(ParameterSetName="List")]
    [string]$BackupDir = "backups",

    [Parameter(ParameterSetName="Rollback", Mandatory=$true)]
    [switch]$Rollback,

    [Parameter(ParameterSetName="Rollback")]
    [string]$BackupName,

    [Parameter(ParameterSetName="List")]
    [switch]$ListBackups,

    [Parameter(ParameterSetName="UpdateGit")]
    [Parameter(ParameterSetName="UpdateLocal")]
    [Parameter(ParameterSetName="UpdateRelease")]
    [Parameter(ParameterSetName="Rollback")]
    [Parameter(ParameterSetName="List")]
    [switch]$Force,

    [Parameter(ParameterSetName="UpdateGit")]
    [Parameter(ParameterSetName="UpdateLocal")]
    [Parameter(ParameterSetName="UpdateRelease")]
    [Parameter(ParameterSetName="Rollback")]
    [Parameter(ParameterSetName="List")]
    [switch]$PassThru
)

$RootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fullBackupDir = Join-Path $RootPath $BackupDir

function Write-Color {
    param([string]$Text, [string]$Color = "White", [switch]$NoNewline)
    $fg = switch ($Color) {
        "Red" { [ConsoleColor]::Red }
        "Green" { [ConsoleColor]::Green }
        "Yellow" { [ConsoleColor]::Yellow }
        "Cyan" { [ConsoleColor]::Cyan }
        "Magenta" { [ConsoleColor]::Magenta }
        "Gray" { [ConsoleColor]::Gray }
        "DarkGray" { [ConsoleColor]::DarkGray }
        default { [ConsoleColor]::White }
    }
    if ($NoNewline) {
        Write-Host $Text -ForegroundColor $fg -NoNewline
    } else {
        Write-Host $Text -ForegroundColor $fg
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $prefix = switch ($Level) {
        "ERROR" { "[ERROR]" }
        "WARN" { "[WARN] " }
        "OK" { "[OK]   " }
        default { "[INFO] " }
    }
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "OK" { "Green" }
        default { "White" }
    }
    Write-Color ("{0} {1}" -f $prefix, $Message) $color
}

function New-Backup {
    param([string]$BackupName = $null)
    if (-not $BackupName) {
        $BackupName = "backup-{0:yyyyMMdd-HHmmss}" -f (Get-Date)
    }
    $backupPath = Join-Path $fullBackupDir $BackupName
    
    if (-not (Test-Path $fullBackupDir)) {
        New-Item -ItemType Directory -Path $fullBackupDir -Force | Out-Null
    }
    
    Write-Log "Creating backup: $BackupName"
    
    # Files/directories to backup (core hub files)
    $itemsToBackup = @(
        "DevOptimizer-Master.psm1",
        "DevOptimizer-Config.psm1",
        "DevOptimizer-Path.psm1",
        "DevOptimizer-Admin.psm1",
        "Discover-Scripts.ps1",
        "Build-Registry.ps1",
        "Execute-Command.ps1",
        "Show-Menu.ps1",
        "Get-Category.ps1",
        "Manage-Favorites.ps1",
        "Check-Health.ps1",
        "Update-Hub.ps1",
        "config\hub-config.json",
        "config\schemas\hub-registry.schema.json",
        "config\schemas\hub-config.schema.json",
        "modules"
    )
    
    $copied = 0
    foreach ($item in $itemsToBackup) {
        $src = Join-Path $RootPath $item
        $dst = Join-Path $backupPath $item
        if (Test-Path $src) {
            $dstDir = Split-Path -Parent $dst
            if (-not (Test-Path $dstDir)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }
            Copy-Item -Path $src -Destination $dst -Recurse -Force -ErrorAction SilentlyContinue
            $copied++
        }
    }
    
    # Create backup manifest
    $manifest = @{
        name = $BackupName
        timestamp = (Get-Date).ToString("o")
        items = $itemsToBackup
        copied = $copied
        version = "unknown"
    }
    
    # Try to get current version from registry
    $registryPath = Join-Path $RootPath "config\hub-registry.json"
    if (Test-Path $registryPath) {
        try {
            $registry = Get-Content $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            $manifest.version = $registry.version
        } catch { }
    }
    
    $manifest | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $backupPath "backup-manifest.json") -Encoding UTF8
    
    Write-Log "Backup created: $backupPath ($copied items)"
    return $backupPath
}

function Restore-Backup {
    param([string]$BackupName)
    $backupPath = Join-Path $fullBackupDir $BackupName
    
    if (-not (Test-Path $backupPath)) {
        Write-Log "Backup not found: $BackupName" "ERROR"
        return $false
    }
    
    $manifestPath = Join-Path $backupPath "backup-manifest.json"
    if (Test-Path $manifestPath) {
        $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Log "Restoring backup: $($manifest.name) from $($manifest.timestamp)"
    }
    
    Write-Log "Restoring files from backup..."
    
    $items = Get-ChildItem -Path $backupPath -Recurse -File | Where-Object { $_.Name -ne "backup-manifest.json" }
    $restored = 0
    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($backupPath.Length + 1)
        $dst = Join-Path $RootPath $relativePath
        $dstDir = Split-Path -Parent $dst
        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        Copy-Item -Path $item.FullName -Destination $dst -Force -ErrorAction SilentlyContinue
        $restored++
    }
    
    Write-Log "Restored $restored files from backup"
    return $true
}

function List-Backups {
    if (-not (Test-Path $fullBackupDir)) {
        Write-Log "No backups directory found"
        return @()
    }
    
    $backups = Get-ChildItem -Path $fullBackupDir -Directory | Sort-Object LastWriteTime -Descending
    $results = @()
    
    foreach ($backup in $backups) {
        $manifestPath = Join-Path $backup.FullName "backup-manifest.json"
        $info = @{
            name = $backup.Name
            path = $backup.FullName
            date = $backup.LastWriteTime
        }
        if (Test-Path $manifestPath) {
            try {
                $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                $info.version = $manifest.version
                $info.items = $manifest.copied
            } catch { }
        }
        $results += $info
    }
    
    return $results
}

function Update-FromGit {
    param([string]$Remote, [string]$Branch)
    Write-Log "Updating from Git ($Remote/$Branch)..."
    
    # Check if we're in a git repo
    if (-not (Test-Path (Join-Path $RootPath ".git"))) {
        Write-Log "Not a Git repository" "ERROR"
        return $false
    }
    
    try {
        # Fetch latest
        & git -C $RootPath fetch $Remote -ErrorAction Stop
        
        # Check for changes
        $status = & git -C $RootPath status --porcelain -ErrorAction Stop
        if ($status) {
            Write-Log "Working directory has uncommitted changes" "WARN"
            if (-not $Force) {
                Write-Color "Commit or stash changes before updating. Use -Force to overwrite." "Yellow"
                return $false
            }
        }
        
        # Pull changes
        & git -C $RootPath pull $Remote $Branch -ErrorAction Stop
        
        Write-Log "Git update successful"
        return $true
    } catch {
        Write-Log "Git update failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Update-FromLocal {
    param([string]$SourcePath)
    Write-Log "Updating from local path: $SourcePath"
    
    if (-not (Test-Path $SourcePath)) {
        Write-Log "Source path not found: $SourcePath" "ERROR"
        return $false
    }
    
    # Copy files from source
    $items = Get-ChildItem -Path $SourcePath -Recurse -File
    $copied = 0
    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($SourcePath.Length + 1)
        $dst = Join-Path $RootPath $relativePath
        $dstDir = Split-Path -Parent $dst
        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        Copy-Item -Path $item.FullName -Destination $dst -Force -ErrorAction SilentlyContinue
        $copied++
    }
    
    Write-Log "Local update successful ($copied files copied)"
    return $true
}

function Update-FromRelease {
    param([string]$Url)
    Write-Log "Downloading release from: $Url"
    
    try {
        $tempDir = Join-Path $env:TEMP ("devoptimizer-update-{0}" -f [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        $zipPath = Join-Path $tempDir "release.zip"
        Write-Log "Downloading..."
        Invoke-WebRequest -Uri $Url -OutFile $zipPath -ErrorAction Stop
        
        Write-Log "Extracting..."
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force -ErrorAction Stop
        
        # Find extracted content
        $extractedDirs = Get-ChildItem -Path $tempDir -Directory
        if ($extractedDirs.Count -eq 1) {
            $sourceDir = $extractedDirs[0].FullName
        } else {
            $sourceDir = $tempDir
        }
        
        # Copy files
        $items = Get-ChildItem -Path $sourceDir -Recurse -File
        $copied = 0
        foreach ($item in $items) {
            $relativePath = $item.FullName.Substring($sourceDir.Length + 1)
            $dst = Join-Path $RootPath $relativePath
            $dstDir = Split-Path -Parent $dst
            if (-not (Test-Path $dstDir)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }
            Copy-Item -Path $item.FullName -Destination $dst -Force -ErrorAction SilentlyContinue
            $copied++
        }
        
        # Cleanup
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Log "Release update successful ($copied files copied)"
        return $true
    } catch {
        Write-Log "Release update failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

Write-Color "+==============================================================================+" "Cyan"
Write-Color "| DevOptimizer Script Hub - Update Manager                                    |" "Cyan"
Write-Color "+==============================================================================+" "Cyan"
Write-Color ""

$result = @{
    success = $false
    action = ""
    backup = $null
    message = ""
    timestamp = (Get-Date).ToString("o")
}

if ($ListBackups) {
    $result.action = "list"
    $backups = List-Backups
    Write-Color "Available Backups:" "Cyan"
    Write-Color ""
    if ($backups.Count -eq 0) {
        Write-Color "  No backups found" "Gray"
    } else {
        foreach ($b in $backups) {
            Write-Color "  $($b.name)" "White" -NoNewline
            Write-Color "  [$($b.date.ToString('yyyy-MM-dd HH:mm:ss'))]" "Gray"
            if ($b.version) { Write-Color "    Version: $($b.version), Items: $($b.items)" "DarkGray" }
        }
    }
    $result.backups = $backups
    $result.success = $true
    $result.message = "Listed $($backups.Count) backups"
}

elseif ($Rollback) {
    $result.action = "rollback"
    $backups = List-Backups
    if ($backups.Count -eq 0) {
        Write-Log "No backups available for rollback" "ERROR"
        $result.message = "No backups available"
    } else {
        $targetBackup = $BackupName
        if (-not $targetBackup) {
            $targetBackup = $backups[0].name
            Write-Color "Rolling back to latest backup: $targetBackup" "Yellow"
        }
        
        if (-not $Force) {
            Write-Color "This will overwrite current files. Continue? (y/N): " "Yellow" -NoNewline
            $confirm = Read-Host
            if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                Write-Log "Rollback cancelled" "WARN"
                $result.message = "Rollback cancelled by user"
            } else {
                if (Restore-Backup -BackupName $targetBackup) {
                    $result.success = $true
                    $result.backup = $targetBackup
                    $result.message = "Rollback completed successfully"
                    Write-Log "Rollback completed. Rebuild registry recommended." "OK"
                } else {
                    $result.message = "Rollback failed"
                }
            }
        } else {
            if (Restore-Backup -BackupName $targetBackup) {
                $result.success = $true
                $result.backup = $targetBackup
                $result.message = "Rollback completed successfully"
                Write-Log "Rollback completed. Rebuild registry recommended." "OK"
            } else {
                $result.message = "Rollback failed"
            }
        }
    }
}

else {
    $result.action = "update"
    
    # Create backup before update
    $backupPath = New-Backup
    $result.backup = Split-Path -Leaf $backupPath
    
    $updateSuccess = $false
    switch ($Source) {
        "git" { $updateSuccess = Update-FromGit -Remote $GitRemote -Branch $GitBranch }
        "local" { $updateSuccess = Update-FromLocal -SourcePath $LocalPath }
        "release" { $updateSuccess = Update-FromRelease -Url $ReleaseUrl }
    }
    
    if ($updateSuccess) {
        $result.success = $true
        $result.message = "Update completed successfully"
        Write-Log "Update completed. Run Build-Registry.ps1 to rebuild registry." "OK"
    } else {
        $result.message = "Update failed"
        Write-Log "Update failed. Restoring from backup..." "ERROR"
        if (Restore-Backup -BackupName $result.backup) {
            Write-Log "Rollback completed automatically" "OK"
        }
    }
}

Write-Color ""
Write-Color "+==============================================================================+" "Cyan"
Write-Color "| Update Summary                                                               |" "Cyan"
Write-Color "+==============================================================================+" "Cyan"
Write-Color ""
Write-Color "Action: $($result.action)" "White"
$statusText = if ($result.success) { "SUCCESS" } else { "FAILED" }
$statusColor = if ($result.success) { "Green" } else { "Red" }
Write-Color "Status: $statusText" $statusColor
Write-Color "Message: $($result.message)" "White"
if ($result.backup) { Write-Color "Backup: $($result.backup)" "Cyan" }

if ($PassThru) {
    return $result
}

if (-not $result.success) { exit 1 }
exit 0