<#
.SYNOPSIS
    Docker Model Runner (DMR) model management - list, evict, TTL, watchdog.
.DESCRIPTION
    Manages models loaded by the integrated docker-model-runner container.
    Provides visibility into VRAM usage per model and proactive eviction.
    Registered as hub command: dmr-model-manager (category: ai-ml)
#>
#requires -Version 5.1
# CATEGORY: ai-ml
param(
    [ValidateSet('list','evict','ttl','watchdog','status','check-once')]
    [string]$Action = 'list',
    [string]$Model,
    [int]$TTLMinutes = 30,
    [switch]$All,
    [switch]$Force,
    [int]$IntervalSeconds = 60
)

$ErrorActionPreference = 'SilentlyContinue'
$logFile = 'D:\DevOptimizer\logs\dmr-model-manager.log'
$stateFile = 'D:\DevOptimizer\logs\dmr-model-state.json'

function Log { param($msg) Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) }
function Write-Out { param($msg) Write-Host $msg; Log $msg }

# --- Helpers ----------------------------------------------------------------
function Get-DMRContainer {
    # Check running containers first
    $c = docker ps --filter "name=docker-model-runner" --format "{{.Names}}" 2>$null
    if ($c) { return $c.Trim() }
    
    # Check stopped containers
    $c = docker ps -a --filter "name=docker-model-runner" --format "{{.Names}}" 2>$null
    if ($c) { return $c.Trim() }
    
    # Try common alternative names
    foreach ($name in 'docker-model-runner','dmr','model-runner') {
        $c = docker ps --filter "name=$name" --format "{{.Names}}" 2>$null
        if ($c) { return $c.Trim() }
        $c = docker ps -a --filter "name=$name" --format "{{.Names}}" 2>$null
        if ($c) { return $c.Trim() }
    }
    return $null
}

function Get-DMRContainerStatus {
    $container = Get-DMRContainer
    if (-not $container) { return 'NOT_FOUND' }
    $status = docker ps -a --filter "name=^/$container$" --format "{{.Status}}" 2>$null
    return $status.Trim()
}

function Get-VRAMUsage {
    $nsmi = nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>$null
    # Output format: "7643, 8192" (used, total) - comma + space
    if ($nsmi -match '(\d+)\s*,\s*(\d+)') {
        return @{ Used = [int]$Matches[1]; Total = [int]$Matches[2]; Pct = [int](100 * $Matches[1] / $Matches[2]) }
    }
    # Fallback: try just space-separated
    if ($nsmi -match '(\d+)\s+(\d+)') {
        return @{ Used = [int]$Matches[1]; Total = [int]$Matches[2]; Pct = [int](100 * $Matches[1] / $Matches[2]) }
    }
    return @{ Used = 0; Total = 0; Pct = 0 }
}

function Get-DMRModels {
    $container = Get-DMRContainer
    if (-not $container) { return @() }
    
    # Try to get models via docker exec (DMR API)
    $models = @()
    try {
        # DMR exposes a models endpoint
        $result = docker exec $container curl -s http://localhost:12434/v1/models 2>$null
        if ($result -and $result -match '"data"') {
            $json = $result | ConvertFrom-Json
            foreach ($m in $json.data) {
                $models += [pscustomobject]@{
                    Id          = $m.id
                    OwnedBy     = $m.owned_by
                    Created     = if ($m.created) { [datetime]::FromFileTimeUtc($m.created * 10000000 + 116444736000000000) } else { $null }
                    SizeBytes   = if ($m.size) { [long]$m.size } else { 0 }
                }
            }
        }
    } catch { }
    
    # Fallback: parse docker logs for model load events
    if ($models.Count -eq 0) {
        $logs = docker logs --tail 200 $container 2>$null
        foreach ($line in $logs) {
            if ($line -match 'loaded model[:\s]+(\S+)') {
                $models += [pscustomobject]@{ Id = $Matches[1]; OwnedBy = 'docker-model-runner'; Created = (Get-Date); SizeBytes = 0 }
            }
        }
        $models = $models | Sort-Object Id -Unique
    }
    
    return $models
}

