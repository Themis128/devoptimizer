<#
.SYNOPSIS
    Health check and self-healing for DevOptimizer Script Hub

.DESCRIPTION
    Performs comprehensive health checks on the Script Hub installation and can auto-fix common issues.

.PARAMETER AutoFix
    Automatically fix detected issues where possible

.PARAMETER RegistryPath
    Path to hub-registry.json (default: config\hub-registry.json)

.PARAMETER ConfigPath
    Path to hub-config.json (default: config\hub-config.json)

.PARAMETER Verbose
    Show detailed output

.PARAMETER PassThru
    Return health result object instead of exiting

.EXAMPLE
    Check-Health.ps1
    Check-Health.ps1 -AutoFix
    Check-Health.ps1 -AutoFix -Verbose
    Check-Health.ps1 -PassThru | ConvertTo-Json
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [string]$RegistryPath = "config\hub-registry.json",
    [string]$ConfigPath = "config\hub-config.json",
    [switch]$PassThru
)

$RootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ModulesPath = Join-Path $RootPath "modules"
$fullRegistryPath = Join-Path $RootPath $RegistryPath
$fullConfigPath = Join-Path $RootPath $ConfigPath

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
        "FIX" { "[FIX]  " }
        default { "[INFO] " }
    }
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "OK" { "Green" }
        "FIX" { "Cyan" }
        default { "White" }
    }
    if ($Verbose -or $Level -in @("ERROR", "WARN", "FIX")) {
        Write-Color "$prefix $Message" $color
    }
}

$health = @{
    timestamp = (Get-Date).ToString("o")
    checks = @()
    errors = @()
    warnings = @()
    fixes = @()
    score = 0
    maxScore = 0
}

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message,
        [string]$FixAction = $null,
        [bool]$Critical = $true
    )
    $points = if ($Critical) { 10 } else { 5 }
    $health.maxScore += $points
    if ($Passed) {
        $health.score += $points
        $health.checks += @{ name = $Name; passed = $true; message = $Message }
        Write-Log ("{0}: {1}" -f $Name, $Message) "OK"
    } else {
        $health.checks += @{ name = $Name; passed = $false; message = $Message }
        Write-Log ("{0}: {1}" -f $Name, $Message) "ERROR"
        $health.errors += @{ check = $Name; message = $Message; fix = $FixAction; critical = $Critical }
    }
}

function Add-Warning {
    param([string]$Name, [string]$Message, [string]$FixAction = $null)
    $health.maxScore += 5
    $health.score += 3  # Partial credit for warnings
    $health.checks += @{ name = $Name; passed = $true; warning = $true; message = $Message }
    Write-Log ("{0}: {1}" -f $Name, $Message) "WARN"
    $health.warnings += @{ check = $Name; message = $Message; fix = $FixAction }
}

function Try-Fix {
    param([string]$Name, [scriptblock]$FixScript)
    try {
        & $FixScript
        $health.fixes += $Name
        Write-Log ("{0}: Fixed successfully" -f $Name) "FIX"
        return $true
    } catch {
        Write-Log ("{0}: Fix failed - {1}" -f $Name, $_.Exception.Message) "ERROR"
        return $false
    }
}

Write-Color "+==============================================================================+" "Cyan"
Write-Color "| DevOptimizer Script Hub - Health Check                                      |" "Cyan"
Write-Color "+==============================================================================+" "Cyan"
Write-Color ""

# =============================================================================
# CHECK 1: Core files exist
# =============================================================================
$coreFiles = @(
    "DevOptimizer-Master.psm1",
    "DevOptimizer-Config.psm1",
    "DevOptimizer-Path.psm1",
    "DevOptimizer-Admin.psm1",
    "Discover-Scripts.ps1",
    "Build-Registry.ps1",
    "Execute-Command.ps1",
    "Show-Menu.ps1",
    "Get-Category.ps1",
    "Manage-Favorites.ps1"
)

