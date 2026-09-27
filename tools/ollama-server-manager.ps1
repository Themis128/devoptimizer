# DevOptimizer System - Ollama Server Manager
# This script manages the Ollama server with laptop optimization features

param(
    [string]$Action = "status",
    [int]$BasePort = 11434,
    [int]$MaxPorts = 10,
    [bool]$AutoStart = $true,
    [string]$ConfigFile = "configs\system-config.json"
)

# Import required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath = Join-Path $scriptDir "..\modules"

# Load configuration module
. (Join-Path $modulesPath "config-loader.ps1")

# Load REST client module
. (Join-Path $modulesPath "ollama-rest.ps1")

function Get-OllamaExecutablePath {
    <#
    .SYNOPSIS
    Finds the Ollama executable path.

    .DESCRIPTION
    Searches for ollama.exe in common locations.

    .OUTPUTS
    String. Path to ollama.exe or null if not found.
    #>

    $possiblePaths = @(
        "ollama.exe",
        "C:\Program Files\Ollama\ollama.exe",
        "C:\Program Files (x86)\Ollama\ollama.exe",
        "$env:USERPROFILE\AppData\Local\Programs\Ollama\ollama.exe",
        "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-Log "Found Ollama executable at: $path" -Level "INFO" -Component "ServerManager"
            return $path
        }
    }

    Write-Log "Ollama executable not found in standard locations" -Level "WARN" -Component "ServerManager"
    return $null
}

function Test-OllamaProcess {
    <#
    .SYNOPSIS
    Checks if Ollama server process is running.

    .DESCRIPTION
    Searches for ollama.exe process and returns status.

    .OUTPUTS
    PSCustomObject. Process status information.
    #>

    try {
        $processes = Get-Process -Name "ollama" -ErrorAction SilentlyContinue

        if ($processes) {
            $process = $processes[0]
            return @{
                IsRunning = $true
                ProcessId = $process.Id
                ProcessName = $process.ProcessName
                StartTime = $process.StartTime
                WorkingSet = $process.WorkingSet
                CPU = $process.CPU
            }
        } else {
            return @{
                IsRunning = $false
                ProcessId = $null
                ProcessName = $null
                StartTime = $null
                WorkingSet = 0
                CPU = 0
            }
        }
    } catch {
        Write-Log "Error checking Ollama process: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
        return @{
            IsRunning = $false
            ProcessId = $null
            ProcessName = $null
            StartTime = $null
            WorkingSet = 0
            CPU = 0
            Error = $_.Exception.Message
        }
    }
}

function Start-OllamaServer {
    <#
    .SYNOPSIS
    Starts the Ollama server with laptop optimization.

    .DESCRIPTION
    Launches Ollama server with optimized settings for laptop usage.

    .PARAMETER Port
    Port to bind the server to.

    .PARAMETER ServerHost
    Host to bind the server to (default: 127.0.0.1 for security).
    #>
    param(
        [int]$Port = 11434,
        [string]$ServerHost = "127.0.0.1"
    )

    try {
        $ollamaPath = Get-OllamaExecutablePath
        if (-not $ollamaPath) {
            throw "Ollama executable not found. Please install Ollama first."
        }

        # Check if already running
        $processStatus = Test-OllamaProcess
        if ($processStatus.IsRunning) {
            Write-Log "Ollama server is already running (PID: $($processStatus.ProcessId))" -Level "INFO" -Component "ServerManager"
            return $processStatus
        }

        # Set environment variables for laptop optimization
        $envVars = @{
            "OLLAMA_HOST" = "$ServerHost`:$Port"
            "OLLAMA_NUM_PARALLEL" = "2"  # Limit parallel requests
            "OLLAMA_MAX_LOADED_MODELS" = "2"  # Limit loaded models
            "OLLAMA_KEEP_ALIVE" = "10m"  # Keep models loaded for 10 minutes
            "OLLAMA_DEBUG" = "0"  # Disable debug logging for performance
        }

        foreach ($var in $envVars.GetEnumerator()) {
            [Environment]::SetEnvironmentVariable($var.Key, $var.Value, "Process")
            Write-Log "Set environment variable: $($var.Key) = $($var.Value)" -Level "DEBUG" -Component "ServerManager"
        }

        # Start the server
        Write-Log "Starting Ollama server on $ServerHost`:$Port with laptop optimizations..." -Level "INFO" -Component "ServerManager"

        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $ollamaPath
        $processInfo.Arguments = "serve"
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        # Wait a moment for server to start
        Start-Sleep -Seconds 3

        # Verify server is running
        $newProcessStatus = Test-OllamaProcess
        if ($newProcessStatus.IsRunning) {
            Write-Log "Ollama server started successfully (PID: $($newProcessStatus.ProcessId))" -Level "INFO" -Component "ServerManager"

            # Test server health
            Start-Sleep -Seconds 2
            $healthCheck = Test-OllamaServerHealth -ServerUrl "http://$ServerHost`:$Port"
            if ($healthCheck.IsHealthy) {
                Write-Log "Ollama server is healthy and responding" -Level "INFO" -Component "ServerManager"
            } else {
                Write-Log "Ollama server started but health check failed" -Level "WARN" -Component "ServerManager"
            }

            return $newProcessStatus
        } else {
            throw "Failed to start Ollama server"
        }

    } catch {
        Write-Log "Failed to start Ollama server: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
        throw "Failed to start Ollama server: $($_.Exception.Message)"
    }
}