function Get-ModelLastAccess {
    $container = Get-DMRContainer
    if (-not $container) { return @{} }
    
    $access = @{}
    try {
        # Check DMR access logs if available
        $logs = docker logs --tail 500 $container 2>$null
        foreach ($line in $logs) {
            if ($line -match '(GET|POST)\s+/v1/(chat/completions|embeddings|models/[\w-]+)') {
                # Extract model name from request if possible
                if ($line -match 'model["\s:=]+([\w\-\.\/]+)') {
                    $access[$Matches[1]] = (Get-Date)
                }
            }
        }
    } catch { }
    
    return $access
}

function Check-DMRHealth {
    param(
        [int]$TTLMinutes = 30
    )
    $result = @{ ActionTaken = $false; Message = ''; ExitCode = 0 }
    
    $container = Get-DMRContainer
    if (-not $container) {
        $result.Message = 'docker-model-runner container not found'
        $result.ExitCode = 1
        return $result
    }
    
    $vram = Get-VRAMUsage
    $vramPct = $vram.Pct
    $models = Get-DMRModels
    $lastAccess = Get-ModelLastAccess
    $now = Get-Date
    
    $evicted = @()
    foreach ($m in $models) {
        $last = if ($lastAccess.ContainsKey($m.Id)) { $lastAccess[$m.Id] } else { $m.Created }
        if ($last -and (($now - $last).TotalMinutes -gt $TTLMinutes)) {
            $evicted += $m.Id
        }
    }
    
    if ($evicted.Count -gt 0) {
        docker restart $container 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $result.ActionTaken = $true
            $result.Message = "Evicted idle models: $($evicted -join ', '); restarted docker-model-runner"
            Start-Sleep -Seconds 10
        } else {
            $result.Message = "FAILED to restart docker-model-runner for idle eviction"
            $result.ExitCode = 1
        }
    } elseif ($vramPct -gt 85) {
        docker restart $container 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $result.ActionTaken = $true
            $result.Message = "VRAM at ${vramPct}% (>85%); restarted docker-model-runner preemptively"
            Start-Sleep -Seconds 10
        } else {
            $result.Message = "FAILED to restart docker-model-runner for VRAM pressure"
            $result.ExitCode = 1
        }
    } else {
        $result.Message = "VRAM ${vramPct}%, ${models.Count} model(s) loaded, no idle models > ${TTLMinutes}min"
    }
    
    return $result
}

