# DevOptimizer Logging System
# Comprehensive logging with structured levels, rotation, and multiple outputs

param(
    [string]$LogsDirectory = "D:\DevOptimizer\logs",
    [string]$ConfigPath = "D:\DevOptimizer\config\devoptimizer-config.json"
)

enum LogLevel {
    DEBUG = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
    CRITICAL = 4
}

class DevOptimizerLogger {
    [string]$LogsDirectory
    [string]$ConfigPath
    [LogLevel]$MinLevel
    [bool]$ConsoleOutput
    [bool]$FileOutput
    [string]$LogFormat
    [hashtable]$LogFiles = @{}
    [int]$MaxLogSize
    [int]$MaxLogFiles
    
    DevOptimizerLogger([string]$LogsDir, [string]$Config) {
        $this.LogsDirectory = $LogsDir
        $this.ConfigPath = $Config
        $this.InitializeLogger()
    }
    
    [void] InitializeLogger() {
        try {
            # Load configuration
            if (Test-Path $this.ConfigPath) {
                $config = Get-Content $this.ConfigPath -Raw | ConvertFrom-Json
                $this.MinLevel = [LogLevel]::$($config.system.log_level)
                $this.ConsoleOutput = $config.logging.console_output
                $this.FileOutput = $config.logging.file_output
                $this.LogFormat = $config.logging.log_format
                $this.MaxLogSize = $this.ParseSize($config.logging.max_log_size)
                $this.MaxLogFiles = $config.logging.max_log_files
            } else {
                # Default configuration
                $this.MinLevel = [LogLevel]::INFO
                $this.ConsoleOutput = $true
                $this.FileOutput = $true
                $this.LogFormat = "timestamp|level|component|message"
                $this.MaxLogSize = 10MB
                $this.MaxLogFiles = 10
            }
            
            # Ensure logs directory exists
            if (-not (Test-Path $this.LogsDirectory)) {
                New-Item -Path $this.LogsDirectory -ItemType Directory -Force | Out-Null
            }
            
            Write-Host "[LOGGER] Logging system initialized" -ForegroundColor Green
        }
        catch {
            Write-Error "[LOGGER] Failed to initialize logging system: $($_.Exception.Message)"
        }
    }
    
    [int] ParseSize([string]$SizeString) {
        $sizeString = $SizeString.ToUpper()
        if ($sizeString.EndsWith("KB")) {
            return [int]($sizeString.Replace("KB", "")) * 1024
        } elseif ($sizeString.EndsWith("MB")) {
            return [int]($sizeString.Replace("MB", "")) * 1024 * 1024
        } elseif ($sizeString.EndsWith("GB")) {
            return [int]($sizeString.Replace("GB", "")) * 1024 * 1024 * 1024
        } else {
            return [int]$sizeString
        }
    }
    
