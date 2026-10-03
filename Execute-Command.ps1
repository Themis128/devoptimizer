<#
.SYNOPSIS
    DevOptimizer Script Hub - Command Execution Wrapper
    Executes a registered command from the hub registry with proper parameter handling, logging, and error reporting.

.DESCRIPTION
    This script loads the hub registry, finds the specified command by name or ID, validates parameters,
    handles admin elevation if required, executes the command with proper logging, and returns structured output.
    Supports all script types: PowerShell, Batch, Python, Bash (WSL), Node.js.

.PARAMETER Command
    Name or ID of the command to execute (from registry).

.PARAMETER Parameters
    Hashtable of parameters to pass to the command.

.PARAMETER RegistryPath
    Path to hub-registry.json. Defaults to config\hub-registry.json

.PARAMETER LogPath
    Directory for execution logs. Defaults to logs\executions

.PARAMETER Timeout
    Execution timeout in seconds. Default: 300 (5 minutes).

.PARAMETER NoAdminCheck
    Skip admin privilege check (use with caution).

.PARAMETER DryRun
    Show what would be executed without actually running.

.PARAMETER PassThru
    Return execution result object instead of writing to console.

.EXAMPLE
    .\Execute-Command.ps1 -Command "optimize-memory" -Parameters @{ "Aggressive" = $true }

.EXAMPLE
    .\Execute-Command.ps1 -Command "system-health-check" -Timeout 600 -PassThru

.EXAMPLE
    .\Execute-Command.ps1 -Command "backup-configs" -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$Command,

    [Parameter(Position=1)]
    [hashtable]$Parameters = @{},

    [Parameter()]
    [string]$RegistryPath = "config\hub-registry.json",

    [Parameter()]
    [string]$LogPath = "logs\executions",

    [Parameter()]
    [int]$Timeout = 300,

    [Parameter()]
    [switch]$NoAdminCheck,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$PassThru
)

$RootPath = "D:\DevOptimizer"
$fullRegistryPath = Join-Path $RootPath $RegistryPath
$fullLogPath = Join-Path $RootPath $LogPath

# Create log directory if needed
if (-not (Test-Path $fullLogPath)) {
    New-Item -ItemType Directory -Path $fullLogPath -Force | Out-Null
}

$logFile = Join-Path $fullLogPath ("execution-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
$executionId = [Guid]::NewGuid().ToString()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $logEntry = "[$timestamp] [$Level] [$executionId] $Message"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    $color = "Green"
    if ($Level -eq "ERROR") { $color = "Red" }
    elseif ($Level -eq "WARN") { $color = "Yellow" }
    elseif ($Level -eq "DEBUG") { $color = "Gray" }
    Write-Host $logEntry -ForegroundColor $color
}

Write-Log "Starting execution of command: $Command"

# Load registry
if (-not (Test-Path $fullRegistryPath)) {
    Write-Log "Registry not found at: $fullRegistryPath" "ERROR"
    $result = @{
        success = $false
        error = "Registry not found. Run Build-Registry.ps1 first."
        executionId = $executionId
        logFile = $logFile
    }
    if ($PassThru) { return $result } else { exit 1 }
}

$registry = Get-Content $fullRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Find command by name or ID
$cmd = $registry.commands | Where-Object { $_.name -eq $Command -or $_.name -eq $Command.ToLower() }
if (-not $cmd) {
    # Try case-insensitive match on name
    $cmd = $registry.commands | Where-Object { $_.name -ieq $Command }
}
if (-not $cmd) {
    Write-Log "Command not found in registry: $Command" "ERROR"
    $available = $registry.commands | Select-Object -ExpandProperty name | Sort-Object
    Write-Log "Available commands: $($available -join ', ')" "DEBUG"
    $result = @{
        success = $false
        error = "Command '$Command' not found in registry"
        executionId = $executionId
        logFile = $logFile
        availableCommands = $available
    }
    if ($PassThru) { return $result } else { exit 1 }
}

Write-Log "Found command: $($cmd.name) (Category: $($cmd.category), Type: $($cmd.entryPoint))"

