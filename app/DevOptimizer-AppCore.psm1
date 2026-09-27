#Requires -Version 5.1
<#
.SYNOPSIS
    DevOptimizer Windows 11 application core - pure, unit-testable logic.

.DESCRIPTION
    Imported by DevOptimizer-App.ps1 and by the Pester test suite (tests\app\).
    Every function is side-effect free unless a path/registry override is injected,
    so tests never touch the real config or registry.

    Functions:
      Get-AppSettings        - load settings JSON (schema-validated, defaults for missing fields)
      Save-AppSettings       - persist settings JSON
      Test-CommandFilter     - command haystack matching (name/description/path/tags; category excluded)
      Set-AutoStart          - create/remove the HKCU Run value
      Test-AutoStart         - query the Run value
      Send-RunCompleteToast  - Windows toast (PowerShell AUMID) with silent fallback
      Set-WindowChrome       - dark titlebar + rounded corners + Mica backdrop (DWM, silent fallback)
      Test-SingleInstance    - named-mutex single instance probe
#>

Set-StrictMode -Version 2.0

# =====================================================================
# Settings
# =====================================================================

$script:SettingsSchema = @{
    theme         = @{ Type = [string];  Default = 'dark';  Valid = @('dark', 'light') }
    toasts        = @{ Type = [bool];    Default = $true }
    autostart     = @{ Type = [bool];    Default = $false }
    defaultDryRun = @{ Type = [bool];    Default = $false }
    logLevel      = @{ Type = [string];  Default = 'info';  Valid = @('debug', 'info', 'warn', 'error') }
    toastMinSeconds = @{ Type = [int];   Default = 10 }
}

function Get-DefaultAppSettings {
    $out = @{}
    # NOTE: indexer access (not .Key) everywhere - under Set-StrictMode 2.0 a
    # missing-key property access throws, while indexing simply returns $null.
    foreach ($k in $script:SettingsSchema.Keys) { $out[$k] = $script:SettingsSchema[$k]['Default'] }
    return $out
}

function Get-AppSettings {
    param([string]$SettingsPath)

    $settings = Get-DefaultAppSettings
    if (-not $SettingsPath -or -not (Test-Path -LiteralPath $SettingsPath)) { return $settings }
    try {
        $raw = Get-Content -LiteralPath $SettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($k in $script:SettingsSchema.Keys) {
            if ($raw.PSObject.Properties.Name -contains $k) {
                $v = $raw.$k
                $schema = $script:SettingsSchema[$k]
                if ($schema['Valid'] -and ($schema['Valid'] -notcontains $v)) { continue }
                $settings[$k] = $v -as $schema['Type']
            }
        }
    } catch {
        # corrupted settings file falls back to defaults
    }
    return $settings
}

function Save-AppSettings {
    param(
        [Parameter(Mandatory)][hashtable]$Settings,
        [Parameter(Mandatory)][string]$SettingsPath
    )

    $clean = Get-DefaultAppSettings
    foreach ($k in @($clean.Keys)) {
        if ($Settings.ContainsKey($k)) { $clean[$k] = $Settings[$k] }
    }
    $dir = Split-Path -Parent $SettingsPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $clean | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
    return $clean
}

# =====================================================================
# Command filtering (search)
# =====================================================================

function Test-CommandFilter {
    param(
        [Parameter(Mandatory)]$Command,
        [AllowEmptyString()][string]$Query
    )

    if ([string]::IsNullOrWhiteSpace($Query)) { return $true }
    # Search matches name/description/path/tags ONLY - not the category.
    # Category scoping is the category list's job; including it made a search
    # for a category name match every command in that category (2026-09-26 bug).
    $hay = "{0} {1} {2} {3}" -f $Command.name, $Command.description, $Command.path, (@($Command.tags) -join ' ')
    return ($hay -like ("*{0}*" -f $Query.Trim()))
}

# =====================================================================
# Autostart (HKCU Run key; injectable path for tests)
# =====================================================================

$script:AutoStartValueName = 'DevOptimizer'

function Get-RunKeyPath {
    param([string]$RunKeyPath)
    if ($RunKeyPath) { return $RunKeyPath }
    return 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
}

function Test-AutoStart {
    param([string]$RunKeyPath)
    $key = Get-RunKeyPath -RunKeyPath $RunKeyPath
    if (-not (Test-Path $key)) { return $false }
    $v = Get-ItemProperty -Path $key -Name $script:AutoStartValueName -ErrorAction SilentlyContinue
    return ($null -ne $v -and $v.$script:AutoStartValueName)
}

