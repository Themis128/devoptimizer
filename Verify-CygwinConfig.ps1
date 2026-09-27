# Verify Cygwin Bash Configuration in VS Code Insiders

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     VS Code Insiders - Cygwin Bash Configuration Check        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$settingsPath = "$env:APPDATA\Code - Insiders\User\settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

Write-Host "📋 CURRENT CONFIGURATION:`n" -ForegroundColor Yellow

# Check default profile
$defaultProfile = $settings."terminal.integrated.defaultProfile.windows"
Write-Host "Default Terminal Profile:" -ForegroundColor Gray
if ($defaultProfile -eq "Cygwin Bash") {
    Write-Host "  ✓ Cygwin Bash" -ForegroundColor Green
} else {
    Write-Host "  ✗ $defaultProfile" -ForegroundColor Red
}

# Check Cygwin profile exists
Write-Host "`nCygwin Bash Profile:" -ForegroundColor Gray
if ($settings."terminal.integrated.profiles.windows"."Cygwin Bash") {
    $profile = $settings."terminal.integrated.profiles.windows"."Cygwin Bash"
    Write-Host "  ✓ Profile exists" -ForegroundColor Green
    Write-Host "    Path: $($profile.path)" -ForegroundColor White
    Write-Host "    Args: $($profile.args -join ' ')" -ForegroundColor White
} else {
    Write-Host "  ✗ Profile not found" -ForegroundColor Red
}

# Check Cline integration
Write-Host "`nCline Extension:" -ForegroundColor Gray
$clineShell = $settings."cline.terminalShell"
if ($clineShell -eq "C:\cygwin64\bin\bash.exe") {
    Write-Host "  ✓ Configured for Cygwin Bash" -ForegroundColor Green
} else {
    Write-Host "  ✗ Using: $clineShell" -ForegroundColor Yellow
}

# Check integrated shell
Write-Host "`nIntegrated Shell:" -ForegroundColor Gray
$integratedShell = $settings."terminal.integrated.shell.windows"
if ($integratedShell -eq "C:\cygwin64\bin\bash.exe") {
    Write-Host "  ✓ Configured for Cygwin Bash" -ForegroundColor Green
} else {
    Write-Host "  ℹ Using: $integratedShell" -ForegroundColor Cyan
}

# Check if Cygwin bash actually exists
Write-Host "`nCygwin Installation:" -ForegroundColor Gray
if (Test-Path "C:\cygwin64\bin\bash.exe") {
    Write-Host "  ✓ bash.exe found" -ForegroundColor Green
    $version = & C:\cygwin64\bin\bash.exe --version 2>&1 | Select-Object -First 1
    Write-Host "    $version" -ForegroundColor White
} else {
    Write-Host "  ✗ bash.exe NOT found!" -ForegroundColor Red
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

if ($defaultProfile -eq "Cygwin Bash" -and (Test-Path "C:\cygwin64\bin\bash.exe")) {
    Write-Host "`n✅ Configuration is correct!" -ForegroundColor Green
    Write-Host "   Restart VS Code Insiders to apply changes`n" -ForegroundColor Cyan
} else {
    Write-Host "`n⚠ Configuration needs attention" -ForegroundColor Yellow
    Write-Host "   Run the configuration script again`n" -ForegroundColor Cyan
}
