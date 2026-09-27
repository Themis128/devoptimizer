# Comprehensive Script Validation Tool
# Validates PowerShell (.ps1) and Batch (.bat) scripts for syntax errors

param(
    [string]$Path = "D:\DevOptimizer",
    [string]$OutputFile = "script-validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
)

$ErrorActionPreference = "Continue"
$results = @{
    PowerShell = @{
        Total = 0
        Valid = 0
        Invalid = 0
        Errors = @()
    }
    Batch = @{
        Total = 0
        Valid = 0
        Invalid = 0
        Errors = @()
    }
}

function Test-PowerShellSyntax {
    param([string]$FilePath)

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)

        if ($errors.Count -eq 0) {
            return @{ Valid = $true; Errors = @() }
        } else {
            $errorMessages = $errors | ForEach-Object {
                "$($_.Message) (Line $($_.Extent.StartLineNumber), Column $($_.Extent.StartColumnNumber))"
            }
            return @{ Valid = $false; Errors = $errorMessages }
        }
    }
    catch {
        return @{ Valid = $false; Errors = @($_.Exception.Message) }
    }
}

function Test-BatchSyntax {
    param([string]$FilePath)

    $errors = @()

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        $lines = [System.IO.File]::ReadAllLines($FilePath)

        # Corrupted-file detection: script flattened onto one giant line
        # (newlines stripped during variant generation). Legitimate long lines
        # (e.g. AI-prompt call arguments) only occur in files with real structure.
        $maxLen = 0
        foreach ($ln in $lines) { if ($ln.Length -gt $maxLen) { $maxLen = $ln.Length } }
        if ($lines.Count -ge 1 -and $lines.Count -lt 25 -and $maxLen -gt 400) {
            return @{ Valid = $false; Errors = @("Flattened single-line content (corrupted): $($lines.Count) lines, longest $maxLen chars") }
        }

        # Paren/quote balance on "code" lines only:
        # - lines beginning with echo/rem/::/title are literal text, not block structure
        # - parens inside double-quoted spans are literal arguments/prompts, not block structure
        # Note: quote PARITY is deliberately not a failure condition — batch's legal
        # `set "VAR=value` (unclosed-quote) idiom makes odd quote counts normal.
        $openParens = 0
        $closeParens = 0
        foreach ($ln in $lines) {
            if ($ln -match '^\s*@?\s*(echo(\.|$|\s)|rem\b|::|title\b)') { continue }
            $codePart = [regex]::Replace($ln, '"[^"]*"', '""')
            $openParens  += ([regex]::Matches($codePart, '\(')).Count
            $closeParens += ([regex]::Matches($codePart, '\)')).Count
        }
        if ($openParens -ne $closeParens) {
            $errors += "Unmatched parentheses: $openParens open, $closeParens close (code lines, quoted spans excluded)"
        }

        # Check for common syntax errors
        if ($content -match 'goto\s+:\s*$') {
            $errors += "Invalid goto statement (goto with no label)"
        }

        # Check for invalid label syntax
        $invalidLabels = [regex]::Matches($content, '^:\s*$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($invalidLabels.Count -gt 0) {
            $errors += "Found empty label(s)"
        }

        # Try to parse with cmd.exe (basic validation)
        $testResult = cmd /c "exit /b 0" 2>&1
        if ($LASTEXITCODE -ne 0) {
            # This is just a basic check, not comprehensive
        }

        return @{ Valid = ($errors.Count -eq 0); Errors = $errors }
    }
    catch {
        return @{ Valid = $false; Errors = @($_.Exception.Message) }
    }
}

function Write-Report {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $OutputFile -Value $Message -ErrorAction SilentlyContinue
}

# Start validation
Write-Report "================================================================="
Write-Report "SCRIPT VALIDATION REPORT"
Write-Report "================================================================="
Write-Report "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Report "Path: $Path"
Write-Report ""

# Validate PowerShell scripts
Write-Report "Validating PowerShell scripts (.ps1)..."
Write-Report ""

