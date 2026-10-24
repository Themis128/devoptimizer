<#
.SYNOPSIS
    DevOptimizer MCP Server - exposes DevOptimizer tools to Devin CLI and other MCP clients
.DESCRIPTION
    Implements MCP protocol over stdio. Provides Devin health, diagnostics, maintenance, and repair tools.
#>

using namespace System.Text.Json

$ErrorActionPreference = 'Stop'

# MCP Protocol constants
$MCP_VERSION = "2024-11-05"

# Tool definitions
$tools = @(
    @{
        name = "devin_health"
        description = "Quick Devin Desktop health check (WSL, devin-server, memory, bundles)"
        inputSchema = @{
            type = "object"
            properties = @{
                repair = @{ type = "boolean"; description = "Auto-repair if issues found" }
            }
        }
    }
    @{
        name = "devin_diagnostics"
        description = "Deep Devin diagnostics (app version, commit dirs, logs, error signatures)"
        inputSchema = @{
            type = "object"
            properties = @{
                outfile = @{ type = "string"; description = "Optional JSON output file path" }
            }
        }
    }
    @{
        name = "devin_doctor"
        description = "Run community devin-doctor check (stores, schema, config, disk)"
        inputSchema = @{
            type = "object"
            properties = @{
                skipInstall = @{ type = "boolean"; description = "Skip auto-install of devin-doctor" }
                jsonOnly = @{ type = "boolean"; description = "Output only JSON" }
            }
        }
    }
    @{
        name = "devin_maintenance"
        description = "Run daily maintenance (cache sweep, log retention, bundle cleanup)"
        inputSchema = @{
            type = "object"
            properties = @{
                logRetentionDays = @{ type = "integer"; default = 14; description = "Log retention days" }
                reportRetentionDays = @{ type = "integer"; default = 30; description = "Report retention days" }
            }
        }
    }
    @{
        name = "devin_repair"
        description = "Repair Devin issues (fix bundle, clean leftovers, prune logs)"
        inputSchema = @{
            type = "object"
            properties = @{
                fixBundle = @{ type = "boolean"; description = "Fix corrupt bundle" }
                cleanLeftovers = @{ type = "boolean"; description = "Clean superseded commit dirs" }
                pruneServerLogs = @{ type = "boolean"; description = "Prune old server logs" }
                days = @{ type = "integer"; default = 14; description = "Log age threshold" }
                force = @{ type = "boolean"; description = "Skip confirmations" }
            }
        }
    }
    @{
        name = "devin_cleanup_acp"
        description = "Clean ACP message databases (old sessions, large DBs, orphaned files)"
        inputSchema = @{
            type = "object"
            properties = @{
                days = @{ type = "integer"; default = 14; description = "Retention days" }
                removeLarge = @{ type = "boolean"; description = "Remove DBs > 256 MB" }
            }
        }
    }
    @{
        name = "devin_tune_windows"
        description = "Tune Windows for Devin (priority, startup, Defender exclusions)"
        inputSchema = @{
            type = "object"
            properties = @{
                priority = @{ type = "string"; enum = ["normal", "high"]; default = "high" }
                startup = @{ type = "boolean"; default = $true }
                defenderExclusions = @{ type = "boolean"; default = $true }
            }
        }
    }
)

function Write-McpResponse {
    param([object]$Response)
    $json = $Response | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json + "`n")
    [Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)
}

function Write-McpError {
    param([string]$Id, [int]$Code, [string]$Message)
    Write-McpResponse @{
        jsonrpc = "2.0"
        id = $Id
        error = @{ code = $Code; message = $Message }
    }
}

function Handle-Initialize {
    param([object]$Request)
    Write-McpResponse @{
        jsonrpc = "2.0"
        id = $Request.id
        result = @{
            protocolVersion = $MCP_VERSION
            capabilities = @{ tools = @{} }
            serverInfo = @{ name = "devoptimizer"; version = "1.0.0" }
        }
    }
}

function Handle-ToolsList {
    param([object]$Request)
    Write-McpResponse @{
        jsonrpc = "2.0"
        id = $Request.id
        result = @{ tools = $tools }
    }
}

function Handle-ToolCall {
    param([object]$Request)
    $toolName = $Request.params.name
    $args = $Request.params.arguments

    try {
        $result = switch ($toolName) {
            "devin_health"      { Invoke-DevinHealth $args }
            "devin_diagnostics" { Invoke-DevinDiagnostics $args }
            "devin_doctor"      { Invoke-DevinDoctor $args }
            "devin_maintenance" { Invoke-DevinMaintenance $args }
            "devin_repair"      { Invoke-DevinRepair $args }
            "devin_cleanup_acp" { Invoke-DevinCleanupACP $args }
            "devin_tune_windows" { Invoke-DevinTuneWindows $args }
            default { throw "Unknown tool: $toolName" }
        }
        Write-McpResponse @{
            jsonrpc = "2.0"
            id = $Request.id
            result = @{ content = @(@{ type = "text"; text = $result }) }
        }
    } catch {
        Write-McpError $Request.id -32603 $_.Exception.Message
    }
}

function Invoke-DevinHealth {
    param($args)
    $script = "D:\DevOptimizer\scripts\devin\Check-DevinHealth.ps1"
    $params = @()
    if ($args.repair) { $params += "-Repair" }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @params 2>&1 | Out-String
}