# Check admin requirement
if ($cmd.requiresAdmin -and -not $NoAdminCheck) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Command requires admin privileges, re-launching elevated..." "WARN"

        # Re-launch elevated. The child command ships base64-encoded (-EncodedCommand):
        # a plain -Command re-quote broke on empty hashtables ({} binds as a ScriptBlock
        # and the child crashed invisibly at parameter binding while this parent still
        # reported success). The child deserializes the JSON itself - a string cannot
        # bind [hashtable] directly.
        $json = if ($Parameters.Count) { $Parameters | ConvertTo-Json -Compress } else { '{}' }
        $json = $json.Replace("'", "''")
        # Child logs into a dedicated subdir keyed by THIS parent's executionId, so the
        # parent can forward the child's captured output unambiguously even when several
        # elevated runs overlap (each parent reads only its own subdir).
        $childLogPath = "logs\executions\elevated-$executionId"
        $child = "`$p = @{}; ('$json' | ConvertFrom-Json).PSObject.Properties | ForEach-Object { `$p[`$_.Name] = `$_.Value }; " +
                 "& '$PSCommandPath' -Command '$Command' -Parameters `$p -RegistryPath '$RegistryPath' -LogPath '$childLogPath' -Timeout $Timeout -NoAdminCheck"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($child))
        $elevated = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded) -Verb RunAs -Wait -PassThru -WindowStyle Hidden

        # Forward the elevated child's captured output into this process's output stream:
        # the app-runner path captures streams (*>&1) into the per-run log, and without
        # this the run log shows only the relaunch marker while the scan output stays in
        # the child's own execution log.
        $childDir = Join-Path $RootPath $childLogPath
        $childStdoutFile = Get-ChildItem $childDir -Filter 'execution-*.log.stdout' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($childStdoutFile) {
            $childStdout = Get-Content $childStdoutFile.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $childStderrPath = $childStdoutFile.FullName -replace '\.stdout$', '.stderr'
            $childStderr = Get-Content $childStderrPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($childStdout) { "=== ELEVATED CHILD STDOUT ==="; $childStdout }
            if ($childStderr) { "=== ELEVATED CHILD STDERR ==="; $childStderr }
            Write-Log "Elevated child output forwarded from $childLogPath" "DEBUG"
        }

        # The elevated child re-runs this script (its log lands in LogPath); propagate
        # its real exit code instead of unconditional success.
        $result = @{
            success = ($elevated.ExitCode -eq 0)
            elevated = $true
            exitCode = $elevated.ExitCode
            message = "Command relaunched with admin privileges"
            executionId = $executionId
            logFile = $logFile
        }
        if ($elevated.ExitCode -ne 0) {
            Write-Log "Elevated child exited with code $($elevated.ExitCode)" "ERROR"
            $result.error = "Elevated child exited with code $($elevated.ExitCode)"
        }
        if ($PassThru) { return $result } else {
            if ($elevated.ExitCode -ne 0) { exit 1 }
            exit 0
        }
    }
}

# Build parameter arguments
$paramArgs = @()
foreach ($param in $cmd.parameters) {
    $paramName = $param.name
    $paramValue = $Parameters[$paramName]
    
    if ($param.required -and (-not $Parameters.ContainsKey($paramName))) {
        Write-Log "Required parameter missing: $paramName" "ERROR"
        $result = @{
            success = $false
            error = "Required parameter '$paramName' is missing"
            executionId = $executionId
            logFile = $logFile
        }
        if ($PassThru) { return $result } else { exit 1 }
    }
    
    if ($Parameters.ContainsKey($paramName)) {
        switch ($param.type) {
            "boolean" {
                if ($paramValue -eq $true) { $paramArgs += "-$paramName" }
            }
            "array" {
                if ($paramValue -is [array]) {
                    foreach ($v in $paramValue) { $paramArgs += ("-{0}:{1}" -f $paramName, $v) }
                } else {
                    $paramArgs += ("-{0}:{1}" -f $paramName, $paramValue)
                }
            }
            default {
                $paramArgs += ("-{0}:{1}" -f $paramName, $paramValue)
            }
        }
    }
}

# Add any extra parameters not in schema
foreach ($key in $Parameters.Keys) {
    if (-not ($cmd.parameters | Where-Object { $_.name -eq $key })) {
        $paramArgs += ("-{0}:{1}" -f $key, $Parameters[$key])
    }
}

