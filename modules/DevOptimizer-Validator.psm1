# DevOptimizer Input Validation and Security Module
# Comprehensive input validation, sanitization, and security checks

param(
    [string]$ConfigPath = "D:\DevOptimizer\config\devoptimizer-config.json"
)

class DevOptimizerValidator {
    [hashtable]$Config
    [string[]]$AllowedExtensions
    [string[]]$BlockedCommands
    [bool]$InputValidationEnabled
    [bool]$PathSanitizationEnabled
    
    DevOptimizerValidator([string]$ConfigPath) {
        $this.LoadConfiguration($ConfigPath)
    }
    
    [void] LoadConfiguration([string]$ConfigPath) {
        try {
            if (Test-Path $ConfigPath) {
                $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                $this.InputValidationEnabled = $configContent.security.input_validation
                $this.PathSanitizationEnabled = $configContent.security.path_sanitization
                $this.AllowedExtensions = $configContent.security.allowed_extensions
                $this.BlockedCommands = $configContent.security.blocked_commands
            } else {
                # Default security settings
                $this.InputValidationEnabled = $true
                $this.PathSanitizationEnabled = $true
                $this.AllowedExtensions = @(".bat", ".ps1", ".cmd", ".exe")
                $this.BlockedCommands = @("format", "del /f", "rmdir /s", "shutdown", "restart")
            }
        }
        catch {
            Write-Warning "[VALIDATOR] Failed to load security configuration, using defaults"
            $this.InputValidationEnabled = $true
            $this.PathSanitizationEnabled = $true
            $this.AllowedExtensions = @(".bat", ".ps1", ".cmd", ".exe")
            $this.BlockedCommands = @("format", "del /f", "rmdir /s", "shutdown", "restart")
        }
    }
    
    [bool] ValidateInput([string]$Input, [string]$Type = "general") {
        if (-not $this.InputValidationEnabled) {
            return $true
        }
        
        switch ($Type.ToLower()) {
            "filepath" { return $this.ValidateFilePath($Input) }
            "filename" { return $this.ValidateFileName($Input) }
            "command" { return $this.ValidateCommand($Input) }
            "number" { return $this.ValidateNumber($Input) }
            "email" { return $this.ValidateEmail($Input) }
            "url" { return $this.ValidateUrl($Input) }
            default { return $this.ValidateGeneral($Input) }
        }
    }
    
    [bool] ValidateFilePath([string]$Path) {
        try {
            # Check for null or empty
            if ([string]::IsNullOrWhiteSpace($Path)) {
                return $false
            }
            
            # Check for path traversal attempts
            if ($Path.Contains("..") -or $Path.Contains("~")) {
                return $false
            }
            
            # Check for invalid characters
            $invalidChars = @('<', '>', '|', '?', '*', '"')
            foreach ($char in $invalidChars) {
                if ($Path.Contains($char)) {
                    return $false
                }
            }
            
            # Validate path format
            $fullPath = [System.IO.Path]::GetFullPath($Path)
            if ($fullPath -ne $Path) {
                return $false
            }
            
            return $true
        }
        catch {
            return $false
        }
    }
    
