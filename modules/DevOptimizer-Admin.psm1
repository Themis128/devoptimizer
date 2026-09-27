# DevOptimizer Admin Privilege Module
# Handles admin privilege detection and elevation for the Script Hub

class DevOptimizerAdmin {
    [bool]$IsAdmin = $false
    [bool]$CanElevate = $false
    [string]$ElevationMethod = ""
    [string]$CurrentUser = ""
    [string]$CurrentProcess = ""
    
    DevOptimizerAdmin() {
        $this.CheckAdminStatus()
        $this.DetermineElevationCapability()
    }
    
    [void] CheckAdminStatus() {
        try {
            $this.CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $this.CurrentProcess = [System.Diagnostics.Process]::GetCurrentProcess().Id
            
            $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
            $this.IsAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
            
            Write-Host "[ADMIN] Current user: $($this.CurrentUser)" -ForegroundColor Cyan
            Write-Host "[ADMIN] Is Administrator: $($this.IsAdmin)" -ForegroundColor $(if ($this.IsAdmin) { "Green" } else { "Yellow" })
        }
        catch {
            Write-Error "[ADMIN] Failed to check admin status: $($_.Exception.Message)"
            $this.IsAdmin = $false
        }
    }
    
    [void] DetermineElevationCapability() {
        try {
            # Check if we can use UAC elevation
            $this.CanElevate = $true
            $this.ElevationMethod = "UAC"
            
            # Check for RunAs support
            if (Get-Command "Start-Process" -ErrorAction SilentlyContinue) {
                $this.CanElevate = $true
            }
        }
        catch {
            $this.CanElevate = $false
        }
    }
    
    [bool] RequireAdmin() {
        if (-not $this.IsAdmin) {
            Write-Warning "[ADMIN] This operation requires administrator privileges"
            return $false
        }
        return $true
    }
    
    [bool] ElevateIfNeeded() {
        if ($this.IsAdmin) {
            return $true
        }
        
        if (-not $this.CanElevate) {
            Write-Error "[ADMIN] Cannot elevate privileges - UAC not available"
            return $false
        }
        
        Write-Host "[ADMIN] Elevating privileges via $($this.ElevationMethod)..." -ForegroundColor Yellow
        
        try {
            # Re-launch current script with admin privileges
            $scriptPath = $MyInvocation.MyCommand.Path
            if ($scriptPath -and (Test-Path $scriptPath)) {
                Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs -ErrorAction Stop
                return $true
            } else {
                # Try to elevate current session
                Start-Process powershell.exe -Verb RunAs -ErrorAction Stop
                return $true
            }
        }
        catch {
            Write-Error "[ADMIN] Failed to elevate: $($_.Exception.Message)"
            return $false
        }
    }
    
    [bool] RunAsAdmin([string]$ScriptPath, [string]$Arguments = "") {
        if (-not (Test-Path $ScriptPath)) {
            Write-Error "[ADMIN] Script not found: $ScriptPath"
            return $false
        }
        
        try {
            $process = Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments" -Verb RunAs -PassThru -Wait -ErrorAction Stop
            return $process.ExitCode -eq 0
        }
        catch {
            Write-Error "[ADMIN] Failed to run as admin: $($_.Exception.Message)"
            return $false
        }
    }
    
    [hashtable] GetStatus() {
        return @{
            IsAdmin = $this.IsAdmin
            CanElevate = $this.CanElevate
            ElevationMethod = $this.ElevationMethod
            CurrentUser = $this.CurrentUser
            CurrentProcess = $this.CurrentProcess
        }
    }
}

$Global:DevOptimizerAdmin = [DevOptimizerAdmin]::new()

function Get-DevOptimizerAdmin {
    return $Global:DevOptimizerAdmin
}

function Test-AdminPrivilege {
    return $Global:DevOptimizerAdmin.IsAdmin
}

function Require-AdminPrivilege {
    return $Global:DevOptimizerAdmin.RequireAdmin()
}

function Elevate-IfNeeded {
    return $Global:DevOptimizerAdmin.ElevateIfNeeded()
}

function Invoke-AsAdmin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath,
        [string]$Arguments = ""
    )
    return $Global:DevOptimizerAdmin.RunAsAdmin($ScriptPath, $Arguments)
}

function Get-AdminStatus {
    return $Global:DevOptimizerAdmin.GetStatus()
}

Export-ModuleMember -Function Get-DevOptimizerAdmin, Test-AdminPrivilege, Require-AdminPrivilege, Elevate-IfNeeded, Invoke-AsAdmin, Get-AdminStatus

Write-Host "[ADMIN] DevOptimizer Admin Privilege Module initialized" -ForegroundColor Cyan