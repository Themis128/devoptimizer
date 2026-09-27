# DevOptimizer Backend System
# Comprehensive backend for all batch files with verbose descriptions

param(
    [string]$Mode = "hub",
    [string]$Action = "",
    [string]$ToolName = ""
)

# Global variables
$script:BAT_HUB = ""
$script:LogFile = ""
$script:VerboseMode = $true

# Initialize the backend system
function Initialize-Backend {
    param([string]$HubPath)
    
    $script:BAT_HUB = $HubPath
    $script:LogFile = Join-Path $HubPath "logs\backend-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    
    # Create logs directory if it doesn't exist
    $logsDir = Join-Path $HubPath "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    
    Write-Log "Backend system initialized" "INFO"
}

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "Backend"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] [$Component] $Message"
    
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logEntry
    }
    
    if ($script:VerboseMode) {
        $color = switch ($Level) {
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "INFO" { "Cyan" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}

# Check system status
function Get-SystemStatus {
    Write-Log "Checking system status..." "INFO"
    
    $status = @{
        Ollama = "OFFLINE"
        OneDrive = "OFFLINE"
        CursorAI = "OFFLINE"
        VSCode = "OFFLINE"
    }
    
    # Check Ollama
    try {
        $ollamaProcess = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
        if ($ollamaProcess) {
            $status.Ollama = "ONLINE"
            Write-Log "Ollama: ONLINE (Running)" "SUCCESS"
        } else {
            Write-Log "Ollama: OFFLINE (Not Running)" "WARNING"
        }
    } catch {
        Write-Log "Ollama: OFFLINE (Not Running)" "WARNING"
    }
    
    # Check OneDrive
    try {
        $oneDriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        if ($oneDriveProcess) {
            $status.OneDrive = "ONLINE"
            Write-Log "OneDrive: ONLINE (Running)" "SUCCESS"
        } else {
            Write-Log "OneDrive: OFFLINE (Not Running)" "WARNING"
        }
    } catch {
        Write-Log "OneDrive: OFFLINE (Not Running)" "WARNING"
    }
    
    # Check Cursor AI
    try {
        $cursorProcess = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
        if ($cursorProcess) {
            $status.CursorAI = "ONLINE"
            Write-Log "Cursor AI: ONLINE (Running)" "SUCCESS"
        } else {
            Write-Log "Cursor AI: OFFLINE (Not Running)" "WARNING"
        }
    } catch {
        Write-Log "Cursor AI: OFFLINE (Not Running)" "WARNING"
    }
    
    # Check VS Code
    try {
        $vscodeProcess = Get-Process -Name "Code" -ErrorAction SilentlyContinue
        if ($vscodeProcess) {
            $status.VSCode = "ONLINE"
            Write-Log "VS Code: ONLINE (Running)" "SUCCESS"
        } else {
            Write-Log "VS Code: OFFLINE (Not Running)" "WARNING"
        }
    } catch {
        Write-Log "VS Code: OFFLINE (Not Running)" "WARNING"
    }
    
    return $status
}

# Scan for BAT files with verbose descriptions
function Get-BATFilesWithDescriptions {
    Write-Log "Scanning for BAT files with verbose descriptions..." "INFO"
    
    $batFiles = @()
    $categories = @{
        "OLLAMA" = @()
        "CURSOR" = @()
        "M365" = @()
        "SYSTEM" = @()
        "DEV" = @()
        "AWS" = @()
        "OTHER" = @()
    }
    
    # Tool descriptions database
    $toolDescriptions = @{
        "ollama-ai-analyzer" = "AI-powered system analysis tool that uses Ollama models to analyze system performance, identify bottlenecks, suggest optimizations, and provide intelligent recommendations for system improvements."
        "ollama-intelligent-monitor" = "Intelligent system monitoring with AI assistance: real-time system monitoring, predictive analysis, anomaly detection, performance trending, and automated alert generation using AI models."
        "ollama-intelligent-optimizer" = "AI-driven system optimization tool: analyzes system configuration, identifies optimization opportunities, applies intelligent tweaks, monitors results, and continuously improves system performance using machine learning."
        "OLLAMA-MODEL-MANAGER" = "Manages Ollama AI models: install new models, remove unused models, list all available models, check model sizes and performance. Essential for maintaining your local AI model collection."
        "OLLAMA-MULTI-MODEL-SYSTEM-STATUS" = "Ollama AI integration tool for advanced AI-powered system management and automation tasks."
        "ollama-performance-scorer" = "Performance scoring and benchmarking tool: evaluates system performance across multiple metrics, generates performance scores, compares against baselines, tracks performance trends, and provides detailed performance reports."
        "ollama-predictive-maintenance" = "Predictive maintenance system using AI: monitors system health indicators, predicts potential failures, schedules preventive maintenance, tracks component lifecycles, and prevents system downtime through intelligent forecasting."
        "OLLAMA-QUICK-TESTS" = "Performs quick performance and functionality tests on Ollama models: speed tests, accuracy tests, memory usage analysis, response quality checks, and model comparison benchmarks."
        "OLLAMA-REST-INTEGRATION-COMPLETE" = "Ollama AI integration tool for advanced AI-powered system management and automation tasks."
        "ollama-script-generator" = "AI-powered script generation tool: creates custom batch scripts, PowerShell scripts, and automation scripts based on natural language descriptions, learns from existing scripts, and generates optimized code solutions."
        "OLLAMA-SERVER-MANAGER" = "Controls Ollama server operations: start/stop the Ollama service, restart server, check server status, configure server settings, and manage server resources. Critical for AI functionality."
        "OLLAMA-TROUBLESHOOTER" = "Diagnoses and fixes common Ollama issues: connection problems, model loading errors, performance issues, memory problems, and provides automated solutions for common problems."
        
        "CURSOR-AI-COMPLETE-OPTIMIZER" = "Complete Cursor AI optimization suite: optimizes Cursor AI settings, improves code completion accuracy, enhances AI response quality, configures AI models, and maximizes development productivity with intelligent AI assistance."
        "CURSOR-AI-ESSENTIAL-TOOLS" = "Essential Cursor AI development tools collection: provides core AI-powered development utilities, code analysis tools, intelligent refactoring, automated testing, and productivity enhancements for modern development workflows."
        "CURSOR-AI-GIT-CACHE-CLEAR" = "Clears Git cache for Cursor AI optimization: removes stale Git cache files, optimizes Git performance, clears AI-related cache, improves Cursor AI responsiveness, and resolves Git integration issues with AI features."
        "cursor-ai-nuxt4-optimization" = "Cursor AI development tool for enhanced AI-powered coding assistance and development productivity."
        "CURSOR-AI-OPTIMIZATION-SUITE" = "Comprehensive Cursor AI optimization suite: fine-tunes AI settings, optimizes memory usage, improves response times, configures AI models, enhances code suggestions, and maximizes AI development efficiency."
        "CURSOR-AI-TROUBLESHOOTER" = "Diagnoses and fixes Cursor AI issues: resolves AI connection problems, fixes code completion issues, troubleshoots AI model errors, optimizes AI performance, and provides solutions for common Cursor AI problems."
        
        "M365-ACCOUNTS-ENHANCER" = "Enhances Microsoft 365 account settings and configurations: optimizes account settings, improves sync performance, configures security settings, manages licenses, and enhances overall Microsoft 365 experience."
        "M365-TROUBLESHOOTER" = "Diagnoses and fixes Microsoft 365 issues: resolves authentication problems, fixes sync issues, troubleshoots Office applications, resolves licensing problems, and provides automated solutions for common M365 issues."
        "ONEDRIVE-MANAGER" = "Manages OneDrive sync and settings: optimizes sync performance, resolves sync conflicts, manages storage, configures sync settings, troubleshoots sync issues, and ensures reliable cloud file synchronization."
        
        "SYSTEM-BACKUP-MANAGER" = "Creates and manages comprehensive system backups: automated backup scheduling, incremental backups, system restore points, file versioning, backup verification, and disaster recovery preparation."
        "SYSTEM-COMPLETION-SUMMARY" = "Generates comprehensive system completion summary: system status overview, completed tasks, pending operations, system health summary, and detailed completion reports for system maintenance."
        "SYSTEM-IMPROVEMENT-PLAN" = "Creates detailed system improvement plans: identifies improvement opportunities, prioritizes optimizations, creates implementation schedules, tracks progress, and provides actionable improvement recommendations."
        "SYSTEM-PERFORMANCE-MONITOR" = "Monitors system performance metrics in real-time: CPU usage, memory consumption, disk I/O, network performance, process monitoring, performance alerts, and detailed performance reporting."
        "HEALTH-MONITOR" = "System health monitoring and diagnostics: comprehensive health checks, system diagnostics, performance analysis, health scoring, preventive maintenance, and detailed health reporting."
        "performance-optimization-template" = "Performance optimization and monitoring: system performance tuning, optimization recommendations, performance benchmarking, resource optimization, and continuous performance improvement."
        "NETWORK-MANAGER" = "Network configuration and diagnostics: network optimization, connection troubleshooting, bandwidth management, network security, performance monitoring, and network health analysis."
        "SECURITY-MANAGER" = "Security settings and monitoring: security configuration, threat detection, security scanning, vulnerability assessment, security hardening, and comprehensive security management."
        
        "DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER" = "DevOptimizer comprehensive launcher: central hub for all development tools, system optimization, AI integration, and development environment management with intelligent automation and productivity features."
        "DEVOPTIMIZER-HUB-VERBOSE-DESCRIPTIONS" = "DevOptimizer comprehensive launcher: central hub for all development tools, system optimization, AI integration, and development environment management with intelligent automation and productivity features."
        "DEVTOOLS-MANAGER" = "Development tools manager: manages development environment, installs development tools, configures development settings, optimizes development workflow, and provides comprehensive development tool management."
        
        "AWS-IAC-MANAGER-ASCII" = "ASCII-based AWS IAC management: provides text-based interface for AWS infrastructure management, ASCII diagrams for infrastructure visualization, command-line infrastructure management, and simplified IAC operations."
        "AWS-IAC-MANAGER" = "Infrastructure as Code management: manages AWS infrastructure using code, automates infrastructure deployment, manages Terraform configurations, handles infrastructure versioning, and provides infrastructure lifecycle management."
        "AWS-POWERSHELL-MODULES-DOWNLOADER" = "Downloads AWS PowerShell modules: automatically downloads and installs AWS PowerShell modules, manages module versions, configures AWS PowerShell environment, and ensures up-to-date AWS PowerShell integration."
        "AWS-TERRAFORM-ANALYZER" = "Analyzes Terraform configurations: validates Terraform code, analyzes infrastructure configurations, identifies optimization opportunities, provides security recommendations, and generates detailed Terraform analysis reports."
    }
    
    # Scan for actual BAT files
    $batFiles = Get-ChildItem -Path $script:BAT_HUB -Recurse -Filter "*.bat" | ForEach-Object {
        $baseName = $_.BaseName
        $description = if ($toolDescriptions.ContainsKey($baseName)) {
            $toolDescriptions[$baseName]
        } else {
            "Utility tool for system management, optimization, and automation tasks."
        }
        
        @{
            Name = $baseName
            Path = $_.FullName
            Description = $description
            Category = Get-ToolCategory $baseName
        }
    }
    
    # Categorize tools
    foreach ($tool in $batFiles) {
        $categories[$tool.Category] += $tool
    }
    
    return @{
        Tools = $batFiles
        Categories = $categories
        TotalCount = $batFiles.Count
    }
}

# Determine tool category
function Get-ToolCategory {
    param([string]$ToolName)
    
    $ollamaKeywords = @("ollama", "OLLAMA")
    $cursorKeywords = @("cursor", "CURSOR")
    $m365Keywords = @("M365", "ONEDRIVE")
    $systemKeywords = @("SYSTEM", "HEALTH", "NETWORK", "SECURITY", "performance")
    $devKeywords = @("DEV", "DEVOPTIMIZER", "DEVTOOLS")
    $awsKeywords = @("AWS")
    
    if ($ollamaKeywords | Where-Object { $ToolName -like "*$_*" }) { return "OLLAMA" }
    if ($cursorKeywords | Where-Object { $ToolName -like "*$_*" }) { return "CURSOR" }
    if ($m365Keywords | Where-Object { $ToolName -like "*$_*" }) { return "M365" }
    if ($systemKeywords | Where-Object { $ToolName -like "*$_*" }) { return "SYSTEM" }
    if ($devKeywords | Where-Object { $ToolName -like "*$_*" }) { return "DEV" }
    if ($awsKeywords | Where-Object { $ToolName -like "*$_*" }) { return "AWS" }
    
    return "OTHER"
}

# Display hub interface
function Show-HubInterface {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "                   DEVOPTIMIZER BAT HUB" -ForegroundColor Cyan
    Write-Host "                  Verbose Descriptions Version" -ForegroundColor Cyan
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "Initializing DevOptimizer BAT Hub..." "STATUS"
    Write-Log "Scanning for all available BAT files..." "INFO"
    Write-Log "Enhanced version with detailed verbose descriptions" "INFO"
    Write-Host ""
    Write-Log "DevOptimizer BAT Hub initialized" "SUCCESS"
    Write-Host ""
    
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host "                      SYSTEM STATUS CHECK" -ForegroundColor Cyan
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $status = Get-SystemStatus
    Write-Log "System status check completed" "INFO"
    Write-Host ""
    
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host "                      AVAILABLE BAT TOOLS" -ForegroundColor Cyan
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "Scanning for BAT files with verbose descriptions..." "INFO"
    Write-Host ""
    
    $batData = Get-BATFilesWithDescriptions
    $toolNumber = 1
    
    # Display tools by category
    foreach ($category in @("OLLAMA", "CURSOR", "M365", "SYSTEM", "DEV", "AWS", "OTHER")) {
        if ($batData.Categories[$category].Count -gt 0) {
            $categoryName = switch ($category) {
                "OLLAMA" { "OLLAMA TOOLS" }
                "CURSOR" { "CURSOR AI TOOLS" }
                "M365" { "MICROSOFT 365 TOOLS" }
                "SYSTEM" { "SYSTEM TOOLS" }
                "DEV" { "DEVELOPMENT TOOLS" }
                "AWS" { "AWS TOOLS" }
                "OTHER" { "OTHER TOOLS" }
            }
            
            Write-Host "[$categoryName]" -ForegroundColor Yellow
            Write-Host ""
            
            foreach ($tool in $batData.Categories[$category]) {
                Write-Host "[$toolNumber] $($tool.Name)" -ForegroundColor White
                Write-Host "    >>> $($tool.Description)" -ForegroundColor Gray
                Write-Host ""
                $toolNumber++
            }
        }
    }
    
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host "[SUMMARY] Found $($batData.TotalCount) BAT tools available" -ForegroundColor Green
    Write-Host "[OLLAMA: $($batData.Categories.OLLAMA.Count)] [CURSOR: $($batData.Categories.CURSOR.Count)] [M365: $($batData.Categories.M365.Count)] [SYSTEM: $($batData.Categories.SYSTEM.Count)] [DEV: $($batData.Categories.DEV.Count)] [AWS: $($batData.Categories.AWS.Count)] [OTHER: $($batData.Categories.OTHER.Count)]" -ForegroundColor Green
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[0] Exit Hub" -ForegroundColor Red
    Write-Host ""
    Write-Host "Enter your choice (number): " -NoNewline -ForegroundColor White
}

# Execute tool
function Invoke-Tool {
    param([string]$ToolName)
    
    Write-Log "Executing tool: $ToolName" "INFO"
    
    # Find the tool file
    $toolFile = Get-ChildItem -Path $script:BAT_HUB -Recurse -Filter "*.bat" | Where-Object { $_.BaseName -eq $ToolName }
    
    if ($toolFile) {
        Write-Log "Found tool file: $($toolFile.FullName)" "SUCCESS"
        try {
            & $toolFile.FullName
        } catch {
            Write-Log "Error executing tool: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "Tool not found: $ToolName" "ERROR"
    }
}

# Main execution
function Main {
    # Determine BAT_HUB path
    $hubPath = ""
    if (Test-Path "D:\DevOptimizer") {
        $hubPath = "D:\DevOptimizer"
    } elseif (Test-Path "C:\DevOptimizer") {
        $hubPath = "C:\DevOptimizer"
    } else {
        $hubPath = Split-Path -Parent $PSScriptRoot
    }
    
    Initialize-Backend -HubPath $hubPath
    
    switch ($Mode.ToLower()) {
        "hub" {
            Show-HubInterface
        }
        "status" {
            Get-SystemStatus
        }
        "scan" {
            Get-BATFilesWithDescriptions
        }
        "execute" {
            Invoke-Tool -ToolName $ToolName
        }
        default {
            Show-HubInterface
        }
    }
}

# Run main function
Main
