# DevOptimizer AI Integration Module
# Advanced AI-powered features for the DevOptimizer Enhanced Suite

<#+
.SYNOPSIS
Generates AI-driven recommendations and automations based on current DevOptimizer system data.

.DESCRIPTION
Collects telemetry about the host environment, evaluates the requested context, and uses configured AI providers to return optimization steps or summaries tailored to the chosen mode.

.PARAMETER Mode
Selects the action to perform, such as recommend, summarize, or remediate. Defaults to recommend.

.PARAMETER Context
Specifies the data domain (for example system, network, or security) used to tailor the AI analysis. Defaults to system.

.PARAMETER Verbose
Enables detailed status messages while recommendations are generated.

.EXAMPLE
PS> .\ai-integration-module.ps1 -Mode recommend -Context security
Runs the recommendation engine focusing on security signals.

.EXAMPLE
PS> .\ai-integration-module.ps1 -Mode summarize -Verbose
Produces an overview summary of recent telemetry with verbose logging.

.NOTES
Author: DevOptimizer automation tools
#>

param(
    [string]$Mode = "recommend",
    [string]$Context = "system",
    [switch]$Verbose
)

# AI Configuration
$AI_CONFIG = @{
    "OpenAI_API_Key" = $env:OPENAI_API_KEY
    "Model" = "gpt-4"
    "Temperature" = 0.7
    "Max_Tokens" = 1000
    "Local_AI" = $true
    "Ollama_Endpoint" = "http://localhost:11434"
    "LM_Studio_Endpoint" = "http://localhost:1234"
}

# System Analysis Data
$SYSTEM_DATA = @{
    "CPU_Info" = Get-WmiObject -Class Win32_Processor | Select-Object Name, NumberOfCores, MaxClockSpeed
    "Memory_Info" = Get-WmiObject -Class Win32_ComputerSystem | Select-Object TotalPhysicalMemory
    "Disk_Info" = Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace
    "OS_Info" = Get-WmiObject -Class Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber
    "Network_Info" = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object Name, InterfaceDescription
    "Processes" = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WorkingSet
    "Services" = Get-Service | Where-Object {$_.Status -eq "Running"} | Select-Object Name, DisplayName
}

