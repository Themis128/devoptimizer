<#
.SYNOPSIS
    Add a command to the Devin FCFS queue for execution on next session start.

.DESCRIPTION
    This helper function allows users to enqueue commands that will be executed
    in First-Come-First-Served order when Devin Desktop starts. The queue persists
    across restarts via file-backed state.

.PARAMETER Command
    The command to execute (e.g., "fix the issue in the app folder").

.PARAMETER WorkingDir
    Optional working directory for the command. Defaults to the DevOptimizer repo root.

.PARAMETER Description
    Optional human-readable description of what this command does.

.PARAMETER MaxRetries
    Maximum retry attempts for the command. Defaults to 3.

.EXAMPLE
    Add-DevinQueue -Command "fix the authentication bug in login page" -Description "Fix login authentication"

.EXAMPLE
    Add-DevinQueue -Command "run all tests" -WorkingDir "D:\DevOptimizer" -Description "Full test suite" -MaxRetries 2

.NOTES
    Requires the queue-manager.ps1 at C:\Users\tbaltzakis\devin-queue\hooks\queue-manager.ps1
    Queue state is persisted at C:\Users\tbaltzakis\devin-queue\queue-state.json
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Command,

    [Parameter(Mandatory=$false, Position=1)]
    [string]$WorkingDir = "D:\DevOptimizer",

    [Parameter(Mandatory=$false, Position=2)]
    [string]$Description = "",

    [Parameter(Mandatory=$false)]
    [int]$MaxRetries = 3
)

$queueManager = "C:\Users\tbaltzakis\devin-queue\hooks\queue-manager.ps1"
if (-not (Test-Path $queueManager)) {
    Write-Error "Queue manager not found at $queueManager"
    exit 1
}

$pwsh = "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"
if (-not (Test-Path $pwsh)) {
    $pwsh = "pwsh"
}

$args = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-WindowStyle", "Hidden",
    "-File", $queueManager,
    "-Action", "enqueue",
    "-Command", $Command,
    "-WorkingDir", $WorkingDir,
    "-Description", $Description,
    "-MaxRetries", $MaxRetries
)

$exitCode = (& $pwsh $args)
exit $LASTEXITCODE