    [bool] ValidateFileName([string]$FileName) {
        try {
            # Check for null or empty
            if ([string]::IsNullOrWhiteSpace($FileName)) {
                return $false
            }
            
            # Check length
            if ($FileName.Length -gt 255) {
                return $false
            }
            
            # Check for invalid characters
            $invalidChars = @('<', '>', '|', '?', '*', '"', ':', '\', '/')
            foreach ($char in $invalidChars) {
                if ($FileName.Contains($char)) {
                    return $false
                }
            }
            
            # Check for reserved names
            $reservedNames = @("CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9")
            $nameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($FileName).ToUpper()
            if ($reservedNames -contains $nameWithoutExtension) {
                return $false
            }
            
            return $true
        }
        catch {
            return $false
        }
    }
    
    [bool] ValidateCommand([string]$Command) {
        try {
            # Check for null or empty
            if ([string]::IsNullOrWhiteSpace($Command)) {
                return $false
            }
            
            # Check for blocked commands
            foreach ($blockedCmd in $this.BlockedCommands) {
                if ($Command.ToLower().Contains($blockedCmd.ToLower())) {
                    return $false
                }
            }
            
            # Check for command injection patterns
            $injectionPatterns = @(';', '&', '|', '`', '$', '(', ')', '{', '}')
            foreach ($pattern in $injectionPatterns) {
                if ($Command.Contains($pattern)) {
                    return $false
                }
            }
            
            return $true
        }
        catch {
            return $false
        }
    }
    
    [bool] ValidateNumber([string]$Number) {
        try {
            if ([string]::IsNullOrWhiteSpace($Number)) {
                return $false
            }
            
            $parsed = [double]::Parse($Number)
            return $true
        }
        catch {
            return $false
        }
    }
    
    [bool] ValidateEmail([string]$Email) {
        try {
            if ([string]::IsNullOrWhiteSpace($Email)) {
                return $false
            }
            
            $emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
            return $Email -match $emailRegex
        }
        catch {
            return $false
        }
    }
    
    [bool] ValidateUrl([string]$Url) {
        try {
            if ([string]::IsNullOrWhiteSpace($Url)) {
                return $false
            }
            
            $uri = [System.Uri]::new($Url)
            return $uri.IsAbsoluteUri
        }
        catch {
            return $false
        }
    }
    
    [bool] ValidateGeneral([string]$Input) {
        try {
            # Check for null or empty
            if ([string]::IsNullOrWhiteSpace($Input)) {
                return $false
            }
            
            # Check length (reasonable limit)
            if ($Input.Length -gt 1000) {
                return $false
            }
            
            # Check for script injection patterns
            $scriptPatterns = @('<script', 'javascript:', 'vbscript:', 'onload=', 'onerror=')
            foreach ($pattern in $scriptPatterns) {
                if ($Input.ToLower().Contains($pattern)) {
                    return $false
                }
            }
            
            return $true
        }
        catch {
            return $false
        }
    }
    
    [string] SanitizeInput([string]$Input, [string]$Type = "general") {
        if (-not $this.PathSanitizationEnabled) {
            return $Input
        }
        
        switch ($Type.ToLower()) {
            "filepath" { return $this.SanitizeFilePath($Input) }
            "filename" { return $this.SanitizeFileName($Input) }
            "command" { return $this.SanitizeCommand($Input) }
            default { return $this.SanitizeGeneral($Input) }
        }
    }
    
    [string] SanitizeFilePath([string]$Path) {
        try {
            # Remove path traversal attempts
            $sanitized = $Path.Replace("..", "").Replace("~", "")
            
            # Remove invalid characters
            $invalidChars = @('<', '>', '|', '?', '*', '"')
            foreach ($char in $invalidChars) {
                $sanitized = $sanitized.Replace($char, "")
            }
            
            # Normalize path separators
            $sanitized = $sanitized.Replace('/', '\')
            
            return $sanitized
        }
        catch {
            return ""
        }
    }
    
    [string] SanitizeFileName([string]$FileName) {
        try {
            # Remove invalid characters
            $invalidChars = @('<', '>', '|', '?', '*', '"', ':', '\', '/')
            foreach ($char in $invalidChars) {
                $FileName = $FileName.Replace($char, "")
            }
            
            # Limit length
            if ($FileName.Length -gt 255) {
                $FileName = $FileName.Substring(0, 255)
            }
            
            return $FileName
        }
        catch {
            return ""
        }
    }
    
    [string] SanitizeCommand([string]$Command) {
        try {
            # Remove command injection patterns
            $injectionPatterns = @(';', '&', '|', '`', '$', '(', ')', '{', '}')
            foreach ($pattern in $injectionPatterns) {
                $Command = $Command.Replace($pattern, "")
            }
            
            # Remove script patterns
            $scriptPatterns = @('<script', 'javascript:', 'vbscript:', 'onload=', 'onerror=')
            foreach ($pattern in $scriptPatterns) {
                $Command = $Command.Replace($pattern, "", [System.StringComparison]::IgnoreCase)
            }
            
            return $Command
        }
        catch {
            return ""
        }
    }
    
    [string] SanitizeGeneral([string]$Input) {
        try {
            # Remove script injection patterns
            $scriptPatterns = @('<script', 'javascript:', 'vbscript:', 'onload=', 'onerror=')
            foreach ($pattern in $scriptPatterns) {
                $Input = $Input.Replace($pattern, "", [System.StringComparison]::IgnoreCase)
            }
            
            # Limit length
            if ($Input.Length -gt 1000) {
                $Input = $Input.Substring(0, 1000)
            }
            
            return $Input
        }
        catch {
            return ""
        }
    }
    
    [bool] IsFileExtensionAllowed([string]$FilePath) {
        try {
            $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
            return $this.AllowedExtensions -contains $extension
        }
        catch {
            return $false
        }
    }
    
    [hashtable] ValidateAndSanitize([string]$Input, [string]$Type = "general") {
        $result = @{
            IsValid = $false
            SanitizedInput = ""
            ErrorMessage = ""
        }
        
        try {
            # Validate input
            $isValid = $this.ValidateInput($Input, $Type)
            
            if ($isValid) {
                # Sanitize input
                $sanitized = $this.SanitizeInput($Input, $Type)
                $result.IsValid = $true
                $result.SanitizedInput = $sanitized
            } else {
                $result.ErrorMessage = "Input validation failed for type: $Type"
            }
        }
        catch {
            $result.ErrorMessage = "Validation error: $($_.Exception.Message)"
        }
        
        return $result
    }
}

# Global validator instance
$Global:DevOptimizerValidator = [DevOptimizerValidator]::new($ConfigPath)

# Helper functions
function Test-DevOptimizerInput {
    param(
        [string]$Input,
        [string]$Type = "general"
    )
    return $Global:DevOptimizerValidator.ValidateInput($Input, $Type)
}

function Get-SanitizedInput {
    param(
        [string]$Input,
        [string]$Type = "general"
    )
    return $Global:DevOptimizerValidator.SanitizeInput($Input, $Type)
}

function Test-AndSanitizeInput {
    param(
        [string]$Input,
        [string]$Type = "general"
    )
    return $Global:DevOptimizerValidator.ValidateAndSanitize($Input, $Type)
}

function Test-FileExtension {
    param([string]$FilePath)
    return $Global:DevOptimizerValidator.IsFileExtensionAllowed($FilePath)
}

# Initialize validator
Write-Host "[VALIDATOR] DevOptimizer Input Validation System initialized" -ForegroundColor Cyan
