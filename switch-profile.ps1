# VS Code Insiders Profile Switcher
# Usage: .\switch-profile.ps1 -Profile [test|heavy]

param(
    [ValidateSet('test', 'heavy')]
    [string]$Profile = 'test'
)

$vscode = "code-insiders"

Write-Host ""
Write-Host "Switching VS Code Insiders profile..." -ForegroundColor Cyan

if ($Profile -eq 'test') {
    Write-Host "Profile: Playwright-Test (lightweight)" -ForegroundColor Green
    Write-Host "- Minimal extensions" -ForegroundColor Gray
    Write-Host "- Reduced MCP servers" -ForegroundColor Gray
    Write-Host "- Optimized for testing" -ForegroundColor Gray
    Write-Host ""
    
    & $vscode --profile "Playwright-Test"
} else {
    Write-Host "Profile: Heavy (full development)" -ForegroundColor Yellow
    Write-Host "- All extensions enabled" -ForegroundColor Gray
    Write-Host "- Full MCP server stack" -ForegroundColor Gray
    Write-Host "- Complete development environment" -ForegroundColor Gray
    Write-Host ""
    
    & $vscode --profile "Heavy"
}