$ps1Files = Get-ChildItem -Path $Path -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch '\\node_modules\\' -and
        $_.FullName -notmatch '\\\.git\\' -and
        $_.FullName -notmatch '\\backups\\' -and
        $_.FullName -notmatch '\\archive\\'
    }

foreach ($file in $ps1Files) {
    $results.PowerShell.Total++
    $relativePath = $file.FullName.Replace($Path, "").TrimStart('\')

    $validation = Test-PowerShellSyntax -FilePath $file.FullName

    if ($validation.Valid) {
        $results.PowerShell.Valid++
        Write-Report "[OK] $relativePath"
    } else {
        $results.PowerShell.Invalid++
        $errorMsg = ($validation.Errors -join "; ")
        $results.PowerShell.Errors += @{
            File = $relativePath
            Errors = $validation.Errors
        }
        Write-Report "[ERROR] $relativePath"
        Write-Report "        $errorMsg"
    }
}

Write-Report ""
Write-Report "Validating Batch scripts (.bat)..."
Write-Report ""

$batFiles = Get-ChildItem -Path $Path -Filter "*.bat" -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch '\\node_modules\\' -and
        $_.FullName -notmatch '\\\.git\\' -and
        $_.FullName -notmatch '\\backups\\' -and
        $_.FullName -notmatch '\\archive\\' -and
        $_.FullName -notmatch '\.corrupted\.bak$' -and
        $_.FullName -notmatch '\.backup-'
    }

foreach ($file in $batFiles) {
    $results.Batch.Total++
    $relativePath = $file.FullName.Replace($Path, "").TrimStart('\')

    $validation = Test-BatchSyntax -FilePath $file.FullName

    if ($validation.Valid) {
        $results.Batch.Valid++
        Write-Report "[OK] $relativePath"
    } else {
        $results.Batch.Invalid++
        $errorMsg = ($validation.Errors -join "; ")
        $results.Batch.Errors += @{
            File = $relativePath
            Errors = $validation.Errors
        }
        Write-Report "[ERROR] $relativePath"
        Write-Report "        $errorMsg"
    }
}

# Summary
Write-Report ""
Write-Report "================================================================="
Write-Report "SUMMARY"
Write-Report "================================================================="
Write-Report "PowerShell Scripts:"
Write-Report "  Total: $($results.PowerShell.Total)"
Write-Report "  Valid: $($results.PowerShell.Valid)"
Write-Report "  Invalid: $($results.PowerShell.Invalid)"
Write-Report ""
Write-Report "Batch Scripts:"
Write-Report "  Total: $($results.Batch.Total)"
Write-Report "  Valid: $($results.Batch.Valid)"
Write-Report "  Invalid: $($results.Batch.Invalid)"
Write-Report ""

$totalScripts = $results.PowerShell.Total + $results.Batch.Total
$totalValid = $results.PowerShell.Valid + $results.Batch.Valid
$totalInvalid = $results.PowerShell.Invalid + $results.Batch.Invalid

Write-Report "Overall:"
Write-Report "  Total Scripts: $totalScripts"
Write-Report "  Valid: $totalValid"
Write-Report "  Invalid: $totalInvalid"

if ($totalInvalid -gt 0) {
    Write-Report ""
    Write-Report "================================================================="
    Write-Report "DETAILED ERROR REPORT"
    Write-Report "================================================================="

    if ($results.PowerShell.Errors.Count -gt 0) {
        Write-Report ""
        Write-Report "PowerShell Script Errors:"
        foreach ($errItem in $results.PowerShell.Errors) {
            Write-Report "  File: $($errItem.File)"
            foreach ($err in $errItem.Errors) {
                Write-Report "    - $err"
            }
        }
    }

    if ($results.Batch.Errors.Count -gt 0) {
        Write-Report ""
        Write-Report "Batch Script Errors:"
        foreach ($errItem in $results.Batch.Errors) {
            Write-Report "  File: $($errItem.File)"
            foreach ($err in $errItem.Errors) {
                Write-Report "    - $err"
            }
        }
    }
}

Write-Report ""
Write-Report "Report saved to: $OutputFile"
Write-Report "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Report "================================================================="

# Return exit code
if ($totalInvalid -eq 0) {
    exit 0
} else {
    exit 1
}