foreach ($file in $coreFiles) {
    # Modules are in modules/ subdirectory, scripts are in root
    if ($file -like "*.psm1") {
        $path = Join-Path $ModulesPath $file
    } else {
        $path = Join-Path $RootPath $file
    }
    Add-Check -Name "CoreFile:$file" -Passed (Test-Path $path) -Message "Core file exists" -FixAction "Re-run installer"
}

# =============================================================================
# CHECK 2: Registry exists and is valid
# =============================================================================
Add-Check -Name "Registry:Exists" -Passed (Test-Path $fullRegistryPath) -Message "Registry file exists" -FixAction "Run Build-Registry.ps1"

if (Test-Path $fullRegistryPath) {
    try {
        $registry = Get-Content $fullRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        Add-Check -Name "Registry:ValidJson" -Passed $true -Message "Registry is valid JSON"
        
        # Check registry structure
        $hasCommands = $registry.commands -and $registry.commands.Count -gt 0
        Add-Check -Name "Registry:HasCommands" -Passed $hasCommands -Message "Registry has $($registry.commands.Count) commands" -FixAction "Run Build-Registry.ps1"
        
        $hasCategories = $registry.categories -and $registry.categories.Count -gt 0
        Add-Check -Name "Registry:HasCategories" -Passed $hasCategories -Message "Registry has $($registry.categories.Count) categories" -FixAction "Run Build-Registry.ps1"
        
        $hasVersion = $registry.version -ne $null
        Add-Check -Name "Registry:HasVersion" -Passed $hasVersion -Message "Registry has version: $($registry.version)" -Critical $false
        
        # Check for duplicate command IDs
        $ids = $registry.commands | ForEach-Object { $_.name }
        $duplicates = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
        $noDuplicates = $duplicates.Count -eq 0
        Add-Check -Name "Registry:UniqueIds" -Passed $noDuplicates -Message "No duplicate command IDs" -FixAction "Rebuild registry" -Critical $false
        
    } catch {
        Add-Check -Name "Registry:ValidJson" -Passed $false -Message "Registry JSON parse error: $($_.Exception.Message)" -FixAction "Run Build-Registry.ps1"
    }
}

# =============================================================================
# CHECK 3: Config exists and is valid
# =============================================================================
Add-Check -Name "Config:Exists" -Passed (Test-Path $fullConfigPath) -Message "Config file exists" -FixAction "Run initial setup" -Critical $false

if (Test-Path $fullConfigPath) {
    try {
        $config = Get-Content $fullConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        Add-Check -Name "Config:ValidJson" -Passed $true -Message "Config is valid JSON" -Critical $false
    } catch {
        Add-Check -Name "Config:ValidJson" -Passed $false -Message "Config JSON parse error: $($_.Exception.Message)" -FixAction "Recreate config" -Critical $false
    }
}

# =============================================================================
# CHECK 4: Module loading
# =============================================================================
$modulePath = Join-Path $ModulesPath "DevOptimizer-Master.psm1"
if (Test-Path $modulePath) {
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Add-Check -Name "Module:MasterLoads" -Passed $true -Message "Master module loads successfully"
        
        # Test -LoadHub parameter
        try {
            Import-Module $modulePath -Force -ArgumentList @("-LoadHub") -ErrorAction Stop
            Add-Check -Name "Module:LoadHub" -Passed $true -Message "LoadHub parameter works"
        } catch {
            Add-Check -Name "Module:LoadHub" -Passed $false -Message "LoadHub parameter failed" -Critical $false
        }
    } catch {
        Add-Check -Name "Module:MasterLoads" -Passed $false -Message "Master module load failed: $($_.Exception.Message)" -FixAction "Check module syntax"
    }
}

# =============================================================================
# CHECK 5: Sub-modules
# =============================================================================
$subModules = @("DevOptimizer-Config", "DevOptimizer-Path", "DevOptimizer-Admin")
foreach ($mod in $subModules) {
    $modPath = Join-Path $ModulesPath "$mod.psm1"
    if (Test-Path $modPath) {
        try {
            Import-Module $modPath -Force -ErrorAction Stop
            Add-Check -Name "Module:$mod" -Passed $true -Message "$mod loads successfully"
        } catch {
            Add-Check -Name "Module:$mod" -Passed $false -Message "$mod load failed: $($_.Exception.Message)" -Critical $false
        }
    } else {
        Add-Check -Name "Module:$mod" -Passed $false -Message "$mod not found" -Critical $false
    }
}