# Resolve script path
$scriptPath = Join-Path $RootPath $cmd.path
if (-not (Test-Path $scriptPath)) {
    Write-Log "Script file not found: $scriptPath" "ERROR"
    $result = @{
        success = $false
        error = "Script file not found: $scriptPath"
        executionId = $executionId
        logFile = $logFile
    }
    if ($PassThru) { return $result } else { exit 1 }
}

# Build execution command based on entry point
$interpreter = ""
$scriptArgs = @()

switch ($cmd.entryPoint) {
    "powershell" {
        $interpreter = "powershell"
        $scriptArgs = @("-ExecutionPolicy", "Bypass", "-File", $scriptPath) + $paramArgs
    }
    "cmd" {
        $interpreter = "cmd.exe"
        $scriptArgs = @("/c", $scriptPath) + $paramArgs
    }
    "python" {
        $interpreter = "python"
        $scriptArgs = @($scriptPath) + $paramArgs
    }
    "bash" {
        $interpreter = "wsl"
        $scriptArgs = @("bash", $scriptPath) + $paramArgs
    }
    "node" {
        $interpreter = "node"
        $scriptArgs = @($scriptPath) + $paramArgs
    }
    "wsl" {
        $interpreter = "wsl"
        $scriptArgs = @($scriptPath) + $paramArgs
    }
    default {
        $interpreter = "powershell"
        $scriptArgs = @("-ExecutionPolicy", "Bypass", "-File", $scriptPath) + $paramArgs
    }
}

$fullCmd = "$interpreter $($scriptArgs -join ' ')"
Write-Log "Execution command: $fullCmd"

if ($DryRun) {
    Write-Host "[DRY RUN] Would execute: $fullCmd" -ForegroundColor Cyan
    $result = @{
        success = $true
        dryRun = $true
        command = $fullCmd
        executionId = $executionId
        logFile = $logFile
    }
    if ($PassThru) { return $result } else { exit 0 }
}

# Execute with timeout and logging
$stdoutLog = $logFile + ".stdout"
$stderrLog = $logFile + ".stderr"
Write-Log "Starting process: $interpreter $($scriptArgs -join ' ')"
$startTime = Get-Date

try {
    $process = Start-Process -FilePath $interpreter -ArgumentList $scriptArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
    $exitCode = $process.ExitCode
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Log "Process exited with code: $exitCode (Duration: $("{0:N2}" -f $duration)s)"
    
    # Read output from logs
    $stdout = Get-Content $stdoutLog -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    $stderr = Get-Content $stderrLog -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    $output = $stdout + $stderr
    
    # Combine into main log
    Add-Content -Path $logFile -Value "=== STDOUT ===" -Encoding UTF8
    Add-Content -Path $logFile -Value $stdout -Encoding UTF8
    Add-Content -Path $logFile -Value "=== STDERR ===" -Encoding UTF8
    Add-Content -Path $logFile -Value $stderr -Encoding UTF8

    # Forward to the output stream: app-run runners capture the invoked script's
    # streams (*>&1), so without this the per-run log shows only the structured
    # INFO lines while the script's own output stays confined to $logFile.
    # -PassThru callers must get exactly the result object (its .output field
    # already carries this text) — extra stream objects would wrap it in an array.
    if (-not $PassThru) {
        if ($stdout) { $stdout }
        if ($stderr) { $stderr }
    }
    
    $result = @{
        success = ($exitCode -eq 0)
        exitCode = $exitCode
        duration = $duration
        executionId = $executionId
        logFile = $logFile
        command = $cmd.name
        output = $output
    }
    
    if ($exitCode -ne 0) {
        Write-Log "Command failed with exit code $exitCode" "ERROR"
        $result.error = "Command exited with code $exitCode"
    }
    
} catch {
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    Write-Log "Execution exception: $($_.Exception.Message)" "ERROR"
    $result = @{
        success = $false
        error = $_.Exception.Message
        duration = $duration
        executionId = $executionId
        logFile = $logFile
        command = $cmd.name
    }
}

if ($result.success) {
    Write-Log "Command completed successfully"
} else {
    Write-Log "Command failed: $($result.error)" "ERROR"
}

if ($PassThru) { return $result } else { 
    if (-not $result.success) { exit 1 } 
}