# DevOptimizer AI Analysis Script
# Run with: pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Run-Analysis.ps1"

param(
    [string]$MetricsDir = "D:\DevOptimizer\metrics",
    [string]$LogsDir = "D:\DevOptimizer\logs",
    [string]$OutputDir = "D:\DevOptimizer\ai-analysis",
    [string]$Model = "llama3.1",
    [switch]$SystemAnalysis = $true,
    [switch]$LogAnalysis = $true,
    [switch]$GenerateRemediation = $true
)

$ErrorActionPreference = 'Stop'

Write-Host "Starting DevOptimizer AI Analysis..." -ForegroundColor Green
Write-Host "Metrics Directory: $MetricsDir" -ForegroundColor Yellow
Write-Host "Logs Directory: $LogsDir" -ForegroundColor Yellow
Write-Host "Output Directory: $OutputDir" -ForegroundColor Yellow
Write-Host "Model: $Model" -ForegroundColor Yellow

try {
    # Check if Ollama is available
    Write-Host "`nChecking Ollama availability..." -ForegroundColor Blue
    try {
        $OllamaVersion = ollama --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Ollama is available" -ForegroundColor Green
        } else {
            throw "Ollama not responding"
        }
    } catch {
        Write-Error "Ollama not available. Please install and start Ollama first."
        exit 1
    }

    # Check if model is available
    Write-Host "`nChecking model availability..." -ForegroundColor Blue
    try {
        $AvailableModels = ollama list
        if ($AvailableModels -match $Model) {
            Write-Host "✓ Model '$Model' is available" -ForegroundColor Green
        } else {
            Write-Warning "Model '$Model' not found. Available models:"
            Write-Host $AvailableModels -ForegroundColor Yellow
            Write-Host "Please install the model first: ollama pull $Model" -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-Error "Failed to check model availability: $_"
        exit 1
    }

    # Create output directory
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Get latest metrics files
    Write-Host "`nGathering metrics data..." -ForegroundColor Blue
    $MetricsFiles = @()
    if (Test-Path $MetricsDir) {
        $MetricsFiles = Get-ChildItem -Path $MetricsDir -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
        Write-Host "✓ Found $($MetricsFiles.Count) metrics files" -ForegroundColor Green
    } else {
        Write-Warning "Metrics directory not found: $MetricsDir"
    }

    # Get latest log files
    Write-Host "`nGathering log data..." -ForegroundColor Blue
    $LogFiles = @()
    if (Test-Path $LogsDir) {
        $LogFiles = Get-ChildItem -Path $LogsDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
        Write-Host "✓ Found $($LogFiles.Count) log files" -ForegroundColor Green
    } else {
        Write-Warning "Logs directory not found: $LogsDir"
    }

    # System Analysis
    if ($SystemAnalysis) {
        Write-Host "`nRunning system analysis..." -ForegroundColor Blue

        # Prepare system data summary
        $SystemData = @{
            metrics_files = $MetricsFiles | ForEach-Object { @{
                name = $_.Name
                size = $_.Length
                modified = $_.LastWriteTime
            }}
            log_files = $LogFiles | ForEach-Object { @{
                name = $_.Name
                size = $_.Length
                modified = $_.LastWriteTime
            }}
            collection_time = Get-Date
            system_info = @{
                hostname = $env:COMPUTERNAME
                os_version = (Get-WmiObject Win32_OperatingSystem).Caption
                architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
                total_memory = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
                cpu_count = (Get-WmiObject Win32_Processor).NumberOfCores
            }
        }

        # Create prompt for system analysis
        $SystemPrompt = @"
You are a Windows system optimization expert. Analyze the following system data and provide:

1. Key performance issues identified
2. Root cause analysis
3. Specific remediation steps
4. Priority levels (High/Medium/Low)

System Data:
$($SystemData | ConvertTo-Json -Depth 3)

Please provide a structured analysis focusing on:
- CPU utilization patterns
- Memory usage trends
- Disk I/O bottlenecks
- Network performance issues
- Process optimization opportunities
- System health indicators

Format your response as JSON with this structure:
{
    "findings": [
        {
            "category": "CPU|Memory|Disk|Network|Process|System",
            "issue": "description",
            "severity": "High|Medium|Low",
            "impact": "description"
        }
    ],
    "recommendations": [
        {
            "category": "CPU|Memory|Disk|Network|Process|System",
            "action": "specific action",
            "priority": "High|Medium|Low",
            "estimated_impact": "description"
        }
    ]
}
"@

        # Run AI analysis
        Write-Host "Running AI system analysis..." -ForegroundColor Yellow
        $AnalysisOutput = $SystemPrompt | ollama run $Model

        # Save analysis results
        $SystemAnalysisFile = Join-Path $OutputDir "system_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $AnalysisResults = @{
            timestamp = Get-Date
            model_used = $Model
            input_data = $SystemData
            raw_response = $AnalysisOutput
            findings = @()
            recommendations = @()
        }

        # Try to parse JSON response
        try {
            $JsonStart = $AnalysisOutput.IndexOf('{')
            $JsonEnd = $AnalysisOutput.LastIndexOf('}') + 1

            if ($JsonStart -ge 0 -and $JsonEnd -gt $JsonStart) {
                $JsonText = $AnalysisOutput.Substring($JsonStart, $JsonEnd - $JsonStart)
                $ParsedResponse = $JsonText | ConvertFrom-Json

                $AnalysisResults.findings = $ParsedResponse.findings
                $AnalysisResults.recommendations = $ParsedResponse.recommendations
            }
        } catch {
            Write-Warning "Could not parse JSON response, saving as raw text"
        }

        $AnalysisResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $SystemAnalysisFile -Encoding UTF8
        Write-Host "✓ System analysis saved to: $SystemAnalysisFile" -ForegroundColor Green
    }

    # Log Analysis
    if ($LogAnalysis -and $LogFiles.Count -gt 0) {
        Write-Host "`nRunning log analysis..." -ForegroundColor Blue

        # Prepare log data summary
        $LogData = @()
        foreach ($LogFile in $LogFiles) {
            try {
                $LogContent = Get-Content $LogFile -TotalCount 100 -ErrorAction SilentlyContinue
                $LogData += @{
                    file = $LogFile.Name
                    size = $LogFile.Length
                    sample_lines = $LogContent
                }
            } catch {
                Write-Warning "Could not read log file: $($LogFile.Name)"
            }
        }

        # Create prompt for log analysis
        $LogPrompt = @"
You are a Windows system log analysis expert. Analyze the following log data and identify:

1. Critical errors and warnings
2. Performance issues
3. Security concerns
4. System stability problems
5. Recommended actions

Log Files Summary:
$($LogData | ConvertTo-Json -Depth 3)

Provide a structured analysis focusing on:
- Error patterns and frequency
- Performance degradation indicators
- Security events
- System health trends
- Maintenance recommendations

Format your response as JSON with this structure:
{
    "critical_issues": [
        {
            "type": "Error|Warning|Performance|Security",
            "description": "issue description",
            "severity": "Critical|High|Medium|Low",
            "affected_components": ["component1", "component2"]
        }
    ],
    "recommendations": [
        {
            "action": "specific action",
            "priority": "Critical|High|Medium|Low",
            "category": "Maintenance|Security|Performance|Configuration"
        }
    ]
}
"@

        # Run AI analysis
        Write-Host "Running AI log analysis..." -ForegroundColor Yellow
        $LogAnalysisOutput = $LogPrompt | ollama run $Model

        # Save log analysis results
        $LogAnalysisFile = Join-Path $OutputDir "log_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $LogAnalysisResults = @{
            timestamp = Get-Date
            model_used = $Model
            input_data = $LogData
            raw_response = $LogAnalysisOutput
            critical_issues = @()
            recommendations = @()
        }

        # Try to parse JSON response
        try {
            $JsonStart = $LogAnalysisOutput.IndexOf('{')
            $JsonEnd = $LogAnalysisOutput.LastIndexOf('}') + 1

            if ($JsonStart -ge 0 -and $JsonEnd -gt $JsonStart) {
                $JsonText = $LogAnalysisOutput.Substring($JsonStart, $JsonEnd - $JsonStart)
                $ParsedResponse = $JsonText | ConvertFrom-Json

                $LogAnalysisResults.critical_issues = $ParsedResponse.critical_issues
                $LogAnalysisResults.recommendations = $ParsedResponse.recommendations
            }
        } catch {
            Write-Warning "Could not parse JSON response, saving as raw text"
        }

        $LogAnalysisResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $LogAnalysisFile -Encoding UTF8
        Write-Host "✓ Log analysis saved to: $LogAnalysisFile" -ForegroundColor Green
    }

    # Generate Remediation Scripts
    if ($GenerateRemediation) {
        Write-Host "`nGenerating remediation scripts..." -ForegroundColor Blue

        # Create remediation prompt
        $RemediationPrompt = @"
You are a Windows system optimization expert. Based on the analysis results, generate specific remediation scripts.

Generate the following types of scripts:
1. PowerShell scripts for system optimizations
2. Batch files for registry modifications
3. Scheduled task configurations
4. Service management scripts

Focus on:
- Performance improvements
- Security hardening
- Maintenance automation
- Resource optimization

Format your response as a JSON object with script categories and their contents:
{
    "powershell_scripts": [
        {
            "name": "script_name",
            "description": "what it does",
            "content": "PowerShell script content"
        }
    ],
    "batch_scripts": [
        {
            "name": "script_name",
            "description": "what it does",
            "content": "batch script content"
        }
    ],
    "scheduled_tasks": [
        {
            "name": "task_name",
            "description": "what it does",
            "schedule": "frequency",
            "script_path": "path to script"
        }
    ]
}
"@

        # Run AI analysis for remediation
        Write-Host "Generating AI-powered remediation scripts..." -ForegroundColor Yellow
        $RemediationOutput = $RemediationPrompt | ollama run $Model

        # Save remediation results
        $RemediationFile = Join-Path $OutputDir "remediation_scripts_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $RemediationResults = @{
            timestamp = Get-Date
            model_used = $Model
            raw_response = $RemediationOutput
            powershell_scripts = @()
            batch_scripts = @()
            scheduled_tasks = @()
        }

        # Try to parse JSON response
        try {
            $JsonStart = $RemediationOutput.IndexOf('{')
            $JsonEnd = $RemediationOutput.LastIndexOf('}') + 1

            if ($JsonStart -ge 0 -and $JsonEnd -gt $JsonStart) {
                $JsonText = $RemediationOutput.Substring($JsonStart, $JsonEnd - $JsonStart)
                $ParsedResponse = $JsonText | ConvertFrom-Json

                $RemediationResults.powershell_scripts = $ParsedResponse.powershell_scripts
                $RemediationResults.batch_scripts = $ParsedResponse.batch_scripts
                $RemediationResults.scheduled_tasks = $ParsedResponse.scheduled_tasks
            }
        } catch {
            Write-Warning "Could not parse JSON response, saving as raw text"
        }

        $RemediationResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $RemediationFile -Encoding UTF8
        Write-Host "✓ Remediation scripts saved to: $RemediationFile" -ForegroundColor Green

        # Generate individual script files
        $ScriptsDir = Join-Path $OutputDir "generated_scripts"
        if (-not (Test-Path $ScriptsDir)) {
            New-Item -ItemType Directory -Path $ScriptsDir -Force | Out-Null
        }

        # Generate PowerShell scripts
        foreach ($Script in $RemediationResults.powershell_scripts) {
            $ScriptFile = Join-Path $ScriptsDir "$($Script.name).ps1"
            $Script.content | Out-File -FilePath $ScriptFile -Encoding UTF8
            Write-Host "✓ Generated PowerShell script: $($Script.name).ps1" -ForegroundColor Green
        }

        # Generate batch scripts
        foreach ($Script in $RemediationResults.batch_scripts) {
            $ScriptFile = Join-Path $ScriptsDir "$($Script.name).bat"
            $Script.content | Out-File -FilePath $ScriptFile -Encoding UTF8
            Write-Host "✓ Generated batch script: $($Script.name).bat" -ForegroundColor Green
        }
    }

    # Generate analysis summary
    Write-Host "`nGenerating analysis summary..." -ForegroundColor Blue
    $Summary = @{
        timestamp = Get-Date
        model_used = $Model
        metrics_files_processed = $MetricsFiles.Count
        log_files_processed = $LogFiles.Count
        analyses_completed = @()
        output_directory = $OutputDir
        status = "Completed"
    }

    if ($SystemAnalysis) { $Summary.analyses_completed += "System Analysis" }
    if ($LogAnalysis) { $Summary.analyses_completed += "Log Analysis" }
    if ($GenerateRemediation) { $Summary.analyses_completed += "Remediation Scripts" }

    $SummaryFile = Join-Path $OutputDir "analysis_summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $Summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $SummaryFile -Encoding UTF8
    Write-Host "✓ Analysis summary saved to: $SummaryFile" -ForegroundColor Green

    # Display final summary
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "AI ANALYSIS COMPLETED" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green
    Write-Host "Model Used: $Model" -ForegroundColor White
    Write-Host "Metrics Files: $($MetricsFiles.Count)" -ForegroundColor White
    Write-Host "Log Files: $($LogFiles.Count)" -ForegroundColor White
    Write-Host "Analyses Completed:" -ForegroundColor White
    foreach ($Analysis in $Summary.analyses_completed) {
        Write-Host "  - $Analysis" -ForegroundColor Cyan
    }
    Write-Host "Output Directory: $OutputDir" -ForegroundColor White
    Write-Host "Summary: $SummaryFile" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Green

} catch {
    Write-Error "AI analysis failed: $_"
    exit 1
}
