# DevOptimizer Path Resolution Module
# Handles cross-platform path resolution for the Script Hub

param(
    [string]$ConfigPath = "D:\DevOptimizer\config\devoptimizer-config.json"
)

class DevOptimizerPath {
    [hashtable]$Config = @{}
    [string]$RootDirectory = ""
    [string]$ScriptsDirectory = ""
    [string]$ModulesDirectory = ""
    [string]$ToolsDirectory = ""
    [string]$PortableDirectory = ""
    [string]$ConfigDirectory = ""
    [string]$LogsDirectory = ""
    [string]$CacheDirectory = ""
    
    DevOptimizerPath([string]$Path) {
        $this.LoadPaths()
    }
    
    [void] LoadPaths() {
        try {
            # Try to get merged config first
            if ($Global:DevOptimizerModules -and $Global:DevOptimizerModules.Config) {
                $this.Config = $Global:DevOptimizerModules.Config
            }
            
            # Determine root directory
            $this.RootDirectory = $this.GetValue("paths.root_directory", "D:\DevOptimizer")
            $this.ScriptsDirectory = Join-Path $this.RootDirectory "scripts"
            $this.ModulesDirectory = Join-Path $this.RootDirectory "modules"
            $this.ToolsDirectory = Join-Path $this.RootDirectory "tools"
            $this.PortableDirectory = Join-Path $this.RootDirectory "portable"
            $this.ConfigDirectory = Join-Path $this.RootDirectory "config"
            $this.LogsDirectory = Join-Path $this.RootDirectory "logs"
            $this.CacheDirectory = Join-Path $this.RootDirectory "cache"
            
            Write-Host "[PATH] Path resolution initialized" -ForegroundColor Cyan
        }
        catch {
            Write-Error "[PATH] Failed to initialize paths: $($_.Exception.Message)"
        }
    }
    
    [object] GetValue([string]$Path, [object]$Default = $null) {
        if (-not $this.Config) { return $Default }
        $keys = $Path.Split('.')
        $current = $this.Config
        
        foreach ($key in $keys) {
            if ($current -is [hashtable] -and $current.ContainsKey($key)) {
                $current = $current[$key]
            } else {
                return $Default
            }
        }
        return $current
    }
    
    [string] ResolveScript([string]$ScriptName) {
        $paths = @(
            Join-Path $this.ScriptsDirectory "$ScriptName.ps1",
            Join-Path $this.ScriptsDirectory "$ScriptName.bat",
            Join-Path $this.ScriptsDirectory "$ScriptName.py",
            Join-Path $this.PortableDirectory "$ScriptName.bat"
        )
        
        foreach ($path in $paths) {
            if (Test-Path $path) {
                return $path
            }
        }
        return $null
    }
    
    [string] ResolveTool([string]$ToolName) {
        $path = Join-Path $this.ToolsDirectory $ToolName
        if (Test-Path $path) {
            return $path
        }
        return $null
    }
    
    [string[]] GetScriptDirectories() {
        return @($this.ScriptsDirectory, $this.PortableDirectory)
    }
    
    [string[]] GetAllDirectories() {
        return @(
            $this.RootDirectory,
            $this.ScriptsDirectory,
            $this.ModulesDirectory,
            $this.ToolsDirectory,
            $this.PortableDirectory,
            $this.ConfigDirectory,
            $this.LogsDirectory,
            $this.CacheDirectory
        )
    }
    
    [bool] EnsureDirectory([string]$Path) {
        try {
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -ItemType Directory -Force | Out-Null
            }
            return $true
        }
        catch {
            $err = $_.Exception.Message
            Write-Error "[PATH] Failed to create directory ${Path}: $err"
            return $false
        }
    }
    
    [string] GetLogPath([string]$LogName) {
        $this.EnsureDirectory($this.LogsDirectory)
        return Join-Path $this.LogsDirectory "$LogName.log"
    }
    
    [string] GetCachePath([string]$CacheName) {
        $this.EnsureDirectory($this.CacheDirectory)
        return Join-Path $this.CacheDirectory "$CacheName.json"
    }
}

$Global:DevOptimizerPath = [DevOptimizerPath]::new($ConfigPath)

function Get-DevOptimizerPath {
    return $Global:DevOptimizerPath
}

function Resolve-ScriptPath {
    param([string]$ScriptName)
    return $Global:DevOptimizerPath.ResolveScript($ScriptName)
}

function Resolve-ToolPath {
    param([string]$ToolName)
    return $Global:DevOptimizerPath.ResolveTool($ToolName)
}

function Get-ScriptDirectories {
    return $Global:DevOptimizerPath.GetScriptDirectories()
}

function Get-AllDevOptimizerDirectories {
    return $Global:DevOptimizerPath.GetAllDirectories()
}

function Ensure-DevOptimizerDirectory {
    param([string]$Path)
    return $Global:DevOptimizerPath.EnsureDirectory($Path)
}

function Get-DevOptimizerLogPath {
    param([string]$LogName)
    return $Global:DevOptimizerPath.GetLogPath($LogName)
}

function Get-DevOptimizerCachePath {
    param([string]$CacheName)
    return $Global:DevOptimizerPath.GetCachePath($CacheName)
}

Export-ModuleMember -Function Get-DevOptimizerPath, Resolve-ScriptPath, Resolve-ToolPath, Get-ScriptDirectories, Get-AllDevOptimizerDirectories, Ensure-DevOptimizerDirectory, Get-DevOptimizerLogPath, Get-DevOptimizerCachePath

Write-Host "[PATH] DevOptimizer Path Resolution Module initialized" -ForegroundColor Cyan