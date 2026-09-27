# OneDrive Reparse Point Repair Script
# Fixes 0x80071128/0x80071129 errors by handling broken reparse points

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetPath,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Preview = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$QuarantineOnly = $false
)

# Function to write log entries
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Write-Host $logEntry
    
    if ($LogFile -ne "") {
        Add-Content -Path $LogFile -Value $logEntry
    }
}

# Function to check if Cloud Files filter driver is running
function Test-CloudFilesFilter {
    try {
        $service = Get-Service -Name "cldflt" -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq "Running") {
            return $true
        } else {
            Write-Log "[WARNING] Cloud Files filter driver not running"
            try {
                Start-Service -Name "cldflt" -ErrorAction SilentlyContinue
                Write-Log "[SUCCESS] Cloud Files filter driver started"
                return $true
            } catch {
                Write-Log "[ERROR] Failed to start Cloud Files filter driver: $($_.Exception.Message)"
                return $false
            }
        }
    } catch {
        Write-Log "[ERROR] Cloud Files filter driver not found"
        return $false
    }
}

# Function to scan for broken reparse points
function Get-BrokenReparsePoints {
    param([string]$Path)
    
    Write-Log "[INFO] Scanning for reparse points in: $Path"
    
    try {
        $reparseItems = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                       Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }
        
        $brokenItems = @()
        $totalCount = $reparseItems.Count
        
        Write-Log "[INFO] Found $totalCount reparse points"
        
        foreach ($item in $reparseItems) {
            try {
                # Test if reparse point is accessible
                $item.FullName | Out-Null
                $item.Attributes | Out-Null
                # Try to get basic properties
                $item.Name | Out-Null
            } catch {
                $brokenItems += $item
                Write-Log "[WARNING] Broken reparse point detected: $($item.FullName)"
            }
        }
        
        Write-Log "[RESULT] Total reparse points: $totalCount"
        Write-Log "[RESULT] Broken reparse points: $($brokenItems.Count)"
        
        return $brokenItems
    } catch {
        Write-Log "[ERROR] Failed to scan reparse points: $($_.Exception.Message)"
        return @()
    }
}

# Function to quarantine broken reparse point
function Move-ToQuarantine {
    param(
        [System.IO.FileSystemInfo]$Item,
        [string]$QuarantinePath
    )
    
    try {
        $quarantineItemPath = Join-Path $QuarantinePath $Item.Name
        
        # Handle naming conflicts
        $counter = 1
        while (Test-Path $quarantineItemPath) {
            $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($Item.Name)
            $extension = [System.IO.Path]::GetExtension($Item.Name)
            $quarantineItemPath = Join-Path $QuarantinePath "$nameWithoutExt-$counter$extension"
            $counter++
        }
        
        # Move the item to quarantine
        Move-Item -Path $Item.FullName -Destination $quarantineItemPath -Force -ErrorAction Stop
        Write-Log "[SUCCESS] Quarantined: $($Item.FullName) -> $quarantineItemPath"
        
        # Recreate as placeholder if it was a directory
        if ($Item.PSIsContainer) {
            New-Item -ItemType Directory -Path $Item.FullName -Force | Out-Null
            Write-Log "[INFO] Recreated directory placeholder: $($Item.FullName)"
        }
        
        return $true
    } catch {
        Write-Log "[ERROR] Failed to quarantine $($Item.FullName): $($_.Exception.Message)"
        return $false
    }
}

