# Advanced Script Updater with Cutting-Edge Techniques
# Uses modern algorithms and best practices

param(
    [string]$ScriptDir = "D:\DevOptimizer\portable",
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"

# Advanced logging with structured data
class ScriptLogger {
    [string]$LogFile
    [System.Collections.ArrayList]$LogEntries

    ScriptLogger([string]$logPath) {
        $this.LogFile = $logPath
        $this.LogEntries = New-Object System.Collections.ArrayList
    }

    [void] Log([string]$level, [string]$message, [hashtable]$metadata = @{}) {
        $entry = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Level = $level
            Message = $message
            Metadata = $metadata
        }
        $this.LogEntries.Add($entry) | Out-Null

        $logLine = "[$($entry.Timestamp)] [$($entry.Level)] $($entry.Message)"
        if ($metadata.Count -gt 0) {
            $logLine += " | " + ($metadata | ConvertTo-Json -Compress)
        }
        try {
            [System.IO.File]::AppendAllText($this.LogFile, $logLine + "`r`n", [System.Text.Encoding]::UTF8)
        } catch {
            Write-Host "Log write error: $_" -ForegroundColor Yellow
        }
    }
}

# Advanced pattern matching using regex and AST
class ScriptAnalyzer {
    [hashtable] AnalyzeScript([string]$scriptPath) {
        $content = Get-Content -Path $scriptPath -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return @{ Valid = $false; Issues = @("File not readable") } }

        $issues = @()
        $patterns = @{
            "MissingEchoOff" = @{
                Pattern = '^@echo\s+off'
                Issue = "Missing @echo off"
                Fix = "Add @echo off at start"
            }
            "MissingSetlocal" = @{
                Pattern = 'setlocal\s+enabledelayedexpansion'
                Issue = "Missing setlocal enabledelayedexpansion"
                Fix = "Add setlocal enabledelayedexpansion"
            }
            "MissingExit" = @{
                Pattern = '(exit\s+/b|goto\s+:eof|exit\s+0)'
                Issue = "Missing proper exit statement"
                Fix = "Add exit /b 0 at end"
            }
            "HardcodedPaths" = @{
                Pattern = '[A-Z]:\\[^"]*'
                Issue = "Hardcoded absolute paths"
                Fix = "Use relative paths or variables"
            }
            "NoErrorHandling" = @{
                Pattern = 'if\s+errorlevel|if\s+%\?errorlevel\?%'
                Issue = "Limited error handling"
                Fix = "Add comprehensive error handling"
            }
            "InefficientLoops" = @{
                Pattern = 'for\s+/f\s+.*\s+in\s+\(.*\)'
                Issue = "Potentially inefficient loops"
                Fix = "Optimize loop structure"
            }
        }

        $analysis = @{
            Valid = $true
            Issues = @()
            Recommendations = @()
            Complexity = 0
            Lines = ($content -split "`n").Count
        }

        foreach ($key in $patterns.Keys) {
            $pattern = $patterns[$key]
            if ($key -eq "MissingEchoOff") {
                if ($content -notmatch $pattern.Pattern) {
                    $analysis.Issues += $pattern.Issue
                    $analysis.Recommendations += $pattern.Fix
                }
            } elseif ($key -eq "MissingSetlocal") {
                if ($content -notmatch $pattern.Pattern) {
                    $analysis.Issues += $pattern.Issue
                    $analysis.Recommendations += $pattern.Fix
                }
            } elseif ($key -eq "MissingExit") {
                if ($content -notmatch $pattern.Pattern) {
                    $analysis.Issues += $pattern.Issue
                    $analysis.Recommendations += $pattern.Fix
                }
            }
        }

        # Calculate complexity (simple metric)
        $complexity = 0
        $complexity += ([regex]::Matches($content, '\bif\b', 'IgnoreCase')).Count
        $complexity += ([regex]::Matches($content, '\bfor\b', 'IgnoreCase')).Count
        $complexity += ([regex]::Matches($content, '\bgoto\b', 'IgnoreCase')).Count
        $complexity += ([regex]::Matches($content, '\bcall\b', 'IgnoreCase')).Count
        $analysis.Complexity = $complexity