function Set-AutoStart {
    param(
        [Parameter(Mandatory)][bool]$Enabled,
        [string]$RunKeyPath,
        [string]$TargetExe
    )

    $key = Get-RunKeyPath -RunKeyPath $RunKeyPath
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    if ($Enabled) {
        if (-not $TargetExe) { throw "Set-AutoStart -Enabled requires -TargetExe" }
        New-ItemProperty -Path $key -Name $script:AutoStartValueName -Value ('"{0}"' -f $TargetExe) -PropertyType String -Force | Out-Null
    } else {
        Remove-ItemProperty -Path $key -Name $script:AutoStartValueName -ErrorAction SilentlyContinue
    }
    return (Test-AutoStart -RunKeyPath $RunKeyPath)
}

# =====================================================================
# Toast notifications (WinRT; silent fallback - never throws)
# =====================================================================

function Send-RunCompleteToast {
    param(
        [Parameter(Mandatory)][string]$CommandName,
        [Parameter(Mandatory)][bool]$Success,
        [string]$DurationSeconds,
        [string]$AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    )

    try {
        if (-not ('Windows.UI.Notifications.ToastNotificationManager' -as [type])) {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue
        }
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

        $title = if ($Success) { "DevOptimizer: '$CommandName' finished" } else { "DevOptimizer: '$CommandName' failed" }
        $line = if ($Success) { "Completed in $DurationSeconds s - click to open output." } else { "Check the output pane for the error." }
        $template = @"
<toast activationType="foreground">
  <visual>
    <binding template="ToastGeneric">
      <text>$title</text>
      <text>$line</text>
    </binding>
  </visual>
</toast>
"@
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = New-Object Windows.UI.Notifications.ToastNotification($xml)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
        $notifier.Show($toast)
        return $true
    } catch {
        # Toasts unavailable (unregistered AUMID, no broker, etc.) - silent fallback.
        return $false
    }
}

# =====================================================================
# Window chrome (DWM): dark titlebar, rounded corners, Mica backdrop
# =====================================================================

Add-Type -Namespace DevOptimizer.Native -Name Dwm -MemberDefinition @'
[DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
'@ -ErrorAction SilentlyContinue

function Set-WindowChrome {
    param(
        [Parameter(Mandatory)][IntPtr]$WindowHandle,
        [bool]$DarkTitleBar = $true,
        [bool]$RoundedCorners = $true,
        [bool]$MicaBackdrop = $true
    )

    $applied = @{ DarkTitleBar = $false; RoundedCorners = $false; Mica = $false }
    if ($WindowHandle -eq [IntPtr]::Zero) { return $applied }
    try {
        $v = 0
        $hr = [DevOptimizer.Native.Dwm]::DwmSetWindowAttribute($WindowHandle, 20, [ref]$v, 4)  # DWMWA_USE_IMMERSIVE_DARK_MODE
        if ($hr -eq 0) { $applied.DarkTitleBar = $true }
        if ($RoundedCorners) {
            $v = 2  # DWMWCP_ROUND
            $hr = [DevOptimizer.Native.Dwm]::DwmSetWindowAttribute($WindowHandle, 33, [ref]$v, 4)  # DWMWA_WINDOW_CORNER_PREFERENCE
            if ($hr -eq 0) { $applied.RoundedCorners = $true }
        }
        if ($MicaBackdrop) {
            $v = 2  # DWMSBT_MAINWINDOW (Mica)
            $hr = [DevOptimizer.Native.Dwm]::DwmSetWindowAttribute($WindowHandle, 38, [ref]$v, 4)  # DWMWA_SYSTEMBACKDROP_TYPE
            if ($hr -eq 0) { $applied.Mica = $true }
        }
    } catch {
        # pre-Win11 dwmapi or restricted host - defaults stay
    }
    return $applied
}

# =====================================================================
# Single instance
# =====================================================================

function Test-SingleInstance {
    param([string]$MutexName = 'Global\DevOptimizer.SingleInstance')

    $mutex = New-Object System.Threading.Mutex($false, $MutexName)
    $owned = $false
    try { $owned = $mutex.WaitOne(0, $false) } catch { $owned = $false }
    if ($owned) {
        # Module-level reference keeps the mutex alive for the instance lifetime,
        # independent of what the caller does with the returned object.
        $script:ActiveInstanceMutex = $mutex
    }
    return [pscustomobject]@{
        IsFirstInstance = $owned
        Mutex           = $mutex   # caller should dispose on exit
    }
}

Export-ModuleMember -Function @(
    'Get-DefaultAppSettings', 'Get-AppSettings', 'Save-AppSettings',
    'Test-CommandFilter',
    'Test-AutoStart', 'Set-AutoStart',
    'Send-RunCompleteToast', 'Set-WindowChrome', 'Test-SingleInstance'
)