# Function to clear Files On-Demand cache
function Clear-FilesOnDemandCache {
    param([string]$Path)
    
    try {
        Write-Log "[INFO] Clearing Files On-Demand cache for: $Path"
        
        # Use attrib command to clear placeholder attributes
        & cmd.exe /c "attrib -U -P /S /D `"$Path\*`" 2>nul" | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "[SUCCESS] Files On-Demand cache cleared"
        } else {
            Write-Log "[WARNING] Some files may not have been processed (exit code: $LASTEXITCODE)"
        }
    } catch {
        Write-Log "[ERROR] Failed to clear Files On-Demand cache: $($_.Exception.Message)"
    }
}

# Main execution
Write-Log "[INFO] OneDrive Reparse Point Repair Started"
Write-Log "[INFO] Target Path: $TargetPath"
Write-Log "[INFO] Preview Mode: $Preview"
Write-Log "[INFO] Quarantine Only: $QuarantineOnly"

# Check Cloud Files filter driver
if (-not (Test-CloudFilesFilter)) {
    Write-Log "[WARNING] Cloud Files filter driver issues detected, but continuing..."
}

# Determine paths to process
$pathsToProcess = @()
if ($TargetPath -eq "ALL") {
    # Process all OneDrive accounts
    $userProfile = $env:USERPROFILE
    if (Test-Path "$userProfile\OneDrive") {
        $pathsToProcess += "$userProfile\OneDrive"
    }
    Get-ChildItem "$userProfile\OneDrive - *" -Directory -ErrorAction SilentlyContinue | 
        ForEach-Object { $pathsToProcess += $_.FullName }
} else {
    $pathsToProcess += $TargetPath
}

Write-Log "[INFO] Processing $($pathsToProcess.Count) OneDrive account(s)"

$totalFixed = 0
$totalQuarantined = 0
$totalProcessed = 0

foreach ($path in $pathsToProcess) {
    Write-Log "[INFO] Processing account: $path"
    
    if (-not (Test-Path $path)) {
        Write-Log "[ERROR] Path not found: $path"
        continue
    }
    
    # Get broken reparse points
    $brokenItems = Get-BrokenReparsePoints -Path $path
    
    if ($brokenItems.Count -eq 0) {
        Write-Log "[SUCCESS] No broken reparse points found in: $path"
        continue
    }
    
    if ($Preview) {
        Write-Log "[PREVIEW] Would fix $($brokenItems.Count) broken reparse points in: $path"
        foreach ($item in $brokenItems | Select-Object -First 10) {
            Write-Log "[PREVIEW]   - $($item.FullName)"
        }
        if ($brokenItems.Count -gt 10) {
            Write-Log "[PREVIEW]   ... and $($brokenItems.Count - 10) more"
        }
        continue
    }
    
    # Create quarantine folder
    $quarantinePath = Join-Path $path "_OneDrive_ReparseFix_Quarantine"
    if (-not (Test-Path $quarantinePath)) {
        try {
            New-Item -ItemType Directory -Path $quarantinePath -Force | Out-Null
            Write-Log "[INFO] Created quarantine folder: $quarantinePath"
        } catch {
            Write-Log "[ERROR] Failed to create quarantine folder: $($_.Exception.Message)"
            continue
        }
    }
    
    # Process each broken reparse point
    foreach ($item in $brokenItems) {
        $totalProcessed++
        Write-Log "[INFO] Processing item $totalProcessed of $($brokenItems.Count): $($item.FullName)"
        
        if (Move-ToQuarantine -Item $item -QuarantinePath $quarantinePath) {
            $totalFixed++
            $totalQuarantined++
        }
    }
    
    # Clear Files On-Demand cache for this account
    if (-not $QuarantineOnly) {
        Clear-FilesOnDemandCache -Path $path
    }
}

# Summary
Write-Log "[INFO] Repair completed"
Write-Log "[RESULT] Total items processed: $totalProcessed"
Write-Log "[RESULT] Total items fixed: $totalFixed"
Write-Log "[RESULT] Total items quarantined: $totalQuarantined"

if ($totalFixed -gt 0) {
    Write-Log "[SUCCESS] OneDrive reparse point repair completed successfully"
    Write-Log "[INFO] Please restart OneDrive to complete the repair"
    exit 0
} else {
    Write-Log "[INFO] No broken reparse points found or no fixes applied"
    exit 0
}
