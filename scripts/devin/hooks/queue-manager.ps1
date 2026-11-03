<#
.SYNOPSIS
    Devin FCFS Queue Persistence Manager
.DESCRIPTION
    Manages a file-backed queue for Devin Desktop FCFS (First-Come-First-Served) command execution.
    Provides atomic enqueue, dequeue, and state persistence across Devin restarts.
.NOTES
    Queue file: C:\Users\tbaltzakis\devin-queue\queue-state.json
    Lock file:  C:\Users\tbaltzakis\devin-queue\queue-state.json.lock
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet('enqueue', 'dequeue', 'peek', 'list', 'clear', 'send-next')]
    [string]$Action,

    [string]$Command,
    [string]$WorkingDirectory,
    [string]$Description,
    [int]$MaxRetries = 3
)

$queueFile = "C:\Users\tbaltzakis\devin-queue\queue-state.json"
$lockFile = "$queueFile.lock"
$scriptDir = Split-Path $MyInvocation.MyCommand.Path
# Devin CLI path (installed via Devin Desktop)
$devinCli = "C:\Users\tbaltzakis\AppData\Local\Programs\Devin\resources\app\extensions\windsurf\devin\bin\devin.exe"
if (-not (Test-Path $devinCli)) {
    $devinCli = "devin"  # fallback to PATH
}

function Get-Lock {
    param([int]$TimeoutMs = 5000)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        try {
            # Atomic lock creation using FileMode::CreateNew (fails if exists)
            $fs = [System.IO.File]::Open($lockFile, 'CreateNew', 'Write', 'None')
            $fs.Close()
            return $true
        } catch {
            Start-Sleep -Milliseconds 50
        }
    }
    return $false
}