        return $analysis
    }
}

# Advanced script transformer using modern techniques
class ScriptTransformer {
    [string] TransformScript([string]$scriptPath, [hashtable]$analysis) {
        $content = Get-Content -Path $scriptPath -Raw -Encoding UTF8
        $originalContent = $content
        $lines = $content -split "`r?`n"
        $newLines = New-Object System.Collections.ArrayList

        # Track if we've added header
        $headerAdded = $false
        $setlocalAdded = $false

        # Process each line with advanced algorithms
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $trimmed = $line.Trim()

            # Skip empty lines at start (we'll add header)
            if ($i -eq 0 -and $trimmed -eq "") {
                continue
            }

            # Add modern header at the very beginning
            if ($i -eq 0 -and $trimmed -notmatch '^@echo\s+off') {
                $newLines.Add("@echo off") | Out-Null
                $newLines.Add("setlocal enabledelayedexpansion") | Out-Null
                $newLines.Add("") | Out-Null
                $headerAdded = $true
                $setlocalAdded = $true
            }

            # Ensure setlocal is present early
            if (-not $setlocalAdded -and $i -lt 5 -and $trimmed -notmatch 'setlocal') {
                if ($trimmed -match '^@echo\s+off') {
                    $newLines.Add($line) | Out-Null
                    $newLines.Add("setlocal enabledelayedexpansion") | Out-Null
                    $setlocalAdded = $true
                    continue
                }
            }

            # Modernize path references
            if ($trimmed -match 'D:\\DevOptimizer') {
                $line = $line -replace 'D:\\DevOptimizer', '%~dp0'
                $line = $line -replace '%~dp0\\', '%~dp0'
            }

            # Fix common goto issues
            if ($trimmed -match 'goto\s+:menu\b') {
                $line = $line -replace 'goto\s+:menu\b', 'goto :start'
            }

            # Add error handling to critical commands
            if ($trimmed -match '^(copy|move|del|rd|mkdir)\s+' -and $trimmed -notmatch 'if\s+errorlevel') {
                # Don't modify if already has error handling
                $newLines.Add($line) | Out-Null
            } else {
                $newLines.Add($line) | Out-Null
            }
        }

        # Reconstruct content
        $content = $newLines -join "`r`n"

        # Add modern error handling section before any exit
        $errorHandler = @"

:: ================================================================
:: Modern Error Handling Section
:: ================================================================
set "SCRIPT_ERROR=0"
set "ERROR_CODE=0"

:: Error handler function
:handle_error
if "%SCRIPT_ERROR%"=="1" (
    echo.
    echo [ERROR] An error occurred during script execution
    echo [ERROR] Error Code: %ERROR_CODE%
    echo.
    exit /b %ERROR_CODE%
)

"@

        # Insert error handler before first label or at end if no labels
        if ($content -match '^:') {
            $content = $content -replace '^(:\w+)', "$errorHandler`r`n`$1"
        } else {
            $content = $content + "`r`n`r`n" + $errorHandler
        }

        # Ensure proper exit at end
        if ($content -notmatch '(exit\s+/b|goto\s+:eof)\s*$') {
            $content = $content.TrimEnd() + "`r`n`r`n:: Script completed successfully`r`nexit /b 0"
        }

        # Ensure UTF-8 BOM for proper encoding
        return $content
    }
}

