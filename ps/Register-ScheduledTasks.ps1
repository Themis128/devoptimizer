# DevOptimizer Scheduled Tasks Registration Script
# Run with: pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Register-ScheduledTasks.ps1"

param(
    [string]$TasksDir = "D:\DevOptimizer\tasks",
    [switch]$Unregister = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = 'Stop'

Write-Host "DevOptimizer Scheduled Tasks Management" -ForegroundColor Green
Write-Host "Tasks Directory: $TasksDir" -ForegroundColor Yellow

try {
    # Check if running as administrator
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $IsAdmin) {
        Write-Error "This script must be run as administrator to manage scheduled tasks"
        exit 1
    }

    # Get task files
    $TaskFiles = Get-ChildItem -Path $TasksDir -Filter "*.xml" | Sort-Object Name

    if ($TaskFiles.Count -eq 0) {
        Write-Warning "No task files found in: $TasksDir"
        exit 0
    }

    Write-Host "Found $($TaskFiles.Count) task files" -ForegroundColor Blue

    $Results = @{
        timestamp = Get-Date
        operation = if ($Unregister) { "unregister" } else { "register" }
        tasks = @()
        errors = @()
    }

    foreach ($TaskFile in $TaskFiles) {
        $TaskName = $TaskFile.BaseName
        $TaskPath = $TaskFile.FullName

        Write-Host "`nProcessing task: $TaskName" -ForegroundColor Yellow

        try {
            if ($Unregister) {
                # Unregister task
                $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

                if ($ExistingTask) {
                    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$(-not $Force)

                    $Results.tasks += @{
                        name = $TaskName
                        action = "unregistered"
                        status = "success"
                    }

                    Write-Host "✓ Unregistered task: $TaskName" -ForegroundColor Green
                } else {
                    Write-Host "⚠ Task not found: $TaskName" -ForegroundColor Yellow

                    $Results.tasks += @{
                        name = $TaskName
                        action = "unregistered"
                        status = "not_found"
                    }
                }
            } else {
                # Register task
                $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

                if ($ExistingTask -and -not $Force) {
                    Write-Host "⚠ Task already exists: $TaskName" -ForegroundColor Yellow
                    Write-Host "Use -Force to overwrite existing tasks" -ForegroundColor Yellow

                    $Results.tasks += @{
                        name = $TaskName
                        action = "register"
                        status = "already_exists"
                    }
                    continue
                }

                if ($ExistingTask -and $Force) {
                    # Unregister existing task first
                    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
                    Write-Host "✓ Removed existing task: $TaskName" -ForegroundColor Yellow
                }

                # Register new task
                Register-ScheduledTask -Xml (Get-Content $TaskPath -Raw) -TaskName $TaskName -Force

                $Results.tasks += @{
                    name = $TaskName
                    action = "registered"
                    status = "success"
                    file = $TaskPath
                }

                Write-Host "✓ Registered task: $TaskName" -ForegroundColor Green
            }

        } catch {
            $Results.errors += @{
                task = $TaskName
                action = if ($Unregister) { "unregister" } else { "register" }
                error = $_.Exception.Message
            }

            Write-Error "Failed to process task '$TaskName': $_"
        }
    }

    # Display registered tasks
    if (-not $Unregister) {
        Write-Host "`nRegistered DevOptimizer tasks:" -ForegroundColor Blue

        $DevOptimizerTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*DevOptimizer*" }

        if ($DevOptimizerTasks) {
            foreach ($Task in $DevOptimizerTasks) {
                $State = $Task.State.ToString()
                $NextRun = $Task.NextRunTime
                $LastRun = $Task.LastRunTime

                Write-Host "  - $($Task.TaskName)" -ForegroundColor Cyan
                Write-Host "    State: $State" -ForegroundColor White
                Write-Host "    Next Run: $NextRun" -ForegroundColor White
                Write-Host "    Last Run: $LastRun" -ForegroundColor White
                Write-Host ""
            }
        } else {
            Write-Host "  No DevOptimizer tasks found" -ForegroundColor Yellow
        }
    }

    # Save results
    $ResultsFile = "D:\DevOptimizer\logs\task_registration_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

    if (-not (Test-Path "D:\DevOptimizer\logs")) {
        New-Item -ItemType Directory -Path "D:\DevOptimizer\logs" -Force | Out-Null
    }

    $Results | ConvertTo-Json -Depth 3 | Out-File -FilePath $ResultsFile -Encoding UTF8
    Write-Host "✓ Results saved to: $ResultsFile" -ForegroundColor Green

    # Display summary
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "SCHEDULED TASKS MANAGEMENT COMPLETED" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green

    $SuccessfulTasks = ($Results.tasks | Where-Object { $_.status -eq "success" }).Count
    $FailedTasks = $Results.errors.Count

    Write-Host "Operation: $($Results.operation)" -ForegroundColor White
    Write-Host "Tasks processed: $($Results.tasks.Count)" -ForegroundColor White
    Write-Host "Successful: $SuccessfulTasks" -ForegroundColor Green
    Write-Host "Failed: $FailedTasks" -ForegroundColor Red

    if ($Results.errors.Count -gt 0) {
        Write-Host "`nErrors encountered:" -ForegroundColor Red
        foreach ($Error in $Results.errors) {
            Write-Host "- $($Error.task): $($Error.error)" -ForegroundColor Red
        }
    }

    Write-Host "`nResults file: $ResultsFile" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Green

    # Provide usage instructions
    if (-not $Unregister) {
        Write-Host "`nUsage Instructions:" -ForegroundColor Blue
        Write-Host "1. Tasks will run automatically according to their schedules" -ForegroundColor White
        Write-Host "2. Monitor task execution in Task Scheduler (taskschd.msc)" -ForegroundColor White
        Write-Host "3. Check logs in D:\DevOptimizer\logs for execution results" -ForegroundColor White
        Write-Host "4. To unregister tasks, run this script with -Unregister" -ForegroundColor White
    }

} catch {
    Write-Error "Scheduled tasks management failed: $_"
    exit 1
}