function Stop-OllamaServer {
    <#
    .SYNOPSIS
    Stops the Ollama server gracefully.

    .DESCRIPTION
    Terminates the Ollama server process if running.
    #>

    try {
        $processStatus = Test-OllamaProcess

        if (-not $processStatus.IsRunning) {
            Write-Log "Ollama server is not running" -Level "INFO" -Component "ServerManager"
            return $true
        }

        Write-Log "Stopping Ollama server (PID: $($processStatus.ProcessId))..." -Level "INFO" -Component "ServerManager"

        # Try graceful shutdown first
        $process = Get-Process -Id $processStatus.ProcessId -ErrorAction SilentlyContinue
        if ($process) {
            $process.CloseMainWindow()
            Start-Sleep -Seconds 5

            # Check if still running
            if (-not $process.HasExited) {
                Write-Log "Graceful shutdown failed, forcing termination..." -Level "WARN" -Component "ServerManager"
                $process.Kill()
            }
        }

        # Verify server is stopped
        Start-Sleep -Seconds 2
        $finalStatus = Test-OllamaProcess
        if (-not $finalStatus.IsRunning) {
            Write-Log "Ollama server stopped successfully" -Level "INFO" -Component "ServerManager"
            return $true
        } else {
            Write-Log "Failed to stop Ollama server" -Level "ERROR" -Component "ServerManager"
            return $false
        }

    } catch {
        Write-Log "Error stopping Ollama server: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
        return $false
    }
}

function Restart-OllamaServer {
    <#
    .SYNOPSIS
    Restarts the Ollama server.

    .DESCRIPTION
    Stops and starts the Ollama server.
    #>

    Write-Log "Restarting Ollama server..." -Level "INFO" -Component "ServerManager"

    $stopResult = Stop-OllamaServer
    if ($stopResult) {
        Start-Sleep -Seconds 2
        $startResult = Start-OllamaServer
        if ($startResult.IsRunning) {
            Write-Log "Ollama server restarted successfully" -Level "INFO" -Component "ServerManager"
            return $startResult
        } else {
            throw "Failed to restart Ollama server - start failed"
        }
    } else {
        throw "Failed to restart Ollama server - stop failed"
    }
}

function Find-BestPort {
    <#
    .SYNOPSIS
    Finds the best available port for Ollama server.

    .DESCRIPTION
    Scans for available ports starting from base port using improved algorithm.

    .PARAMETER BasePort
    Starting port number.

    .PARAMETER MaxPorts
    Maximum number of ports to check.

    .OUTPUTS
    Integer. Available port number or null.
    #>
    param(
        [int]$BasePort = 11434,
        [int]$MaxPorts = 10
    )

    Write-Log "Scanning for available ports starting from $BasePort..." -Level "INFO" -Component "ServerManager"

    for ($i = 0; $i -lt $MaxPorts; $i++) {
        $port = $BasePort + $i

        try {
            # Create a TcpListener to test if port is available
            $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
            $listener.Start()
            $listener.Stop()

            # Port is available
            Write-Log "Found available port: $port" -Level "INFO" -Component "ServerManager"
            return $port

        } catch [System.Net.Sockets.SocketException] {
            # Port is in use
            Write-Log "Port $port is in use, trying next..." -Level "DEBUG" -Component "ServerManager"
            continue

        } catch {
            # Other error occurred
            Write-Log "Error checking port $port`: $($_.Exception.Message)" -Level "DEBUG" -Component "ServerManager"
            continue
        }
    }

    # If no ports found in range, try system-assigned port
    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, 0)
        $listener.Start()
        $systemPort = $listener.Server.LocalEndPoint.Port
        $listener.Stop()

        Write-Log "Using system-assigned port: $systemPort" -Level "INFO" -Component "ServerManager"
        return $systemPort

    } catch {
        Write-Log "No available ports found in range $BasePort to $($BasePort + $MaxPorts - 1) and system-assigned port failed" -Level "ERROR" -Component "ServerManager"
        return $null
    }
}