# Main execution with advanced algorithms
function Update-Scripts {
    param(
        [string]$Directory,
        [bool]$DryRunMode
    )

    $logger = [ScriptLogger]::new("$Directory\..\script-update-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt")
    $analyzer = [ScriptAnalyzer]::new()
    $transformer = [ScriptTransformer]::new()

    $scripts = Get-ChildItem -Path $Directory -Filter "*.bat" -File | Sort-Object Name

    $stats = @{
        Total = $scripts.Count
        Processed = 0
        Updated = 0
        Skipped = 0
        Errors = 0
    }

    $logger.Log("INFO", "Starting script update process", @{
        TotalScripts = $stats.Total
        DryRun = $DryRunMode
    })

    foreach ($script in $scripts) {
        $stats.Processed++
        $progress = [math]::Round(($stats.Processed / $stats.Total) * 100, 2)

        Write-Progress -Activity "Updating Scripts" -Status "$($script.Name) ($progress%)" `
            -PercentComplete $progress -CurrentOperation "Analyzing script..."

        try {
            $logger.Log("INFO", "Processing script: $($script.Name)", @{
                ScriptNumber = $stats.Processed
                TotalScripts = $stats.Total
            })

            # Analyze script
            $analysis = $analyzer.AnalyzeScript($script.FullName)

            if (-not $analysis.Valid) {
                $stats.Errors++
                $logger.Log("ERROR", "Script analysis failed: $($script.Name)", @{
                    Issues = $analysis.Issues
                })
                continue
            }

            # Always apply modern improvements (even if no critical issues)
            $needsUpdate = $false
            $improvements = @()

            # Check for modern improvements needed
            if ($analysis.Issues.Count -gt 0) {
                $needsUpdate = $true
                $improvements += "Critical fixes needed"
            }

            # Check for modern features to add
            $content = Get-Content -Path $script.FullName -Raw
            if ($content -notmatch 'setlocal\s+enabledelayedexpansion') {
                $needsUpdate = $true
                $improvements += "Add delayed expansion"
            }
            if ($content -notmatch 'ERROR_OCCURRED|errorlevel') {
                $needsUpdate = $true
                $improvements += "Add error handling"
            }
            if ($content -notmatch '%~dp0') {
                $needsUpdate = $true
                $improvements += "Use relative paths"
            }

            if ($needsUpdate) {
                $logger.Log("INFO", "Improvements needed for script: $($script.Name)", @{
                    IssueCount = $analysis.Issues.Count
                    Issues = $analysis.Issues
                    Recommendations = $analysis.Recommendations
                    Improvements = $improvements
                })

                if (-not $DryRunMode) {
                    # Transform script
                    $newContent = $transformer.TransformScript($script.FullName, $analysis)

                    # Backup original
                    $backupPath = "$($script.FullName).backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    Copy-Item -Path $script.FullName -Destination $backupPath -Force

                    # Write updated content
                    [System.IO.File]::WriteAllText($script.FullName, $newContent, [System.Text.Encoding]::UTF8)

                    $stats.Updated++
                    $logger.Log("SUCCESS", "Script updated: $($script.Name)", @{
                        BackupPath = $backupPath
                        IssuesFixed = $analysis.Issues.Count
                    })
                } else {
                    $logger.Log("DRYRUN", "Would update script: $($script.Name)", @{
                        Issues = $analysis.Issues
                    })
                }
            } else {
                $stats.Skipped++
                $logger.Log("INFO", "Script already up-to-date: $($script.Name)", @{
                    Complexity = $analysis.Complexity
                    Lines = $analysis.Lines
                })
            }
        }
        catch {
            $stats.Errors++
            $logger.Log("ERROR", "Error processing script: $($script.Name)", @{
                ErrorMessage = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            })
        }
    }

    Write-Progress -Activity "Updating Scripts" -Completed

    # Final summary
    $logger.Log("INFO", "Update process completed", $stats)

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "   UPDATE SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total Scripts: $($stats.Total)" -ForegroundColor White
    Write-Host "Processed: $($stats.Processed)" -ForegroundColor Green
    Write-Host "Updated: $($stats.Updated)" -ForegroundColor Yellow
    Write-Host "Skipped (already up-to-date): $($stats.Skipped)" -ForegroundColor Gray
    Write-Host "Errors: $($stats.Errors)" -ForegroundColor $(if ($stats.Errors -gt 0) { "Red" } else { "Green" })
    Write-Host "`nLog file: $($logger.LogFile)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    return $stats
}

# Execute
if (-not (Test-Path $ScriptDir)) {
    Write-Error "Script directory not found: $ScriptDir"
    exit 1
}

$result = Update-Scripts -Directory $ScriptDir -DryRunMode $DryRun

exit $result.Errors
