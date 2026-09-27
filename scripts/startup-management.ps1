# Startup Programs Management and Optimization Functions

function Get-StartupPrograms {
    Write-Log "Analyzing startup programs..." -Level "INFO"
    
    $startupPrograms = @()
    
    try {
        # Registry startup locations
        $startupLocations = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        )
        
        foreach ($location in $startupLocations) {
            try {
                if (Test-Path $location) {
                    $items = Get-ItemProperty -Path $location -ErrorAction SilentlyContinue
                    if ($items) {
                        $items.PSObject.Properties | Where-Object { $_.Name -notin 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider' } | ForEach-Object {
                            $startupPrograms += [PSCustomObject]@{
                                Name = $_.Name
                                Command = $_.Value
                                Location = $location
                                Type = "Registry"
                                Impact = Get-StartupImpact $_.Name $_.Value
                            }
                        }
                    }
                }
            } catch {
                Write-Log "Could not read startup location: $location" -Level "WARN"
            }
        }
        
        # Startup folder programs
        $startupFolders = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
            "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Startup"
        )
        
        foreach ($folder in $startupFolders) {
            try {
                if (Test-Path $folder) {
                    $items = Get-ChildItem -Path $folder -ErrorAction SilentlyContinue
                    foreach ($item in $items) {
                        $startupPrograms += [PSCustomObject]@{
                            Name = $item.Name
                            Command = $item.FullName
                            Location = $folder
                            Type = "Folder"
                            Impact = Get-StartupImpact $item.Name $item.FullName
                        }
                    }
                }
            } catch {
                Write-Log "Could not read startup folder: $folder" -Level "WARN"
            }
        }
        
        # Task Scheduler startup tasks
        try {
            $scheduledTasks = Get-ScheduledTask | Where-Object { 
                $_.State -eq "Ready" -and 
                $_.Triggers.CimClass.CimClassName -contains "MSFT_TaskLogonTrigger"
            }
            
            foreach ($task in $scheduledTasks) {
                $startupPrograms += [PSCustomObject]@{
                    Name = $task.TaskName
                    Command = $task.Actions.Execute
                    Location = "Task Scheduler"
                    Type = "Scheduled Task"
                    Impact = Get-StartupImpact $task.TaskName $task.Actions.Execute
                }
            }
        } catch {
            Write-Log "Could not read scheduled tasks" -Level "WARN"
        }
        
        # Display results
        Write-Log "Found $($startupPrograms.Count) startup programs:" -Level "INFO"
        foreach ($program in $startupPrograms | Sort-Object Impact -Descending) {
            $impactColor = switch ($program.Impact) {
                "High" { "ERROR" }
                "Medium" { "WARN" }
                default { "INFO" }
            }
            Write-Log "  [$($program.Impact)] $($program.Name) ($($program.Type))" -Level $impactColor
        }
        
        return $startupPrograms
    }
    catch {
        Write-Log "Error analyzing startup programs: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-StartupImpact {
    param([string]$Name, [string]$Command)
    
    # High impact programs (known resource heavy)
    $highImpactKeywords = @("steam", "origin", "uplay", "epic", "discord", "skype", "zoom", "teams", "slack", "spotify", "itunes", "adobe", "office", "visual studio")
    
    # Low impact programs (system/security)
    $lowImpactKeywords = @("windows", "microsoft", "defender", "security", "system", "driver", "audio", "network")
    
    $nameLower = $Name.ToLower()
    $commandLower = $Command.ToLower()
    
    foreach ($keyword in $highImpactKeywords) {
        if ($nameLower.Contains($keyword) -or $commandLower.Contains($keyword)) {
            return "High"
        }
    }
    
    foreach ($keyword in $lowImpactKeywords) {
        if ($nameLower.Contains($keyword) -or $commandLower.Contains($keyword)) {
            return "Low"
        }
    }
    
    return "Medium"
}

function Optimize-StartupPrograms {
    param(
        [switch]$DisableHigh,
        [switch]$DisableMedium,
        [switch]$Interactive,
        [switch]$DryRun
    )
    
    Write-Log "Optimizing startup programs..." -Level "INFO"
    
    try {
        $startupPrograms = Get-StartupPrograms
        $disabledCount = 0
        
        foreach ($program in $startupPrograms) {
            $shouldDisable = $false
            
            if ($DisableHigh -and $program.Impact -eq "High") {
                $shouldDisable = $true
            }
            if ($DisableMedium -and $program.Impact -in @("High", "Medium")) {
                $shouldDisable = $true
            }
            
            if ($Interactive) {
                $response = Read-Host "Disable '$($program.Name)' [$($program.Impact) impact]? (y/N)"
                $shouldDisable = $response -eq "y" -or $response -eq "Y"
            }
            
            if ($shouldDisable) {
                if ($DryRun) {
                    Write-Log "[DRY RUN] Would disable: $($program.Name)" -Level "INFO"
                    $disabledCount++
                } else {
                    $result = Disable-StartupProgram -Program $program
                    if ($result) {
                        $disabledCount++
                    }
                }
            }
        }
        
        $action = if ($DryRun) { "would disable" } else { "disabled" }
        Write-Log "Startup optimization completed: $action $disabledCount programs" -Level "SUCCESS"
        
        return $disabledCount
    }
    catch {
        Write-Log "Error optimizing startup programs: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Disable-StartupProgram {
    param($Program)
    
    try {
        switch ($Program.Type) {
            "Registry" {
                Remove-ItemProperty -Path $Program.Location -Name $Program.Name -ErrorAction Stop
                Write-Log "Disabled registry startup: $($Program.Name)" -Level "SUCCESS"
                return $true
            }
            "Folder" {
                $backupPath = "$env:TEMP\StartupBackup"
                if (!(Test-Path $backupPath)) {
                    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
                }
                
                Move-Item -Path $Program.Command -Destination "$backupPath\$($Program.Name)" -ErrorAction Stop
                Write-Log "Disabled folder startup: $($Program.Name) (backed up to $backupPath)" -Level "SUCCESS"
                return $true
            }
            "Scheduled Task" {
                Disable-ScheduledTask -TaskName $Program.Name -ErrorAction Stop | Out-Null
                Write-Log "Disabled scheduled task: $($Program.Name)" -Level "SUCCESS"
                return $true
            }
        }
    }
    catch {
        Write-Log "Failed to disable startup program: $($Program.Name) - $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-BootTime {
    Write-Log "Analyzing boot performance..." -Level "INFO"
    
    try {
        # Get last boot time
        $bootTime = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime
        $uptime = (Get-Date) - $bootTime
        
        Write-Log "Last boot: $($bootTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Level "INFO"
        Write-Log "System uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes" -Level "INFO"
        
        # Get boot duration from event log
        try {
            $bootEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ID=100} -MaxEvents 5 -ErrorAction SilentlyContinue
            if ($bootEvents) {
                Write-Log "Recent boot times:" -Level "INFO"
                foreach ($event in $bootEvents) {
                    $bootDuration = [math]::Round($event.Properties[1].Value / 1000, 2)
                    Write-Log "  $($event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')): ${bootDuration}s" -Level "INFO"
                }
            }
        } catch {
            Write-Log "Could not retrieve boot duration from event log" -Level "WARN"
        }
        
        return @{
            LastBoot = $bootTime
            Uptime = $uptime
            BootEvents = $bootEvents
        }
    }
    catch {
        Write-Log "Error analyzing boot performance: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}