function Install-OllamaScheduledTask {
    <#
    .SYNOPSIS
    Installs a scheduled task to auto-start Ollama server at logon.

    .DESCRIPTION
    Creates a Windows scheduled task for automatic server startup.
    #>

    try {
        $taskName = "DevOptimizer-Ollama-Server"
        $ollamaPath = Get-OllamaExecutablePath

        if (-not $ollamaPath) {
            throw "Ollama executable not found"
        }

        # Check if task already exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Write-Log "Scheduled task '$taskName' already exists" -Level "INFO" -Component "ServerManager"
            return $true
        }

        # Create task action
        $action = New-ScheduledTaskAction -Execute $ollamaPath -Argument "serve"

        # Create task trigger (at logon)
        $trigger = New-ScheduledTaskTrigger -AtLogOn

        # Create task settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

        # Create task principal (run as current user)
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType InteractiveToken

        # Register the task
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "DevOptimizer Ollama Server Auto-Start"

        Write-Log "Scheduled task '$taskName' created successfully" -Level "INFO" -Component "ServerManager"
        return $true

    } catch {
        Write-Log "Failed to create scheduled task: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
        return $false
    }
}

function Remove-OllamaScheduledTask {
    <#
    .SYNOPSIS
    Removes the Ollama auto-start scheduled task.
    #>

    try {
        $taskName = "DevOptimizer-Ollama-Server"

        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Log "Scheduled task '$taskName' removed successfully" -Level "INFO" -Component "ServerManager"
            return $true
        } else {
            Write-Log "Scheduled task '$taskName' not found" -Level "INFO" -Component "ServerManager"
            return $true
        }

    } catch {
        Write-Log "Failed to remove scheduled task: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
        return $false
    }
}

function Get-OllamaServerStatus {
    <#
    .SYNOPSIS
    Gets comprehensive Ollama server status.

    .DESCRIPTION
    Returns detailed status information about the server.

    .OUTPUTS
    PSCustomObject. Complete server status.
    #>

    try {
        $processStatus = Test-OllamaProcess
        $config = Get-Configuration
        $serverUrl = Get-ConfigValue -Path "ollama.serverUrl" -DefaultValue "http://127.0.0.1:11434"

        $status = @{
            Process = $processStatus
            ServerUrl = $serverUrl
            Health = $null
            Models = @()
            ScheduledTask = $null
            Configuration = @{
                ServerUrl = $serverUrl
                MaxLoaded = Get-ConfigValue -Path "ollama.maxLoaded" -DefaultValue 2
                Concurrency = Get-ConfigValue -Path "ollama.concurrency" -DefaultValue 2
                KeepAlive = Get-ConfigValue -Path "ollama.keepAliveSec" -DefaultValue 600
            }
        }

        # Check scheduled task
        try {
            $taskName = "DevOptimizer-Ollama-Server"
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($task) {
                $status.ScheduledTask = @{
                    Name = $task.TaskName
                    State = $task.State.ToString()
                    LastRunTime = $task.LastRunTime
                    NextRunTime = $task.NextRunTime
                }
            }
        } catch {
            $status.ScheduledTask = @{ Error = "Could not check scheduled task" }
        }

        # Check server health if running
        if ($processStatus.IsRunning) {
            try {
                $healthCheck = Test-OllamaServerHealth -ServerUrl $serverUrl
                $status.Health = $healthCheck
                $status.Models = $healthCheck.Models
            } catch {
                $status.Health = @{ Error = "Health check failed: $($_.Exception.Message)" }
            }
        }

        return $status

    } catch {
        Write-Log "Failed to get server status: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
        return @{
            Error = $_.Exception.Message
            Process = @{ IsRunning = $false }
            Health = @{ IsHealthy = $false }
        }
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "Unknown"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [$Component] $Message"

    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG" { Write-Host $logMessage -ForegroundColor Gray }
        default { Write-Host $logMessage }
    }
}