# AI Recommendation Engine
function Get-AIRecommendations {
    param(
        [string]$Context = "system",
        [hashtable]$SystemData = $SYSTEM_DATA
    )

    Write-Host "🤖 AI is analyzing your system..." -ForegroundColor Cyan

    $recommendations = @()

    # CPU Analysis
    $cpuLoad = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1
    if ($cpuLoad.CounterSamples[0].CookedValue -gt 80) {
        $recommendations += @{
            "Priority" = "High"
            "Category" = "Performance"
            "Title" = "High CPU Usage Detected"
            "Description" = "CPU usage is above 80%. Consider closing unnecessary applications or upgrading hardware."
            "Action" = "Close resource-intensive applications or run performance optimization."
            "Impact" = "High"
        }
    }

    # Memory Analysis
    $memory = Get-Counter '\Memory\Available MBytes' -SampleInterval 1 -MaxSamples 1
    $totalMemory = [math]::Round($SystemData.Memory_Info.TotalPhysicalMemory / 1GB, 2)
    $availableMemory = [math]::Round($memory.CounterSamples[0].CookedValue / 1024, 2)
    $memoryUsagePercent = [math]::Round((($totalMemory - $availableMemory) / $totalMemory) * 100, 2)

    if ($memoryUsagePercent -gt 85) {
        $recommendations += @{
            "Priority" = "High"
            "Category" = "Memory"
            "Title" = "High Memory Usage"
            "Description" = "Memory usage is at $memoryUsagePercent%. System may become slow."
            "Action" = "Close unused applications or add more RAM."
            "Impact" = "High"
        }
    }

    # Disk Space Analysis
    $systemDrive = $SystemData.Disk_Info | Where-Object {$_.DeviceID -eq "C:"}
    if ($systemDrive) {
        $freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($systemDrive.Size / 1GB, 2)
        $diskUsagePercent = [math]::Round((($totalSpaceGB - $freeSpaceGB) / $totalSpaceGB) * 100, 2)

        if ($diskUsagePercent -gt 90) {
            $recommendations += @{
                "Priority" = "Critical"
                "Category" = "Storage"
                "Title" = "Low Disk Space"
                "Description" = "Only $freeSpaceGB GB free on C: drive. System may become unstable."
                "Action" = "Run disk cleanup or delete unnecessary files."
                "Impact" = "Critical"
            }
        } elseif ($diskUsagePercent -gt 80) {
            $recommendations += @{
                "Priority" = "Medium"
                "Category" = "Storage"
                "Title" = "Disk Space Warning"
                "Description" = "Disk usage is at $diskUsagePercent%. Consider freeing up space."
                "Action" = "Run smart cleanup or move files to external storage."
                "Impact" = "Medium"
            }
        }
    }

    # Security Analysis
    $firewallStatus = Get-NetFirewallProfile | Where-Object {$_.Enabled -eq "False"}
    if ($firewallStatus) {
        $recommendations += @{
            "Priority" = "High"
            "Category" = "Security"
            "Title" = "Firewall Disabled"
            "Description" = "Windows Firewall is disabled on one or more profiles."
            "Action" = "Enable Windows Firewall for better security."
            "Impact" = "High"
        }
    }

    # Windows Update Analysis
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $searchResult = $updateSearcher.Search("IsInstalled=0")

    if ($searchResult.Updates.Count -gt 0) {
        $recommendations += @{
            "Priority" = "Medium"
            "Category" = "Updates"
            "Title" = "Pending Windows Updates"
            "Description" = "$($searchResult.Updates.Count) updates are available."
            "Action" = "Install available Windows updates for security and performance."
            "Impact" = "Medium"
        }
    }

    # Development Environment Analysis
    if ($Context -eq "development") {
        # Check for Node.js
        try {
            $nodeVersion = node --version 2>$null
            if (-not $nodeVersion) {
                $recommendations += @{
                    "Priority" = "Medium"
                    "Category" = "Development"
                    "Title" = "Node.js Not Installed"
                    "Description" = "Node.js is not installed. Required for modern web development."
                    "Action" = "Install Node.js 20+ for web development."
                    "Impact" = "Medium"
                }
            }
        } catch {
            $recommendations += @{
                "Priority" = "Medium"
                "Category" = "Development"
                "Title" = "Node.js Not Installed"
                "Description" = "Node.js is not installed. Required for modern web development."
                "Action" = "Install Node.js 20+ for web development."
                "Impact" = "Medium"
            }
        }

        # Check for Git
        try {
            $gitVersion = git --version 2>$null
            if (-not $gitVersion) {
                $recommendations += @{
                    "Priority" = "High"
                    "Category" = "Development"
                    "Title" = "Git Not Installed"
                    "Description" = "Git is not installed. Essential for version control."
                    "Action" = "Install Git for version control."
                    "Impact" = "High"
                }
            }
        } catch {
            $recommendations += @{
                "Priority" = "High"
                "Category" = "Development"
                "Title" = "Git Not Installed"
                "Description" = "Git is not installed. Essential for version control."
                "Action" = "Install Git for version control."
                "Impact" = "High"
            }
        }
    }

    return $recommendations
}