    [void] Log([LogLevel]$Level, [string]$Component, [string]$Message, [hashtable]$Context = @{}) {
        if ($Level -lt $this.MinLevel) {
            return
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = $this.FormatLogEntry($timestamp, $Level, $Component, $Message, $Context)
        
        # Console output
        if ($this.ConsoleOutput) {
            $this.WriteToConsole($Level, $logEntry)
        }
        
        # File output
        if ($this.FileOutput) {
            $this.WriteToFile($Component, $logEntry)
        }
    }
    
    [string] FormatLogEntry([string]$Timestamp, [LogLevel]$Level, [string]$Component, [string]$Message, [hashtable]$Context) {
        $formattedMessage = $Message
        
        # Add context if provided
        if ($Context.Count -gt 0) {
            $contextString = ($Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
            $formattedMessage += " | Context: $contextString"
        }
        
        # Format based on configuration
        switch ($this.LogFormat) {
            "timestamp|level|component|message" {
                return "$Timestamp|$Level|$Component|$formattedMessage"
            }
            "json" {
                $logObject = @{
                    timestamp = $Timestamp
                    level = $Level.ToString()
                    component = $Component
                    message = $formattedMessage
                    context = $Context
                }
                return $logObject | ConvertTo-Json -Compress
            }
            default {
                return "[$Timestamp] [$Level] [$Component] $formattedMessage"
            }
        }
    }
    
    [void] WriteToConsole([LogLevel]$Level, [string]$LogEntry) {
        $color = switch ($Level) {
            ([LogLevel]::DEBUG) { "Gray" }
            ([LogLevel]::INFO) { "White" }
            ([LogLevel]::WARNING) { "Yellow" }
            ([LogLevel]::ERROR) { "Red" }
            ([LogLevel]::CRITICAL) { "Magenta" }
        }
        
        Write-Host $LogEntry -ForegroundColor $color
    }
    
    [void] WriteToFile([string]$Component, [string]$LogEntry) {
        try {
            $logFile = $this.GetLogFile($Component)
            
            # Check if log rotation is needed
            if ((Get-Item $logFile -ErrorAction SilentlyContinue).Length -gt $this.MaxLogSize) {
                $this.RotateLogFile($logFile)
            }
            
            Add-Content -Path $logFile -Value $LogEntry -Encoding UTF8
        }
        catch {
            Write-Error "[LOGGER] Failed to write to log file: $($_.Exception.Message)"
        }
    }
    
    [string] GetLogFile([string]$Component) {
        if (-not $this.LogFiles.ContainsKey($Component)) {
            $logFileName = "$Component-$(Get-Date -Format 'yyyy-MM-dd').log"
            $logFilePath = Join-Path $this.LogsDirectory $logFileName
            $this.LogFiles[$Component] = $logFilePath
        }
        return $this.LogFiles[$Component]
    }
    
    [void] RotateLogFile([string]$LogFile) {
        try {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $rotatedFile = $LogFile.Replace(".log", "-$timestamp.log")
            Move-Item $LogFile $rotatedFile
            
            # Clean up old log files
            $this.CleanupOldLogs($LogFile)
        }
        catch {
            Write-Error "[LOGGER] Failed to rotate log file: $($_.Exception.Message)"
        }
    }
    
    [void] CleanupOldLogs([string]$LogFile) {
        try {
            $logDir = Split-Path $LogFile -Parent
            $logBaseName = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
            $logExtension = [System.IO.Path]::GetExtension($LogFile)
            
            $oldLogs = Get-ChildItem -Path $logDir -Filter "$logBaseName-*$logExtension" | 
                      Sort-Object LastWriteTime -Descending | 
                      Select-Object -Skip $this.MaxLogFiles
            
            foreach ($oldLog in $oldLogs) {
                Remove-Item $oldLog.FullName -Force
            }
        }
        catch {
            Write-Error "[LOGGER] Failed to cleanup old logs: $($_.Exception.Message)"
        }
    }
    
    # Convenience methods
    [void] Debug([string]$Component, [string]$Message, [hashtable]$Context = @{}) {
        $this.Log([LogLevel]::DEBUG, $Component, $Message, $Context)
    }
    
    [void] Info([string]$Component, [string]$Message, [hashtable]$Context = @{}) {
        $this.Log([LogLevel]::INFO, $Component, $Message, $Context)
    }
    
    [void] Warning([string]$Component, [string]$Message, [hashtable]$Context = @{}) {
        $this.Log([LogLevel]::WARNING, $Component, $Message, $Context)
    }
    
    [void] Error([string]$Component, [string]$Message, [hashtable]$Context = @{}) {
        $this.Log([LogLevel]::ERROR, $Component, $Message, $Context)
    }
    
    [void] Critical([string]$Component, [string]$Message, [hashtable]$Context = @{}) {
        $this.Log([LogLevel]::CRITICAL, $Component, $Message, $Context)
    }
}

# Global logger instance
$Global:DevOptimizerLogger = [DevOptimizerLogger]::new($LogsDirectory, $ConfigPath)

# Helper functions
function Write-Log {
    param(
        [LogLevel]$Level,
        [string]$Component,
        [string]$Message,
        [hashtable]$Context = @{}
    )
    $Global:DevOptimizerLogger.Log($Level, $Component, $Message, $Context)
}

function Write-DebugLog {
    param([string]$Component, [string]$Message, [hashtable]$Context = @{})
    $Global:DevOptimizerLogger.Debug($Component, $Message, $Context)
}

function Write-InfoLog {
    param([string]$Component, [string]$Message, [hashtable]$Context = @{})
    $Global:DevOptimizerLogger.Info($Component, $Message, $Context)
}

function Write-WarningLog {
    param([string]$Component, [string]$Message, [hashtable]$Context = @{})
    $Global:DevOptimizerLogger.Warning($Component, $Message, $Context)
}

function Write-ErrorLog {
    param([string]$Component, [string]$Message, [hashtable]$Context = @{})
    $Global:DevOptimizerLogger.Error($Component, $Message, $Context)
}

function Write-CriticalLog {
    param([string]$Component, [string]$Message, [hashtable]$Context = @{})
    $Global:DevOptimizerLogger.Critical($Component, $Message, $Context)
}

# Initialize logging system
Write-Host "[LOGGER] DevOptimizer Logging System initialized" -ForegroundColor Cyan