# Main execution logic
try {
    Write-Log "Ollama Server Manager - Action: $Action" -Level "INFO" -Component "ServerManager"

    # Validate parameters
    if ($BasePort -lt 1024 -or $BasePort -gt 65535) {
        Write-Log "Invalid BasePort: $BasePort. Must be between 1024 and 65535" -Level "ERROR" -Component "ServerManager"
        exit 1
    }

    if ($MaxPorts -lt 1 -or $MaxPorts -gt 100) {
        Write-Log "Invalid MaxPorts: $MaxPorts. Must be between 1 and 100" -Level "ERROR" -Component "ServerManager"
        exit 1
    }

    switch ($Action.ToLower()) {
        "start" {
            try {
                $port = Find-BestPort -BasePort $BasePort -MaxPorts $MaxPorts
                if ($port) {
                    $result = Start-OllamaServer -Port $port
                    if ($result.IsRunning) {
                        Write-Log "Ollama server started successfully on port $port" -Level "INFO" -Component "ServerManager"
                        exit 0
                    } else {
                        Write-Log "Failed to start Ollama server - process not running" -Level "ERROR" -Component "ServerManager"
                        exit 1
                    }
                } else {
                    Write-Log "No available ports found for Ollama server in range $BasePort to $($BasePort + $MaxPorts - 1)" -Level "ERROR" -Component "ServerManager"
                    Write-Log "Try stopping other services or increasing MaxPorts parameter" -Level "INFO" -Component "ServerManager"
                    exit 1
                }
            } catch {
                Write-Log "Start operation failed: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
                Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "DEBUG" -Component "ServerManager"
                exit 1
            }
        }

        "stop" {
            try {
                $result = Stop-OllamaServer
                if ($result) {
                    Write-Log "Ollama server stopped successfully" -Level "INFO" -Component "ServerManager"
                    exit 0
                } else {
                    Write-Log "Failed to stop Ollama server" -Level "ERROR" -Component "ServerManager"
                    exit 1
                }
            } catch {
                Write-Log "Stop operation failed: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
                Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "DEBUG" -Component "ServerManager"
                exit 1
            }
        }

        "restart" {
            try {
                $result = Restart-OllamaServer
                if ($result.IsRunning) {
                    Write-Log "Ollama server restarted successfully" -Level "INFO" -Component "ServerManager"
                    exit 0
                } else {
                    Write-Log "Failed to restart Ollama server" -Level "ERROR" -Component "ServerManager"
                    exit 1
                }
            } catch {
                Write-Log "Restart operation failed: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
                Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "DEBUG" -Component "ServerManager"
                exit 1
            }
        }

        "status" {
            $status = Get-OllamaServerStatus

            Write-Log "=== Ollama Server Status ===" -Level "INFO" -Component "ServerManager"
            Write-Log "Process Running: $($status.Process.IsRunning)" -Level "INFO" -Component "ServerManager"

            if ($status.Process.IsRunning) {
                Write-Log "Process ID: $($status.Process.ProcessId)" -Level "INFO" -Component "ServerManager"
                Write-Log "Start Time: $($status.Process.StartTime)" -Level "INFO" -Component "ServerManager"
                Write-Log "Memory Usage: $([math]::Round($status.Process.WorkingSet / 1MB, 2)) MB" -Level "INFO" -Component "ServerManager"
                Write-Log "Server URL: $($status.ServerUrl)" -Level "INFO" -Component "ServerManager"

                if ($status.Health) {
                    Write-Log "Health Status: $($status.Health.IsHealthy)" -Level "INFO" -Component "ServerManager"
                    Write-Log "Available Models: $($status.Models.Count)" -Level "INFO" -Component "ServerManager"
                    if ($status.Models.Count -gt 0) {
                        Write-Log "Models: $($status.Models.Name -join ', ')" -Level "INFO" -Component "ServerManager"
                    }
                }
            }

            if ($status.ScheduledTask) {
                Write-Log "Auto-Start Task: $($status.ScheduledTask.Name) ($($status.ScheduledTask.State))" -Level "INFO" -Component "ServerManager"
            }

            exit 0
        }

        "install-task" {
            $result = Install-OllamaScheduledTask
            if ($result) {
                Write-Log "Scheduled task installed successfully" -Level "INFO" -Component "ServerManager"
                exit 0
            } else {
                Write-Log "Failed to install scheduled task" -Level "ERROR" -Component "ServerManager"
                exit 1
            }
        }

        "remove-task" {
            $result = Remove-OllamaScheduledTask
            if ($result) {
                Write-Log "Scheduled task removed successfully" -Level "INFO" -Component "ServerManager"
                exit 0
            } else {
                Write-Log "Failed to remove scheduled task" -Level "ERROR" -Component "ServerManager"
                exit 1
            }
        }

        default {
            Write-Log "Unknown action: $Action" -Level "ERROR" -Component "ServerManager"
            Write-Log "Available actions: start, stop, restart, status, install-task, remove-task" -Level "INFO" -Component "ServerManager"
            exit 1
        }
    }

} catch {
    Write-Log "Server Manager error: $($_.Exception.Message)" -Level "ERROR" -Component "ServerManager"
    exit 1
}