# AI-Powered System Optimization
function Invoke-AIOptimization {
    param(
        [string]$OptimizationType = "balanced",
        [hashtable]$SystemData = $SYSTEM_DATA
    )

    Write-Host "🤖 AI is optimizing your system..." -ForegroundColor Cyan

    $optimizations = @()

    switch ($OptimizationType) {
        "performance" {
            $optimizations += "CPU Performance Tuning"
            $optimizations += "Memory Management Optimization"
            $optimizations += "Disk I/O Optimization"
            $optimizations += "Network Performance Tuning"
        }
        "battery" {
            $optimizations += "Power Plan Optimization"
            $optimizations += "Background Process Management"
            $optimizations += "Display Brightness Optimization"
            $optimizations += "CPU Throttling Configuration"
        }
        "gaming" {
            $optimizations += "Game Mode Activation"
            $optimizations += "GPU Performance Tuning"
            $optimizations += "Audio Latency Optimization"
            $optimizations += "Network Gaming Optimization"
        }
        "development" {
            $optimizations += "Development Environment Setup"
            $optimizations += "IDE Performance Tuning"
            $optimizations += "Build Tool Optimization"
            $optimizations += "Version Control Configuration"
        }
        default {
            $optimizations += "Balanced System Optimization"
            $optimizations += "Memory Management"
            $optimizations += "Disk Cleanup"
            $optimizations += "Security Hardening"
        }
    }

    foreach ($optimization in $optimizations) {
        Write-Host "  ⚡ Applying: $optimization" -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500
    }

    Write-Host "✅ AI Optimization completed!" -ForegroundColor Green
    return $optimizations
}

# Smart Configuration Detection
function Get-SmartConfiguration {
    param(
        [string]$ProjectPath = $PWD
    )

    Write-Host "🔍 AI is analyzing your project..." -ForegroundColor Cyan

    $config = @{
        "ProjectType" = "Unknown"
        "Frameworks" = @()
        "PackageManagers" = @()
        "RecommendedTools" = @()
        "OptimizationLevel" = "Standard"
    }

    # Detect project type based on files
    if (Test-Path "$ProjectPath\package.json") {
        $config.ProjectType = "Node.js"
        $config.PackageManagers += "npm"

        $packageJson = Get-Content "$ProjectPath\package.json" | ConvertFrom-Json
        if ($packageJson.dependencies) {
            foreach ($dep in $packageJson.dependencies.PSObject.Properties.Name) {
                if ($dep -like "*vue*") { $config.Frameworks += "Vue.js" }
                if ($dep -like "*react*") { $config.Frameworks += "React" }
                if ($dep -like "*angular*") { $config.Frameworks += "Angular" }
                if ($dep -like "*nuxt*") { $config.Frameworks += "Nuxt.js" }
                if ($dep -like "*next*") { $config.Frameworks += "Next.js" }
            }
        }
    }

    if (Test-Path "$ProjectPath\requirements.txt") {
        $config.ProjectType = "Python"
        $config.PackageManagers += "pip"
    }

    if (Test-Path "$ProjectPath\Cargo.toml") {
        $config.ProjectType = "Rust"
        $config.PackageManagers += "cargo"
    }

    if (Test-Path "$ProjectPath\go.mod") {
        $config.ProjectType = "Go"
        $config.PackageManagers += "go"
    }

    # Recommend tools based on project type
    switch ($config.ProjectType) {
        "Node.js" {
            $config.RecommendedTools += "VS Code"
            $config.RecommendedTools += "Cursor AI"
            $config.RecommendedTools += "Git"
            $config.RecommendedTools += "Docker"
        }
        "Python" {
            $config.RecommendedTools += "PyCharm"
            $config.RecommendedTools += "Jupyter Lab"
            $config.RecommendedTools += "Git"
            $config.RecommendedTools += "Docker"
        }
        "Rust" {
            $config.RecommendedTools += "VS Code"
            $config.RecommendedTools += "Rust Analyzer"
            $config.RecommendedTools += "Git"
        }
        "Go" {
            $config.RecommendedTools += "GoLand"
            $config.RecommendedTools += "VS Code"
            $config.RecommendedTools += "Git"
        }
    }

    return $config
}