# --- Actions ----------------------------------------------------------------
switch ($Action) {
    'list' {
        Write-Out "=== DMR Model Manager ==="
        $vram = Get-VRAMUsage
        Write-Out "VRAM: {0} / {1} MB ({2}%)" -f $vram.Used, $vram.Total, $vram.Pct
        Write-Out ""
        
        $container = Get-DMRContainer
        if (-not $container) {
            Write-Out "ERROR: docker-model-runner container not found"
            exit 1
        }
        Write-Out "Container: $container"
        Write-Out ""
        
        $models = Get-DMRModels
        $lastAccess = Get-ModelLastAccess
        $now = Get-Date
        
        if ($models.Count -eq 0) {
            Write-Out "No models currently loaded (or DMR API not responding)"
        } else {
            Write-Out ("{0,-40} {1,>12} {2,>20} {3,>15}" -f "MODEL ID", "SIZE (MB)", "LAST ACCESS", "IDLE (MIN)")
            Write-Out ("{0}" -f ('-' * 90))
            foreach ($m in $models) {
                $sizeMB = if ($m.SizeBytes -gt 0) { [math]::Round($m.SizeBytes / 1MB, 1) } else { 'unknown' }
                $last = if ($lastAccess.ContainsKey($m.Id)) { $lastAccess[$m.Id] } else { $m.Created }
                $idle = if ($last) { [math]::Round(($now - $last).TotalMinutes, 1) } else { 'unknown' }
                $idleStr = if ($idle -is [double]) { "{0:N1}" -f $idle } else { $idle }
                Write-Out ("{0,-40} {1,>12} {2,>20} {3,>15}" -f $m.Id.Substring(0,[math]::Min(40,$m.Id.Length)), $sizeMB, 
                    (if ($last) { $last.ToString('yyyy-MM-dd HH:mm') } else { 'never' }), $idleStr)
            }
        }
    }
    
    'evict' {
        $container = Get-DMRContainer
        if (-not $container) { Write-Out "ERROR: docker-model-runner container not found"; exit 1 }
        
        if ($Model) {
            Write-Out "Evicting model: $Model"
            # DMR doesn't have a direct evict API; restart container to evict all
            if (-not $Force) {
                $confirm = Read-Host "This will restart docker-model-runner (evicts ALL models). Continue? (y/N)"
                if ($confirm -ne 'y') { Write-Out "Cancelled"; exit 0 }
            }
            docker restart $container 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Out "SUCCESS: docker-model-runner restarted, all models evicted"
                Start-Sleep -Seconds 10
                $vram = Get-VRAMUsage
                Write-Out "VRAM after: {0} / {1} MB ({2}%)" -f $vram.Used, $vram.Total, $vram.Pct
            } else {
                Write-Out "ERROR: restart failed"
                exit 1
            }
        } elseif ($All) {
            Write-Out "Evicting ALL models (restarting docker-model-runner)..."
            docker restart $container 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Out "SUCCESS: docker-model-runner restarted"
                Start-Sleep -Seconds 10
                $vram = Get-VRAMUsage
                Write-Out "VRAM after: {0} / {1} MB ({2}%)" -f $vram.Used, $vram.Total, $vram.Pct
            } else {
                Write-Out "ERROR: restart failed"
                exit 1
            }
        } else {
            Write-Out "ERROR: Specify -Model <name> or -All"
            exit 1
        }
    }
    
    'ttl' {
        Write-Out "Setting DMR model TTL to $TTLMinutes minutes (idle eviction)"
        $state = @{ TTLMinutes = $TTLMinutes; Enabled = $true; Updated = (Get-Date).ToString('o') }
        $state | ConvertTo-Json -Depth 3 | Set-Content $stateFile -Encoding ASCII
        Write-Out "TTL config saved to $stateFile"
        Write-Out "Run 'dmr-model-manager watchdog' to start background eviction monitor"
    }
    
    'watchdog' {
        Write-Out "Starting DMR Model Watchdog (interval: ${IntervalSeconds}s, TTL: ${TTLMinutes}min)"
        Write-Out "Press Ctrl+C to stop"
        Log "Watchdog started: interval=${IntervalSeconds}s ttl=${TTLMinutes}min"
        
        $state = @{ TTLMinutes = $TTLMinutes; Enabled = $true }
        $state | ConvertTo-Json -Depth 3 | Set-Content $stateFile -Encoding ASCII
        
        try {
            while ($true) {
                $result = Check-DMRHealth -TTLMinutes $TTLMinutes
                if ($result.ActionTaken) {
                    Write-Out "Watchdog: $($result.Message)"
                    Log "Watchdog: $($result.Message)"
                } else {
                    Write-Out "Watchdog: $($result.Message)"
                }
                Start-Sleep -Seconds $IntervalSeconds
            }
        } catch {
            Write-Out "Watchdog stopped: $_"
            Log "Watchdog error: $_"
        }
    }
    
    'check-once' {
        Write-Out "=== DMR Health Check (single run) ==="
        $result = Check-DMRHealth -TTLMinutes $TTLMinutes
        if ($result.ActionTaken) {
            Write-Out "ACTION: $($result.Message)"
            Log "Check-once: $($result.Message)"
        } else {
            Write-Out "OK: $($result.Message)"
            Log "Check-once: $($result.Message)"
        }
        exit $result.ExitCode
    }
    
    'status' {
        Write-Out "=== DMR Status ==="
        $vram = Get-VRAMUsage
        Write-Out "VRAM: {0} / {1} MB ({2}%)" -f $vram.Used, $vram.Total, $vram.Pct
        
        $container = Get-DMRContainer
        if ($container) {
            Write-Out "Container: $container (RUNNING)"
            $models = Get-DMRModels
            Write-Out "Models loaded: $($models.Count)"
            if ($models.Count -gt 0) {
                Write-Out "Model IDs: $($models.Id -join ', ')"
            }
        } else {
            Write-Out "Container: NOT RUNNING"
        }
        
        # Check state file
        if (Test-Path $stateFile) {
            $state = Get-Content $stateFile -Raw | ConvertFrom-Json
            Write-Out "TTL Config: $($state.TTLMinutes) min, Enabled: $($state.Enabled)"
        } else {
            Write-Out "TTL Config: not set"
        }
    }
}

exit 0