# ========================================================================
#                    REMOVE DUPLICATE BAT FILES
#                    Keep Newest, Remove Older Duplicates
# ========================================================================

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "                    REMOVE DUPLICATE BAT FILES" -ForegroundColor Cyan
Write-Host "                    Keep Newest, Remove Older Duplicates" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""

# Set up paths
$devOptimizerPath = "D:\DevOptimizer"
$backupDir = Join-Path $devOptimizerPath "Backups\duplicate-removal"
$logFile = Join-Path $devOptimizerPath "duplicate-removal-log.txt"

# Create backup directory
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "[STATUS] Scanning for duplicate BAT files..." -ForegroundColor Green
Write-Host "[INFO] Will keep newest versions and remove older duplicates" -ForegroundColor Yellow
Write-Host "[INFO] Backups will be created in: $backupDir" -ForegroundColor Yellow
Write-Host ""

# Get all BAT files
$allBatFiles = Get-ChildItem "$devOptimizerPath\*.bat" | Sort-Object Name

# Group files by base name (without extension and common prefixes/suffixes)
$groupedFiles = @{}
$duplicates = @()
$removedCount = 0
$backedUpCount = 0

Write-Host "[ANALYSIS] Analyzing file names for duplicates..." -ForegroundColor Cyan

foreach ($file in $allBatFiles) {
    $baseName = $file.BaseName

    # Normalize the name by removing common variations
    $normalizedName = $baseName

    # Remove common prefixes and suffixes that indicate duplicates
    $normalizedName = $normalizedName -replace '^-', ''  # Remove leading dash
    $normalizedName = $normalizedName -replace '-ORIGINAL$', ''  # Remove -ORIGINAL suffix
    $normalizedName = $normalizedName -replace '-BACKUP$', ''  # Remove -BACKUP suffix
    $normalizedName = $normalizedName -replace '-COPY$', ''  # Remove -COPY suffix
    $normalizedName = $normalizedName -replace '-OLD$', ''  # Remove -OLD suffix
    $normalizedName = $normalizedName -replace '-NEW$', ''  # Remove -NEW suffix
    $normalizedName = $normalizedName -replace '-VERBOSE-DESCRIPTIONS$', ''  # Remove verbose suffix
    $normalizedName = $normalizedName -replace '-WITH-DESCRIPTIONS$', ''  # Remove descriptions suffix
    $normalizedName = $normalizedName -replace '-COMPREHENSIVE$', ''  # Remove comprehensive suffix
    $normalizedName = $normalizedName -replace '-ENHANCED$', ''  # Remove enhanced suffix
    $normalizedName = $normalizedName -replace '-IMPROVED$', ''  # Remove improved suffix
    $normalizedName = $normalizedName -replace '-FIXED$', ''  # Remove fixed suffix
    $normalizedName = $normalizedName -replace '-UPDATED$', ''  # Remove updated suffix
    $normalizedName = $normalizedName -replace '-LATEST$', ''  # Remove latest suffix
    $normalizedName = $normalizedName -replace '-FINAL$', ''  # Remove final suffix
    $normalizedName = $normalizedName -replace '-V\d+$', ''  # Remove version numbers like -V1, -V2
    $normalizedName = $normalizedName -replace '-\d+$', ''  # Remove trailing numbers

    # Convert to lowercase for comparison
    $normalizedName = $normalizedName.ToLower()

    if (-not $groupedFiles.ContainsKey($normalizedName)) {
        $groupedFiles[$normalizedName] = @()
    }

    $groupedFiles[$normalizedName] += $file
}

Write-Host "[ANALYSIS] Found $($groupedFiles.Count) unique base names" -ForegroundColor Yellow
Write-Host ""