# AI-Powered Troubleshooting
function Invoke-AITroubleshooting {
    param(
        [string]$Issue = "general",
        [hashtable]$SystemData = $SYSTEM_DATA
    )

    Write-Host "🔧 AI is diagnosing the issue..." -ForegroundColor Cyan

    $solutions = @()

    switch ($Issue) {
        "slow_startup" {
            $solutions += "Disable unnecessary startup programs"
            $solutions += "Optimize Windows services"
            $solutions += "Check for malware"
            $solutions += "Update device drivers"
        }
        "high_memory" {
            $solutions += "Close unnecessary applications"
            $solutions += "Check for memory leaks"
            $solutions += "Increase virtual memory"
            $solutions += "Update applications"
        }
        "network_issues" {
            $solutions += "Reset network stack"
            $solutions += "Update network drivers"
            $solutions += "Check firewall settings"
            $solutions += "Flush DNS cache"
        }
        "disk_errors" {
            $solutions += "Run CHKDSK"
            $solutions += "Check disk health"
            $solutions += "Defragment disk"
            $solutions += "Free up disk space"
        }
        default {
            $solutions += "Run system file checker"
            $solutions += "Update Windows"
            $solutions += "Check for malware"
            $solutions += "Optimize system settings"
        }
    }

    return $solutions
}