function Invoke-DevinDiagnostics {
    param($args)
    $script = "D:\DevOptimizer\scripts\devin\Get-DevinDiagnostics.ps1"
    $params = @()
    if ($args.outfile) { $params += "-OutFile"; $params += $args.outfile }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @params 2>&1 | Out-String
}

function Invoke-DevinDoctor {
    param($args)
    $script = "D:\DevOptimizer\scripts\devin\Check-DevinDoctor.ps1"
    $params = @()
    if ($args.skipInstall) { $params += "-SkipInstall" }
    if ($args.jsonOnly) { $params += "-JsonOnly" }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @params 2>&1 | Out-String
}

function Invoke-DevinMaintenance {
    param($args)
    $script = "D:\DevOptimizer\scripts\devin\Invoke-DevinDailyMaintenance.ps1"
    $params = @()
    if ($args.logRetentionDays) { $params += "-LogRetentionDays"; $params += $args.logRetentionDays }
    if ($args.reportRetentionDays) { $params += "-ReportRetentionDays"; $params += $args.reportRetentionDays }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @params 2>&1 | Out-String
}

function Invoke-DevinRepair {
    param($args)
    $script = "D:\DevOptimizer\scripts\devin\Repair-Devin.ps1"
    $params = @()
    if ($args.fixBundle) { $params += "-FixBundle" }
    if ($args.cleanLeftovers) { $params += "-CleanLeftovers" }
    if ($args.pruneServerLogs) { $params += "-PruneServerLogs" }
    if ($args.days) { $params += "-Days"; $params += $args.days }
    if ($args.force) { $params += "-Force" }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @params 2>&1 | Out-String
}

function Invoke-DevinCleanupACP {
    param($args)
    $script = "D:\DevOptimizer\scripts\prune-acp.ps1"
    # Use the prune-acp script with parameters
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
        $acpDir = Join-Path \$env:APPDATA 'devin\User\acp-messages'
        $cutoff = (Get-Date).AddDays(-$($args.days))
        $files = Get-ChildItem -LiteralPath \$acpDir -Filter '*.db' -File | Where-Object { `$_.LastWriteTime -lt \$cutoff }
        `$files | ForEach-Object { Write-Host \"Deleting: `$(\$_.Name) (`$([math]::Round(\$_.Length/1MB,1)) MB)\"; Remove-Item -LiteralPath \$_.FullName -Force }
        $shm = Get-ChildItem -LiteralPath \$acpDir -Filter '*.db-shm' -File | Where-Object { `$_.LastWriteTime -lt \$cutoff }
        $wal = Get-ChildItem -LiteralPath \$acpDir -Filter '*.db-wal' -File | Where-Object { `$_.LastWriteTime -lt \$cutoff }
        `$shm | ForEach-Object { Remove-Item -LiteralPath \$_.FullName -Force }
        `$wal | ForEach-Object { Remove-Item -LiteralPath \$_.FullName -Force }
        Write-Host \"Deleted `$(\$files.Count) DBs, `$(\$shm.Count) shm, `$(\$wal.Count) wal older than $($args.days) days\"
        if ($($args.removeLarge)) {
            $large = @('a3b876c1-e098-4649-811f-eccac5e74217.db','5e1ee798-b1d3-4252-9735-fe38ba1d02c9.db','23d592af-c68d-4e0a-877d-06866aabdd1f.db')
            foreach ($name in \$large) {
                \$path = Join-Path \$acpDir \$name
                if (Test-Path \$path) { \$size = (Get-Item \$path).Length; Write-Host \"Deleting large: \$name (`$([math]::Round(\$size/1MB,1)) MB)\"; Remove-Item -LiteralPath \$path -Force }
            }
        }
    " 2>&1 | Out-String
}

function Invoke-DevinTuneWindows {
    param($args)
    $script = "D:\DevOptimizer\scripts\devin\Tune-Windows-For-Devin.ps1"
    $params = @()
    if ($args.priority) { $params += "-Priority"; $params += $args.priority }
    if ($args.startup) { $params += "-RegisterStartup" }
    if ($args.defenderExclusions) { $params += "-DefenderExclusions" }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @params 2>&1 | Out-String
}

# Main loop
try {
    $stdin = [Console]::OpenStandardInput()
    $buffer = New-Object byte[] 8192
    $input = ""

    while ($true) {
        $bytesRead = $stdin.Read($buffer, 0, $buffer.Length)
        if ($bytesRead -eq 0) { break }
        $input += [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)

        # Process complete lines
        while ($input -match "`n") {
            $line = $input.Substring(0, $input.IndexOf("`n")).Trim()
            $input = $input.Substring($input.IndexOf("`n") + 1)

            if (-not $line) { continue }

            try {
                $request = $line | ConvertFrom-Json
            } catch {
                Write-McpError "null" -32700 "Parse error: $($_.Exception.Message)"
                continue
            }

            switch ($request.method) {
                "initialize"      { Handle-Initialize $request }
                "tools/list"      { Handle-ToolsList $request }
                "tools/call"      { Handle-ToolCall $request }
                "notifications/initialized" { /* ignore */ }
                default { Write-McpError $request.id -32601 "Method not found: $($request.method)" }
            }
        }
    }
} catch {
    Write-Host "MCP Server error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}