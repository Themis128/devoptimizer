$errors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    'D:\DevOptimizer\SystemCleanup_v5.ps1',
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -eq 0) {
    Write-Host "Syntax OK - No errors found" -ForegroundColor Green
} else {
    Write-Host "Found $($errors.Count) syntax errors:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Yellow
    }
}