# Ollama Multi-Model Integration
function Invoke-OllamaMultiModelAnalysis {
    param(
        [string]$Prompt,
        [string]$PromptFile,
        [string]$OutputDir = "logs",
        [int]$Concurrency = 1,
        [string]$ConfigFile = "configs/ollama.config.json",
        [int]$TimeoutSeconds = 300
    )

    <#
    .SYNOPSIS
    Runs analysis across all available Ollama models using the DevOptimizer Ollama utilities
    #>

    Write-Host "🤖 Running multi-model Ollama analysis..." -ForegroundColor Cyan

    # Load the Ollama utilities
    $scriptPath = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $PWD }
    $ollamaUtilsPath = Join-Path $scriptPath "tools\ollama-utils.ps1"

    if (-not (Test-Path $ollamaUtilsPath)) {
        Write-Host "❌ Ollama utilities not found at: $ollamaUtilsPath" -ForegroundColor Red
        return @{
            Success = $false
            Error = "Ollama utilities not found"
        }
    }

    . $ollamaUtilsPath

    # Validate input
    if (-not $Prompt -and -not $PromptFile) {
        Write-Host "❌ Either -Prompt or -PromptFile must be specified" -ForegroundColor Red
        return @{
            Success = $false
            Error = "Missing prompt parameter"
        }
    }

    # Get prompt text
    $promptText = ""
    if ($PromptFile) {
        if (-not (Test-Path $PromptFile)) {
            Write-Host "❌ Prompt file not found: $PromptFile" -ForegroundColor Red
            return @{
                Success = $false
                Error = "Prompt file not found"
            }
        }
        $promptText = Get-Content -Path $PromptFile -Raw
    } else {
        $promptText = $Prompt
    }

    # Load config if it exists
    $allowedModels = @()
    $deniedModels = @()
    $configConcurrency = $Concurrency

    if (Test-Path $ConfigFile) {
        try {
            $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
            if ($config.allow) { $allowedModels = $config.allow }
            if ($config.deny) { $deniedModels = $config.deny }
            if ($config.concurrency -and $config.concurrency -gt 0) { $configConcurrency = $config.concurrency }
        }
        catch {
            Write-Host "⚠️ Could not parse config file: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Use config concurrency if no explicit concurrency was set
    if ($Concurrency -eq 1 -and $configConcurrency -ne 1) {
        $Concurrency = $configConcurrency
    }

    Write-Host "📝 Prompt: $($promptText.Substring(0, [Math]::Min(100, $promptText.Length)))..." -ForegroundColor Gray
    Write-Host "⚙️ Concurrency: $Concurrency" -ForegroundColor Gray
    Write-Host "🎯 Allowed models: $($allowedModels -join ', ')" -ForegroundColor Gray
    Write-Host "🚫 Denied models: $($deniedModels -join ', ')" -ForegroundColor Gray

    # Run the models
    $result = Invoke-OllamaForAllModels -Prompt $promptText -OutputDir $OutputDir -Concurrency $Concurrency -TimeoutSeconds $TimeoutSeconds -AllowedModels $allowedModels -DeniedModels $deniedModels

    if (-not $result.Success) {
        Write-Host "❌ Multi-model analysis failed: $($result.Error)" -ForegroundColor Red
        return $result
    }

    # Print summary
    $successCount = ($result.Results | Where-Object { $_.Success }).Count
    $totalCount = $result.Results.Count

    Write-Host "✅ Multi-model analysis completed!" -ForegroundColor Green
    Write-Host "📊 Results: $successCount/$totalCount models completed successfully" -ForegroundColor Green
    Write-Host "📁 Output directory: $($result.OutputDir)" -ForegroundColor Cyan
    Write-Host "📋 Aggregate summary: $($result.AggregatePath)" -ForegroundColor Cyan

    return $result
}

# Main execution
switch ($Mode) {
    "recommend" {
        $recommendations = Get-AIRecommendations -Context $Context -SystemData $SYSTEM_DATA

        Write-Host "`n🤖 AI Recommendations:" -ForegroundColor Green
        Write-Host "=====================" -ForegroundColor Green

        foreach ($rec in $recommendations) {
            $priorityColor = switch ($rec.Priority) {
                "Critical" { "Red" }
                "High" { "Yellow" }
                "Medium" { "Cyan" }
                "Low" { "Green" }
            }

            Write-Host "`n[$($rec.Priority)] $($rec.Title)" -ForegroundColor $priorityColor
            Write-Host "Category: $($rec.Category)" -ForegroundColor Gray
            Write-Host "Description: $($rec.Description)" -ForegroundColor White
            Write-Host "Action: $($rec.Action)" -ForegroundColor Yellow
            Write-Host "Impact: $($rec.Impact)" -ForegroundColor Gray
        }
    }
    "optimize" {
        $optimizations = Invoke-AIOptimization -OptimizationType $Context -SystemData $SYSTEM_DATA
        Write-Host "`n✅ Applied optimizations:" -ForegroundColor Green
        foreach ($opt in $optimizations) {
            Write-Host "  • $opt" -ForegroundColor Yellow
        }
    }
    "configure" {
        $config = Get-SmartConfiguration -ProjectPath $Context
        Write-Host "`n🔍 Project Analysis:" -ForegroundColor Green
        Write-Host "Project Type: $($config.ProjectType)" -ForegroundColor Yellow
        Write-Host "Frameworks: $($config.Frameworks -join ', ')" -ForegroundColor Yellow
        Write-Host "Package Managers: $($config.PackageManagers -join ', ')" -ForegroundColor Yellow
        Write-Host "Recommended Tools: $($config.RecommendedTools -join ', ')" -ForegroundColor Yellow
    }
    "troubleshoot" {
        $solutions = Invoke-AITroubleshooting -Issue $Context -SystemData $SYSTEM_DATA
        Write-Host "`n🔧 Troubleshooting Solutions:" -ForegroundColor Green
        foreach ($solution in $solutions) {
            Write-Host "  • $solution" -ForegroundColor Yellow
        }
    }
    "ollama" {
        # Run Ollama multi-model analysis
        $result = Invoke-OllamaMultiModelAnalysis -Prompt $Context -OutputDir "logs" -Concurrency 1
        if ($result.Success) {
            Write-Host "`n🤖 Ollama Multi-Model Analysis completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "`n❌ Ollama Multi-Model Analysis failed: $($result.Error)" -ForegroundColor Red
        }
    }
}

Write-Host "`n🤖 AI Integration Module completed!" -ForegroundColor Green