# Find duplicates
foreach ($group in $groupedFiles.GetEnumerator()) {
    if ($group.Value.Count -gt 1) {
        $duplicates += $group.Value
        Write-Host "[DUPLICATE GROUP] '$($group.Key)' has $($group.Value.Count) files:" -ForegroundColor Red

        # Sort by modification date (newest first)
        $sortedFiles = $group.Value | Sort-Object LastWriteTime -Descending

        foreach ($file in $sortedFiles) {
            $age = (Get-Date) - $file.LastWriteTime
            $ageText = if ($age.Days -gt 0) { "$($age.Days) days ago" }
                      elseif ($age.Hours -gt 0) { "$($age.Hours) hours ago" }
                      else { "$($age.Minutes) minutes ago" }

            Write-Host "  - $($file.Name) (Modified: $ageText)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

if ($duplicates.Count -eq 0) {
    Write-Host "[SUCCESS] No duplicate BAT files found!" -ForegroundColor Green
    Write-Host "[INFO] All BAT files appear to be unique" -ForegroundColor Yellow
    exit 0
}

Write-Host "[SUMMARY] Found $($duplicates.Count) duplicate files across $($groupedFiles.Values | Where-Object { $_.Count -gt 1 } | Measure-Object).Count groups" -ForegroundColor Yellow
Write-Host ""

# Ask for confirmation
Write-Host "[CONFIRMATION] Do you want to remove the older duplicate files?" -ForegroundColor Yellow
Write-Host "[INFO] This will:" -ForegroundColor White
Write-Host "  1. Keep the newest version of each duplicate group" -ForegroundColor White
Write-Host "  2. Create backups of files to be removed" -ForegroundColor White
Write-Host "  3. Remove the older duplicate files" -ForegroundColor White
Write-Host ""
$confirmation = Read-Host "Type 'YES' to proceed with removal"

if ($confirmation -ne "YES") {
    Write-Host "[CANCELLED] Duplicate removal cancelled by user" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "[PROCESSING] Starting duplicate removal process..." -ForegroundColor Green

# Process each duplicate group
foreach ($group in $groupedFiles.GetEnumerator()) {
    if ($group.Value.Count -gt 1) {
        Write-Host "[PROCESSING] Group: '$($group.Key)'" -ForegroundColor Cyan

        # Sort by modification date (newest first)
        $sortedFiles = $group.Value | Sort-Object LastWriteTime -Descending
        $newestFile = $sortedFiles[0]
        $olderFiles = $sortedFiles[1..($sortedFiles.Count-1)]

        Write-Host "  [KEEPING] $($newestFile.Name) (newest)" -ForegroundColor Green

        foreach ($oldFile in $olderFiles) {
            try {
                # Create backup
                $backupPath = Join-Path $backupDir $oldFile.Name
                Copy-Item $oldFile.FullName $backupPath -Force
                $backedUpCount++

                # Remove the duplicate
                Remove-Item $oldFile.FullName -Force
                $removedCount++

                Write-Host "  [REMOVED] $($oldFile.Name) (backed up to: $backupPath)" -ForegroundColor Red

                # Log the action
                $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - REMOVED: $($oldFile.Name) (backed up to: $backupPath)"
                Add-Content -Path $logFile -Value $logEntry

            } catch {
                Write-Host "  [ERROR] Failed to remove $($oldFile.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
}

Write-Host "========================================================================" -ForegroundColor Green
Write-Host "                    DUPLICATE REMOVAL COMPLETED" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[RESULTS]" -ForegroundColor White
Write-Host "  - Files removed: $removedCount" -ForegroundColor Red
Write-Host "  - Files backed up: $backedUpCount" -ForegroundColor Yellow
Write-Host "  - Backup location: $backupDir" -ForegroundColor Gray
Write-Host "  - Log file: $logFile" -ForegroundColor Gray
Write-Host ""
Write-Host "[SUCCESS] Duplicate removal completed successfully!" -ForegroundColor Green
Write-Host "[INFO] All removed files have been backed up for safety" -ForegroundColor Yellow
Write-Host ""

# Show remaining files count
$remainingFiles = (Get-ChildItem "$devOptimizerPath\*.bat").Count
Write-Host "[INFO] Remaining BAT files: $remainingFiles" -ForegroundColor Cyan

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