# =============================================================================
# CHECK 6: Script directories exist
# =============================================================================
$scriptDirs = @(
    "scripts",
    "BAT",
    "portable",
    "py"
)

foreach ($dir in $scriptDirs) {
    $fullDir = Join-Path $RootPath $dir
    $exists = Test-Path $fullDir -PathType Container
    Add-Check -Name "ScriptDir:$dir" -Passed $exists -Message "Script directory exists" -Critical $false
    if (-not $exists -and $AutoFix) {
        Try-Fix -Name "CreateDir:$dir" -FixScript { New-Item -ItemType Directory -Path $fullDir -Force | Out-Null }
    }
}

# =============================================================================
# CHECK 7: Log directory
# =============================================================================
$logDir = Join-Path $RootPath "logs"
$logExists = Test-Path $logDir -PathType Container
Add-Check -Name "LogDir:Exists" -Passed $logExists -Message "Log directory exists" -Critical $false
if (-not $logExists -and $AutoFix) {
    Try-Fix -Name "CreateLogDir" -FixScript { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
}

# =============================================================================
# CHECK 8: Favorites file
# =============================================================================
$favPath = Join-Path $RootPath "config\favorites.json"
$favExists = Test-Path $favPath
Add-Check -Name "Favorites:Exists" -Passed $favExists -Message "Favorites file exists" -Critical $false
if (-not $favExists -and $AutoFix) {
    Try-Fix -Name "CreateFavoritesFile" -FixScript { @{ favorites = @() } | ConvertTo-Json | Set-Content -Path $favPath -Encoding UTF8 }
}

# =============================================================================
# CHECK 9: PowerShell version
# =============================================================================
$psVersion = $PSVersionTable.PSVersion.Major
$psOk = $psVersion -ge 5
Add-Check -Name "Environment:PowerShellVersion" -Passed $psOk -Message "PowerShell $psVersion (requires 5.1+)" -Critical $false

# =============================================================================
# CHECK 10: Admin rights (for commands requiring admin)
# =============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$adminMsg = if ($isAdmin) { "Running as Administrator" } else { "Not running as Administrator (some commands need elevation)" }
Add-Check -Name "Environment:AdminRights" -Passed $isAdmin -Message $adminMsg -Critical $false

# =============================================================================
# CHECK 11: Git available
# =============================================================================
$gitPath = (Get-Command git -ErrorAction SilentlyContinue).Source
$gitOk = $gitPath -ne $null
$gitMsg = if ($gitOk) { "Git found at $gitPath" } else { "Git not in PATH" }
Add-Check -Name "Environment:Git" -Passed $gitOk -Message $gitMsg -Critical $false

# =============================================================================
# CHECK 12: Python available
# =============================================================================
$pyPath = (Get-Command python -ErrorAction SilentlyContinue).Source
$pyOk = $pyPath -ne $null
$pyMsg = if ($pyOk) { "Python found at $pyPath" } else { "Python not in PATH" }
Add-Check -Name "Environment:Python" -Passed $pyOk -Message $pyMsg -Critical $false

# =============================================================================
# CHECK 13: Registry freshness
# =============================================================================
if (Test-Path $fullRegistryPath) {
    $registryTime = (Get-Item $fullRegistryPath).LastWriteTime
    $ageHours = (Get-Date) - $registryTime | Select-Object -ExpandProperty TotalHours
    $fresh = $ageHours -lt 24
    Add-Check -Name "Registry:Freshness" -Passed $fresh -Message "Registry age: $([math]::Round($ageHours, 1)) hours" -Critical $false
    if (-not $fresh -and $AutoFix) {
        Try-Fix -Name "RebuildRegistry" -FixScript { & "$RootPath\Build-Registry.ps1" -Validate -Force }
    }
}

# =============================================================================
# CHECK 14: Schema validation
# =============================================================================
$schemaPath = Join-Path $RootPath "config\schemas\hub-registry.schema.json"
if ((Test-Path $schemaPath) -and (Test-Path $fullRegistryPath)) {
    $validatorPath = Join-Path $RootPath "Validate-JsonSchema.ps1"
    if (Test-Path $validatorPath) {
        try {
            $result = & $validatorPath -Schema $schemaPath -Json $fullRegistryPath -ErrorAction Stop
            $valid = $result -match "VALID"
            $validMsg = if ($valid) { "Schema validation passed" } else { "Schema validation failed" }
            Add-Check -Name "Registry:SchemaValid" -Passed $valid -Message $validMsg -FixAction "Run Build-Registry.ps1 -Validate -Force"
        } catch {
            Add-Check -Name "Registry:SchemaValid" -Passed $false -Message "Schema validation error: $($_.Exception.Message)" -FixAction "Run Build-Registry.ps1 -Validate -Force"
        }
    } else {
        Add-Warning -Name "Registry:SchemaValidator" -Message "Validator script not found, skipping schema check"
    }
}

# =============================================================================
# CHECK 15: Command script files exist
# =============================================================================
if ($registry -and $registry.commands) {
    $missingScripts = 0
    foreach ($cmd in $registry.commands) {
        $scriptPath = Join-Path $RootPath $cmd.path
        if (-not (Test-Path $scriptPath)) {
            $missingScripts++
            if ($missingScripts -le 5) {
                Write-Log "Missing script: $($cmd.path) for command $($cmd.name)" "WARN"
            }
        }
    }
    $allPresent = $missingScripts -eq 0
    $scriptsMsg = if ($allPresent) { "All command scripts exist" } else { "$missingScripts command scripts missing" }
    Add-Check -Name "Commands:ScriptFilesExist" -Passed $allPresent -Message $scriptsMsg -FixAction "Run Discover-Scripts.ps1 and rebuild"
}

# =============================================================================
# Summary
# =============================================================================
$percentage = if ($health.maxScore -gt 0) { [math]::Round(($health.score / $health.maxScore) * 100) } else { 0 }

$scoreColor = if ($percentage -ge 80) { "Green" } elseif ($percentage -ge 50) { "Yellow" } else { "Red" }
$errorColor = if ($health.errors.Count -eq 0) { "Green" } else { "Red" }
$warnColor = if ($health.warnings.Count -eq 0) { "Green" } else { "Yellow" }

Write-Color ""
Write-Color "+==============================================================================+" "Cyan"
Write-Color "| Health Check Summary                                                          |" "Cyan"
Write-Color "+==============================================================================+" "Cyan"
Write-Color ""
Write-Color "Score: $($health.score) / $($health.maxScore) ($percentage%)" $scoreColor
Write-Color "Errors: $($health.errors.Count)" $errorColor
Write-Color "Warnings: $($health.warnings.Count)" $warnColor
Write-Color "Fixes Applied: $($health.fixes.Count)" "Cyan"
Write-Color ""

if ($health.errors.Count -gt 0) {
    Write-Color "Errors:" "Red"
    foreach ($err in $health.errors) {
        Write-Color "  [X] $($err.check): $($err.message)" "Red"
        if ($err.fix) { Write-Color "      Fix: $($err.fix)" "Yellow" }
    }
    Write-Color ""
}

if ($health.warnings.Count -gt 0) {
    Write-Color "Warnings:" "Yellow"
    foreach ($warn in $health.warnings) {
        Write-Color "  [!] $($warn.check): $($warn.message)" "Yellow"
        if ($warn.fix) { Write-Color "      Fix: $($warn.fix)" "Yellow" }
    }
    Write-Color ""
}

if ($health.fixes.Count -gt 0) {
    Write-Color "Fixes Applied:" "Cyan"
    foreach ($fix in $health.fixes) {
        Write-Color "  [+] $fix" "Cyan"
    }
    Write-Color ""
}

if ($AutoFix -and $health.errors.Count -gt 0) {
    Write-Color "Auto-fix attempted. Re-run health check to verify." "Cyan"
}

if ($PassThru) {
    return $health
}

if ($health.errors.Count -gt 0) {
    exit 1
}
exit 0