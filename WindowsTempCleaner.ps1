# Windows Temporary File Cleaner
# Review this script carefully before running!
# It will clean temp files from safe locations only

Write-Host "=== Windows Temporary File Cleaner ===" -ForegroundColor Cyan
Write-Host "This script will clean temporary files from known safe locations."
Write-Host "Review the script before running - it shows what will be deleted first."
Write-Host ""

# Function to get size of files in bytes and convert to readable format
function Get-ReadableSize {
    param([double]$bytes)
    if ($bytes -ge 1TB) { return "{0:N2} TB" -f ($bytes/1TB) }
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes/1GB) }
    if ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes/1MB) }
    if ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes/1KB) }
    return "{0} Bytes" -f $bytes
}

# Initialize counters
$totalDeleted = 0
$totalSize = 0
$errors = @()

# Define temp locations to clean (relative to user environment)
$tempLocations = @(
    @{ Path = "$env:TEMP"; Description = "User Temp Folder (%TEMP%)" },
    @{ Path = "$env:WINDIR\Temp"; Description = "Windows Temp Folder" },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Description = "Internet Cache" },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"; Description = "Web Cache" },
    @{ Path = "$env:LOCALAPPDATA\Temp"; Description = "Local AppData Temp" }
)

# Browser cache locations (add if browsers are installed)
$browserLocations = @()
if (Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\*") {
    $browserLocations += @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache"; Description = "Chrome Cache" }
}
if (Test-Path "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*") {
    $browserLocations += @{ Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2\"; Description = "Firefox Cache" }
}
if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*") {
    $browserLocations += @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache"; Description = "Edge Cache" }
}

# Combine all locations
$allLocations = $tempLocations + $browserLocations

Write-Host "Scanning for temporary files..." -ForegroundColor Yellow

foreach ($location in $allLocations) {
    # Resolve wildcards in path
    $resolvedPaths = @()
    if ($location.Path -like "*\*") {
        $folderPath = Split-Path $location.Path -Parent
        $wildcardPart = Split-Path $location.Path -Leaf
        if (Test-Path $folderPath) {
            $resolvedPaths = Get-ChildItem -Path $folderPath -Filter $wildcardPart -Directory -ErrorAction SilentlyContinue |
                             ForEach-Object { Join-Path $folderPath $_.Name }
        }
    } else {
        if (Test-Path $location.Path) {
            $resolvedPaths = @($location.Path)
        }
    }

    foreach ($path in $resolvedPaths) {
        if (-not (Test-Path $path)) { continue }

        Write-Host "`nChecking: $($location.Description)" -ForegroundColor Green
        Write-Host "Path: $path"

        try {
            # Get files older than 24 hours (to avoid deleting currently used files)
            $files = Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-24) }

            if ($files.Count -eq 0) {
                Write-Host "  No temp files found (or all files are in use)" -ForegroundColor DarkGray
                continue
            }

            $sizeToDelete = ($files | Measure-Object -Property Length -Sum).Sum
            Write-Host "  Found $($files.Count) files totaling $([int]($sizeToDelete/1024)) KB"
            Write-Host "  These files will be deleted:"

            # Show first few files as examples
            $showCount = [Math]::Min(5, $files.Count)
            for ($i = 0; $i -lt $showCount; $i++) {
                Write-Host "    $($files[$i].Name)"
            }
            if ($files.Count -gt 5) {
                Write-Host "    ... and $($files.Count - 5) more"
            }

            # Ask for confirmation
            $answer = Read-Host "  Delete these files? (y/n/all)"
            if ($answer -eq "all") {
                $deleteAll = $true
                $answer = "y"
            } elseif ($answer -eq "n") {
                continue
            }

            if ($answer -eq "y") {
                $deletedCount = 0
                $deletedSize = 0
                foreach ($file in $files) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        $deletedCount++
                        $deletedSize += $file.Length
                    } catch {
                        # File might be in use - skip it
                        $errors += "Could not delete $($file.Name): $_"
                    }
                }
                Write-Host "  ✓ Deleted $deletedCount files ($([int]($deletedSize/1024)) KB)" -ForegroundColor Green
                $totalDeleted += $deletedCount
                $totalSize += $deletedSize
            }
        } catch {
            Write-Host "  Error scanning ${path}: $_" -ForegroundColor Red
            $errors += "Error scanning ${path}: $_"
        }
    }
}

# Special handling for Recycle Bin
Write-Host "`nChecking Recycle Bin..." -ForegroundColor Yellow
try {
    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.Namespace(0xA)  # 0xA is Recycle Bin
    if ($recycleBin) {
        $items = $recycleBin.Items()
        $count = $items.Count
        if ($count -gt 0) {
            $size = 0
            foreach ($item in $items) {
                try { $size += $item.Size } catch {}
            }
            Write-Host "  Recycle Bin contains $count items totaling $([int]($size/1024)) KB"
            $answer = Read-Host "  Empty Recycle Bin? (y/n)"
            if ($answer -eq "y") {
                $shell.Namespace(0xA).Items() | ForEach-Object { $shell.Namespace(0xA).ParseName($_.Name).Delete() }
                Write-Host "  ✓ Recycle Bin emptied" -ForegroundColor Green
            }
        } else {
            Write-Host "  Recycle Bin is already empty" -ForegroundColor DarkGray
        }
    }
} catch {
    Write-Host "  Could not access Recycle Bin: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n=== CLEANUP SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total files deleted: $totalDeleted"
Write-Host "Total space freed: $([int]($totalSize/1024)) KB ($([math]::Round($totalSize/1MB, 2)) MB)"
if ($errors.Count -gt 0) {
    Write-Host "`nErrors encountered ($($errors.Count) files skipped, likely in use):" -ForegroundColor Yellow
    $errors[0..[Math]::Min(9, $errors.Count-1)] | ForEach-Object { Write-Host "  $_" }
    if ($errors.Count -gt 10) {
        Write-Host "  ... and $($errors.Count - 10) more errors"
    }
}
Write-Host "`nCleanup complete!" -ForegroundColor Green

# Optional: Pause so user can see results
# Read-Host "Press Enter to exit"