function Release-Lock {
    if (Test-Path $lockFile) {
        try { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Read-Queue {
    if (-not (Test-Path $queueFile)) {
        return @{ queue = @(); version = 1; updated = (Get-Date -Format o) }
    }
    try {
        $content = Get-Content $queueFile -Raw -ErrorAction Stop
        return $content | ConvertFrom-Json
    } catch {
        Write-Warning "Failed to read queue file: $_"
        return @{ queue = @(); version = 1; updated = (Get-Date -Format o) }
    }
}

function Write-Queue {
    param($QueueData)
    $QueueData.updated = Get-Date -Format o
    $json = $QueueData | ConvertTo-Json -Depth 10 -Compress
    # Atomic write: write to temp then rename with retry for file locking issues
    for ($i = 0; $i -lt 5; $i++) {
        try {
            $tempFile = "$queueFile.tmp.$([Guid]::NewGuid())"
            Set-Content $tempFile $json -Encoding UTF8 -NoNewline
            Move-Item $tempFile $queueFile -Force -ErrorAction Stop
            return
        } catch {
            if ($i -eq 4) { throw "Failed to write queue after 5 attempts: $_" }
            Start-Sleep -Milliseconds 50
        }
    }
}

function Enqueue-Command {
    param($Command, $WorkingDirectory, $Description)
    if (-not (Get-Lock)) { throw "Could not acquire queue lock" }
    try {
        $q = Read-Queue
        $entry = @{
            id          = [Guid]::NewGuid().ToString()
            command     = $Command
            workingDir  = if ($WorkingDirectory) { $WorkingDirectory } else { (Get-Location).Path }
            description = if ($Description) { $Description } else { "Queued command" }
            enqueuedAt  = Get-Date -Format o
            attempts    = 0
            status      = 'pending'  # pending, running, completed, failed
        }
        $q.queue += $entry
        Write-Queue $q
        Write-Host "Enqueued: $($entry.command) [$($entry.id.Substring(0,8))]" -ForegroundColor Green
        return $entry.id
    } finally { Release-Lock }
}

function Dequeue-Command {
    if (-not (Get-Lock)) { throw "Could not acquire queue lock" }
    try {
        $q = Read-Queue
        if ($q.queue.Count -eq 0) { return $null }
        # Find first pending entry
        $idx = -1
        for ($i = 0; $i -lt $q.queue.Count; $i++) {
            if ($q.queue[$i].status -eq 'pending') { $idx = $i; break }
        }
        if ($idx -eq -1) { return $null }
        $entry = $q.queue[$idx]
        # ConvertFrom-Json returns PSCustomObject which doesn't allow adding properties directly
        # Convert to hashtable to allow modifications
        $entryHash = @{
            id          = $entry.id
            command     = $entry.command
            workingDir  = $entry.workingDir
            description = $entry.description
            enqueuedAt  = $entry.enqueuedAt
            attempts    = $entry.attempts + 1
            status      = 'running'
            startedAt   = Get-Date -Format o
        }
        $q.queue[$idx] = $entryHash
        Write-Queue $q
        return $entryHash
    } finally { Release-Lock }
}

function Peek-Queue {
    $q = Read-Queue
    foreach ($entry in $q.queue) {
        if ($entry.status -eq 'pending') { return $entry }
    }
    return $null
}

function List-Queue {
    $q = Read-Queue
    Write-Host "=== Devin FCFS Queue ===" -ForegroundColor Cyan
    Write-Host "Updated: $($q.updated)" -ForegroundColor Gray
    Write-Host "Total entries: $($q.queue.Count)" -ForegroundColor Gray
    Write-Host ""
    foreach ($entry in $q.queue) {
        $color = switch ($entry.status) {
            'pending'  { 'Yellow' }
            'running'  { 'Cyan' }
            'completed'{ 'Green' }
            'failed'   { 'Red' }
            default    { 'White' }
        }
        $shortId = $entry.id.Substring(0,8)
        $desc = if ($entry.description.Length -gt 50) { "$($entry.description.Substring(0,47))..." } else { $entry.description }
        Write-Host "  [$shortId] $($entry.status.PadRight(10)) $desc" -ForegroundColor $color
        Write-Host "        Command: $($entry.command)" -ForegroundColor DarkGray
        Write-Host "        Dir: $($entry.workingDir)" -ForegroundColor DarkGray
        Write-Host "        Enqueued: $($entry.enqueuedAt)" -ForegroundColor DarkGray
        if ($entry.status -eq 'running') { Write-Host "        Started: $($entry.startedAt)" -ForegroundColor DarkGray }
        Write-Host ""
    }
}

function Clear-Queue {
    if (-not (Get-Lock)) { throw "Could not acquire queue lock" }
    try {
        $q = Read-Queue
        $count = $q.queue.Count
        $q.queue = @()
        Write-Queue $q
        Write-Host "Cleared $count queued commands" -ForegroundColor Yellow
    } finally { Release-Lock }
}

function Mark-Completed {
    param($EntryId)
    if (-not (Get-Lock)) { throw "Could not acquire queue lock" }
    try {
        $q = Read-Queue
        for ($i = 0; $i -lt $q.queue.Count; $i++) {
            if ($q.queue[$i].id -eq $EntryId) {
                $q.queue[$i] = @{
                    id           = $q.queue[$i].id
                    command      = $q.queue[$i].command
                    workingDir   = $q.queue[$i].workingDir
                    description  = $q.queue[$i].description
                    enqueuedAt   = $q.queue[$i].enqueuedAt
                    attempts     = $q.queue[$i].attempts
                    status       = 'completed'
                    completedAt  = Get-Date -Format o
                }
                Write-Queue $q
                return $true
            }
        }
        return $false
    } finally { Release-Lock }
}

function Mark-Failed {
    param($EntryId, $ErrorMessage)
    if (-not (Get-Lock)) { throw "Could not acquire queue lock" }
    try {
        $q = Read-Queue
        for ($i = 0; $i -lt $q.queue.Count; $i++) {
            if ($q.queue[$i].id -eq $EntryId) {
                $q.queue[$i] = @{
                    id           = $q.queue[$i].id
                    command      = $q.queue[$i].command
                    workingDir   = $q.queue[$i].workingDir
                    description  = $q.queue[$i].description
                    enqueuedAt   = $q.queue[$i].enqueuedAt
                    attempts     = $q.queue[$i].attempts
                    status       = 'failed'
                    failedAt     = Get-Date -Format o
                    error        = $ErrorMessage
                }
                Write-Queue $q
                return $true
            }
        }
        return $false
    } finally { Release-Lock }
}

function Send-Next-Queued {
    param([int]$MaxRetries = 3)
    $entry = Dequeue-Command
    if (-not $entry) {
        Write-Host "No pending commands in queue" -ForegroundColor Yellow
        return 0
    }
    
    Write-Host "=== Executing queued command [$($entry.id.Substring(0,8))] ===" -ForegroundColor Cyan
    Write-Host "Command: $($entry.command)" -ForegroundColor White
    Write-Host "Dir: $($entry.workingDir)" -ForegroundColor DarkGray
    
    # Change to working directory
    try { Set-Location $entry.workingDir -ErrorAction Stop }
    catch { Write-Warning "Could not set working directory: $_" }
    
    # Execute the command via Devin CLI
    # Use `devin -p --permission-mode=dangerous --respect-workspace-trust=false -- <command>` (dangerous auto-approves all tools in non-interactive mode)
    $devinArgs = @("-p", "--permission-mode=dangerous", "--respect-workspace-trust=false", "--", $entry.command)
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Host "Attempt $attempt/$MaxRetries..." -ForegroundColor Cyan
        $result = & $devinCli @devinArgs 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "Command completed successfully" -ForegroundColor Green
            Mark-Completed $entry.id
            return 0
        } else {
            Write-Warning "Command failed (exit $exitCode): $result"
            if ($attempt -lt $MaxRetries) {
                Write-Host "Retrying in 5 seconds..." -ForegroundColor Yellow
                Start-Sleep 5
            }
        }
    }
    
    Mark-Failed $entry.id "Failed after $MaxRetries attempts. Last error: $result"
    Write-Host "Command failed after $MaxRetries attempts" -ForegroundColor Red
    return 1
}

# Main dispatch
switch ($Action) {
    'enqueue' {
        if (-not $Command) { throw "Command required for enqueue" }
        Enqueue-Command -Command $Command -WorkingDirectory $WorkingDirectory -Description $Description
    }
    'dequeue' {
        $entry = Dequeue-Command
        if ($entry) { $entry | ConvertTo-Json -Depth 5 } else { Write-Host "Queue empty" }
    }
    'peek' {
        $entry = Peek-Queue
        if ($entry) { $entry | ConvertTo-Json -Depth 5 } else { Write-Host "Queue empty" }
    }
    'list' { List-Queue }
    'clear' { Clear-Queue }
    'send-next' { exit Send-Next-Queued -MaxRetries $MaxRetries }
    default { throw "Unknown action: $Action" }
}