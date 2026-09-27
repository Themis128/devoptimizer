#requires -Version 5.1
<#
.SYNOPSIS
    DevOptimizer App - native Windows WPF GUI for the DevOptimizer Script Hub.
.DESCRIPTION
    Desktop front-end for the hub registry (config\hub-registry.json):
      - Category browsing, live search, favorites (config\favorites.json)
      - Runs commands through Execute-Command.ps1 in a background process
      - Live output pane, parameter dialogs, elevated runs via UAC, dry-run
.NOTES
    Launch with DevOptimizer-App.vbs / DevOptimizer-App.bat, or:
      powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File DevOptimizer-App.ps1
    File must stay UTF-8 with BOM (PowerShell 5.1 needs the BOM for unicode glyphs).
#>

param(
    [string]$Command,
    [string]$Category,
    [switch]$Settings
)

$ErrorActionPreference = 'Stop'

# --- STA guard (WPF requires STA; powershell.exe v3+ defaults to STA, other hosts may not) ---
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $fwd = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass',
             '-File', ('"{0}"' -f $MyInvocation.MyCommand.Definition))
    if ($Command)  { $fwd += @('-Command',  ('"{0}"' -f $Command)) }
    if ($Category) { $fwd += @('-Category', ('"{0}"' -f $Category)) }
    if ($Settings) { $fwd += '-Settings' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $fwd
    return
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:RootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -LiteralPath $script:RootPath

# --- Application core: settings, filtering, autostart, toasts, chrome, single instance ---
Import-Module (Join-Path $script:RootPath 'app\DevOptimizer-AppCore.psm1') -Force
$script:SettingsPath = Join-Path $script:RootPath 'config\app-settings.json'
$script:AppSettings  = Get-AppSettings -SettingsPath $script:SettingsPath
$script:LauncherExe  = Join-Path $script:RootPath 'app\bin\DevOptimizer.exe'

# --- Single instance: focus the running window instead of starting a copy ---
if ($env:DOAPP_SELFTEST -ne '1') {
    $script:InstanceMutex = Test-SingleInstance
    if (-not $script:InstanceMutex.IsFirstInstance) {
        Add-Type -Namespace DevOptimizer.Native -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
'@ -ErrorAction SilentlyContinue
        $h = [DevOptimizer.Native.Win32]::FindWindow($null, 'DevOptimizer - Script Hub')
        if ($h -ne [IntPtr]::Zero) {
            [void][DevOptimizer.Native.Win32]::ShowWindow($h, 9)  # SW_RESTORE
            [void][DevOptimizer.Native.Win32]::SetForegroundWindow($h)
        }
        exit 0
    }
}

$script:RegistryPath = Join-Path $script:RootPath 'config\hub-registry.json'
$script:FavoritesPath = Join-Path $script:RootPath 'config\favorites.json'
# Prefer the application's multi-resolution icon; fall back to the legacy root icon
$script:IconPath = if (Test-Path (Join-Path $script:RootPath 'app\DevOptimizer.ico')) {
    Join-Path $script:RootPath 'app\DevOptimizer.ico'
} else {
    Join-Path $script:RootPath 'icon.ico'
}
$script:Runs = New-Object System.Collections.ArrayList

function Log-D([string]$m) {
    try {
        $d = Join-Path $script:RootPath 'logs\app-runs'
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        Add-Content -LiteralPath (Join-Path $d 'app-debug.log') -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m)
    } catch { }
}
Log-D 'checkpoint: script body entered'

# =====================================================================
# Helpers
# =====================================================================

function New-Brush([string]$Hex) {
    return (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Hex)))
}

function New-Text([string]$Text, [string]$Fg, [double]$Size, [bool]$Bold, [bool]$Wrap) {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.Foreground = New-Brush $Fg
    if ($Size -gt 0) { $t.FontSize = $Size }
    if ($Bold) { $t.FontWeight = 'Bold' }
    if ($Wrap) { $t.TextWrapping = 'Wrap' }
    return $t
}

function New-HubIcon([string]$Path) {
    # Generates icon.ico (blue->teal gradient tile with a "D") if it does not exist.
    if (Test-Path $Path) { return }
    try {
        $bmp = New-Object System.Drawing.Bitmap 32, 32
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $rect = New-Object System.Drawing.Rectangle 0, 0, 32, 32
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect `
            ([System.Drawing.Color]::FromArgb(255, 15, 108, 189)) `
            ([System.Drawing.Color]::FromArgb(255, 78, 201, 176)), 45.0
        $g.FillRectangle($brush, $rect)
        $font = New-Object System.Drawing.Font('Segoe UI', 17, [System.Drawing.FontStyle]::Bold)
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $g.DrawString('D', $font, [System.Drawing.Brushes]::White, ([System.Drawing.RectangleF]::new(0, 0, 32, 32)), $sf)
        $g.Dispose()
        $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
        $fs = [System.IO.File]::Create($Path)
        $icon.Save($fs)
        $fs.Dispose()
        $bmp.Dispose()
    } catch {
        Write-Verbose "Icon generation skipped: $($_.Exception.Message)"
    }
}

function Set-Status([string]$Message) {
    $StatusBarLeft.Text = $Message
}

# =====================================================================
# Data
# =====================================================================

function Load-Data {
    if (-not (Test-Path $script:RegistryPath)) {
        throw "Hub registry not found: $script:RegistryPath"
    }
    $script:Registry = Get-Content $script:RegistryPath -Raw | ConvertFrom-Json
    $script:Commands = @($script:Registry.commands | Sort-Object name)
    $script:Favorites = @()
    if (Test-Path $script:FavoritesPath) {
        try {
            $f = Get-Content $script:FavoritesPath -Raw | ConvertFrom-Json
            if ($f.favorites) { $script:Favorites = @($f.favorites) }
        } catch { }
    }
}

function Save-Favorites {
    @{ favorites = $script:Favorites } | ConvertTo-Json -Depth 2 |
        Set-Content -LiteralPath $script:FavoritesPath -Encoding UTF8
}

function Update-Categories {
    $groups = @($script:Commands | Group-Object category | Sort-Object Count -Descending)
    $script:CategoryKeys = @($null, '__fav__') + @($groups | ForEach-Object { $_.Name })
    $items = @(
        ("All commands   ({0})" -f $script:Commands.Count),
        ("[FAV] Favorites   ({0})" -f $script:Favorites.Count)
    )
    foreach ($grp in $groups) {
        $items += ("{0}   ({1})" -f $grp.Name, $grp.Count)
    }
    $CategoryList.ItemsSource = $items
    if ($CategoryList.SelectedIndex -lt 0) { $CategoryList.SelectedIndex = 0 }
}

function Update-CommandView {
    $catKey = $null
    if ($CategoryList.SelectedIndex -ge 0 -and $CategoryList.SelectedIndex -lt $script:CategoryKeys.Count) {
        $catKey = $script:CategoryKeys[$CategoryList.SelectedIndex]
    }
    $q = $SearchBox.Text.Trim()
    $result = foreach ($c in $script:Commands) {
        if ($catKey -eq '__fav__') {
            if ($script:Favorites -notcontains $c.name) { continue }
        } elseif ($catKey) {
            if ($c.category -ne $catKey) { continue }
        }
        if ($q) {
            # Search matches name/description/path/tags only — NOT category.
            # Category scoping is the category list's job; including it made a
            # search for a category name match every command in that category.
            $hay = "{0} {1} {2} {3}" -f $c.name, $c.description, $c.path, (@($c.tags) -join ' ')
            if ($hay -notmatch [regex]::Escape($q)) { continue }
        }
        [pscustomobject]@{
            Star        = $(if ($script:Favorites -contains $c.name) { [string][char]0x2605 } else { '' })
            Name        = $c.name
            Description = $c.description
            Category    = $c.category
            Admin       = $(if ($c.requiresAdmin) { [string][char]0x26A0 } else { '' })
            Cmd         = $c
        }
    }
    $view = @($result)
    $prevName = $CommandList.SelectedItem.Name
    $CommandList.ItemsSource = $view
    if ($prevName) {
        $again = $view | Where-Object { $_.Name -eq $prevName } | Select-Object -First 1
        if ($again) { $CommandList.SelectedItem = $again }
    }
    $CmdCount.Text = "{0} shown" -f $view.Count
}

function Update-Detail {
    $DetailPanel.Children.Clear() | Out-Null
    $sel = $CommandList.SelectedItem
    if (-not $sel) {
        [void]$DetailPanel.Children.Add((New-Text 'Select a command to see details.' '#8A8A98' 12 $false $true))
        return
    }
    $c = $sel.Cmd
    [void]$DetailPanel.Children.Add((New-Text $c.name '#4EC9B0' 17 $true $true))
    [void]$DetailPanel.Children.Add((New-Text ("category: {0}    entry: {1}" -f $c.category, $c.entryPoint) '#569CD6' 11.5 $false $false))
    [void]$DetailPanel.Children.Add((New-Text '' '#000000' 6 $false $false))
    if ($c.requiresAdmin) {
        [void]$DetailPanel.Children.Add((New-Text (([string][char]0x26A0) + ' Requires administrator privileges') '#D7BA7D' 12 $true $true))
    }
    [void]$DetailPanel.Children.Add((New-Text ($c.description) '#C8C8D4' 12.5 $false $true))
    [void]$DetailPanel.Children.Add((New-Text '' '#000000' 10 $false $false))
    [void]$DetailPanel.Children.Add((New-Text 'SCRIPT PATH' '#8A8A98' 10.5 $true $false))
    [void]$DetailPanel.Children.Add((New-Text $c.path '#9CDCFE' 12 $false $true))
    $defs = @($c.parameters)
    if ($defs.Count -gt 0) {
        [void]$DetailPanel.Children.Add((New-Text '' '#000000' 10 $false $false))
        [void]$DetailPanel.Children.Add((New-Text 'PARAMETERS' '#8A8A98' 10.5 $true $false))
        foreach ($p in $defs) {
            $req = ''
            if ($p.required) { $req = '  (required)' }
            [void]$DetailPanel.Children.Add((New-Text ("- {0}{1}" -f $p.name, $req) '#E8E8EE' 12 $true $false))
            if ($p.description) {
                [void]$DetailPanel.Children.Add((New-Text ("   {0}" -f $p.description) '#8A8A98' 11.5 $false $true))
            }
        }
    }
}

# =====================================================================
# Execution
# =====================================================================

function Show-ParameterDialog($cmd) {
    $defs = @($cmd.parameters)
    if ($defs.Count -eq 0) { return @{} }

    $script:DialogParams = $null
    $dlg = New-Object System.Windows.Window
    $dlg.Title = "Parameters - $($cmd.name)"
    $dlg.Width = 580
    $dlg.SizeToContent = 'Height'
    $dlg.MaxHeight = 720
    $dlg.WindowStartupLocation = 'CenterOwner'
    $dlg.Owner = $win
    $dlg.Background = $win.Background

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '20,16,20,16'
    [void]$sp.Children.Add((New-Text ("Parameters for '{0}'" -f $cmd.name) '#4EC9B0' 15 $true $false))
    [void]$sp.Children.Add((New-Text '' '#000000' 8 $false $false))

    $fields = @{}
    foreach ($p in $defs) {
        $reqMark = ''
        if ($p.required) { $reqMark = '  *' }
        $label = New-Text ("{0}{1}" -f $p.name, $reqMark) '#E8E8EE' 12.5 $true $false
        if ($p.required) { $label.Foreground = New-Brush '#CE9178' }
        [void]$sp.Children.Add($label)
        if ($p.description) {
            [void]$sp.Children.Add((New-Text $p.description '#8A8A98' 11 $false $true))
        }
        $tb = New-Object System.Windows.Controls.TextBox
        $tb.Background = New-Brush '#14141C'
        $tb.Foreground = New-Brush '#E8E8EE'
        $tb.BorderBrush = New-Brush '#3C3C4C'
        $tb.CaretBrush = New-Brush '#FFFFFF'
        $tb.Padding = '6,4'
        $tb.Margin = '0,4,0,10'
        $fields[$p.name] = $tb
        [void]$sp.Children.Add($tb)
    }

    [void]$sp.Children.Add((New-Text '' '#000000' 4 $false $false))
    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.HorizontalAlignment = 'Right'
    $okBtn = New-Object System.Windows.Controls.Button
    $okBtn.Content = 'Run'
    $okBtn.Padding = '18,6'
    $okBtn.Background = New-Brush '#0F6CBD'
    $okBtn.Foreground = New-Brush 'White'
    $cancelBtn = New-Object System.Windows.Controls.Button
    $cancelBtn.Content = 'Cancel'
    $cancelBtn.Padding = '14,6'
    $cancelBtn.Margin = '10,0,0,0'
    $cancelBtn.Background = New-Brush '#2E2E3C'
    $cancelBtn.Foreground = New-Brush '#D4D4DC'
    [void]$row.Children.Add($okBtn)
    [void]$row.Children.Add($cancelBtn)
    [void]$sp.Children.Add($row)

    $okBtn.Add_Click({
        $h = @{}
        foreach ($k in $fields.Keys) {
            $v = $fields[$k].Text.Trim()
            if ($v -ne '') { $h[$k] = $v }
        }
        $script:DialogParams = $h
        $dlg.Close()
    }.GetNewClosure())
    $cancelBtn.Add_Click({ $dlg.Close() }.GetNewClosure())

    $dlg.Content = $sp
    [void]$dlg.ShowDialog()
    return $script:DialogParams
}

function Start-HubRun($cmd, $params, [switch]$Elevated, [switch]$DryRun) {
    # Interactive batch menus (set /p, choice, pause) cannot run headless -
    # open them in a visible console window instead of silently doing nothing.
    $targetPath = Join-Path $script:RootPath ($cmd.path -replace '/', '\')
    if (-not $DryRun -and $cmd.entryPoint -eq 'cmd' -and (Test-Path $targetPath)) {
        $batText = Get-Content $targetPath -Raw -ErrorAction SilentlyContinue
        if ($batText -match '(?im)^\s*set\s+/p\b' -or $batText -match '(?im)^\s*choice\s' -or $batText -match '(?im)^\s*pause\b') {
            try {
                if ($Elevated) {
                    Start-Process -FilePath 'cmd.exe' -ArgumentList '/k', ('"{0}"' -f $targetPath) -Verb RunAs | Out-Null
                } else {
                    Start-Process -FilePath 'cmd.exe' -ArgumentList '/k', ('"{0}"' -f $targetPath) -WorkingDirectory (Split-Path -Parent $targetPath) | Out-Null
                }
            } catch {
                Set-Status ("Launch failed: {0}" -f $_.Exception.Message)
                $OutputBox.AppendText("[$(Get-Date -Format HH:mm:ss)] Launch failed for '$($cmd.name)': $($_.Exception.Message)`r`n")
                $OutputBox.ScrollToEnd()
                return
            }
            $OutputBox.AppendText("[$(Get-Date -Format HH:mm:ss)] '$($cmd.name)' is an interactive tool - opened it in a separate console window. Use that window; its output cannot be captured here.`r`n")
            $OutputBox.ScrollToEnd()
            Set-Status ("Opened '{0}' in a console window." -f $cmd.name)
            return
        }
    }

    $runDir = Join-Path $script:RootPath 'logs\app-runs'
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $id = "run-$($cmd.name)-$stamp"
    $outFile = Join-Path $runDir "$id.log.txt"
    $doneFile = Join-Path $runDir "$id.done.txt"
    $paramFile = Join-Path $runDir "$id.params.json"
    $runnerPath = Join-Path $runDir "$id.runner.ps1"

    ($params | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath $paramFile -Encoding UTF8

    $dryArg = ''
    if ($DryRun) { $dryArg = ' -DryRun' }

    $template = @'
$ErrorActionPreference = 'Continue'
Set-Location -LiteralPath '__ROOT__'
$outFile  = '__OUT__'
$doneFile = '__DONE__'
$params = @{}
$raw = $null
if (Test-Path -LiteralPath '__PARAMS__') { $raw = Get-Content -Raw -LiteralPath '__PARAMS__' }
if ($raw) { ($raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $params[$_.Name] = $_.Value } }
$sw = [System.Diagnostics.Stopwatch]::StartNew()
"DevOptimizer run: __NAME__   |   started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -LiteralPath $outFile -Encoding UTF8
$ok = $true
try {
    & (Join-Path '__ROOT__' 'Execute-Command.ps1') -Command '__NAME__' -Parameters $params__DRY__ *>&1 |
        ForEach-Object { $_.ToString() } | Out-File -LiteralPath $outFile -Append -Encoding UTF8
} catch {
    "ERROR: $($_.Exception.Message)" | Out-File -LiteralPath $outFile -Append -Encoding UTF8
    $_.ScriptStackTrace | Out-File -LiteralPath $outFile -Append -Encoding UTF8
    $ok = $false
}
$sw.Stop()
$lastCode = $LASTEXITCODE
"" | Out-File -LiteralPath $outFile -Append -Encoding UTF8
"---- finished in $([int]$sw.Elapsed.TotalSeconds) s (exit code: $lastCode) ----" | Out-File -LiteralPath $outFile -Append -Encoding UTF8
"exitOk=$ok code=$lastCode" | Out-File -LiteralPath $doneFile -Encoding ASCII
'@

    $runner = $template.Replace('__ROOT__', $script:RootPath).Replace('__OUT__', $outFile).
        Replace('__DONE__', $doneFile).Replace('__PARAMS__', $paramFile).
        Replace('__NAME__', $cmd.name).Replace('__DRY__', $dryArg)
    $runner | Set-Content -LiteralPath $runnerPath -Encoding UTF8

    $psArgs = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $runnerPath
    try {
        if ($Elevated) {
            Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -Verb RunAs | Out-Null
        } else {
            Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WindowStyle Hidden | Out-Null
        }
    } catch {
        Set-Status ("Launch failed: {0}" -f $_.Exception.Message)
        $OutputBox.AppendText("[$(Get-Date -Format HH:mm:ss)] Launch failed for '$($cmd.name)': $($_.Exception.Message)`r`n")
        $OutputBox.ScrollToEnd()
        return
    }

    [void]$script:Runs.Add([pscustomobject]@{
        Name      = $cmd.name
        OutFile   = $outFile
        DoneFile  = $doneFile
        Started   = Get-Date
        Elevated  = [bool]$Elevated
        Completed = $false
    })
    $OutputBox.AppendText("[$(Get-Date -Format HH:mm:ss)] Launched '$($cmd.name)'$(if ($Elevated) { ' (elevated)' })$(if ($DryRun) { ' (dry run)' }).`r`n")
    $OutputBox.ScrollToEnd()
    Set-Status ("Running '{0}'..." -f $cmd.name)
    $RunStatus.Text = "running: $($cmd.name)"
    $RunStatus.Foreground = New-Brush '#D7BA7D'
}

function Invoke-Selected {
    $sel = $CommandList.SelectedItem
    if (-not $sel) {
        Set-Status 'Select a command first.'
        return
    }
    $cmd = $sel.Cmd
    $params = @{}
    if (@($cmd.parameters).Count -gt 0) {
        $params = Show-ParameterDialog -cmd $cmd
        if ($null -eq $params) { return }
    }
    $elevated = [bool]$cmd.requiresAdmin -or [bool]$ChkElevated.IsChecked
    Start-HubRun -cmd $cmd -params $params -Elevated:$elevated -DryRun:([bool]$ChkDryRun.IsChecked)
}

# =====================================================================
# Settings view
# =====================================================================

function Show-SettingsView([bool]$Show) {
    if ($Show) {
        $MainGrid.Visibility = 'Collapsed'
        $SettingsPanel.Visibility = 'Visible'
    } else {
        $SettingsPanel.Visibility = 'Collapsed'
        $MainGrid.Visibility = 'Visible'
    }
}

function Initialize-SettingsView {
    $s = $script:AppSettings
    foreach ($item in $CmbTheme.Items) { if ($item.Content -eq $s.theme) { $CmbTheme.SelectedItem = $item } }
    foreach ($item in $CmbLogLevel.Items) { if ($item.Content -eq $s.logLevel) { $CmbLogLevel.SelectedItem = $item } }
    $ChkToasts.IsChecked = [bool]$s.toasts
    $ChkAutoStart.IsChecked = [bool](Test-AutoStart)
    $ChkDryRunDefault.IsChecked = [bool]$s.defaultDryRun
    $SettingsAboutText.Text = ("{0} commands in {1} categories | registry v{2}" -f
        $script:Commands.Count, @($script:Registry.categories).Count, $script:Registry.version)
}

function Save-SettingsFromView {
    $s = $script:AppSettings
    if ($CmbTheme.SelectedItem) { $s.theme = [string]$CmbTheme.SelectedItem.Content }
    if ($CmbLogLevel.SelectedItem) { $s.logLevel = [string]$CmbLogLevel.SelectedItem.Content }
    $s.toasts = [bool]$ChkToasts.IsChecked
    $s.defaultDryRun = [bool]$ChkDryRunDefault.IsChecked
    try {
        $script:AppSettings = Save-AppSettings -Settings $s -SettingsPath $script:SettingsPath
        Set-AutoStart -Enabled:([bool]$ChkAutoStart.IsChecked) -TargetExe $script:LauncherExe | Out-Null
        Set-Status 'Settings saved.'
    } catch {
        Set-Status ("Saving settings failed: {0}" -f $_.Exception.Message)
    }
}

# =====================================================================
# UI (XAML)
# =====================================================================

$xamlXml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="DevOptimizer - Script Hub"
        Height="840" Width="1340" MinHeight="620" MinWidth="1040"
        WindowStartupLocation="CenterScreen"
        Background="#1B1B24" FontFamily="Segoe UI" FontSize="12.5"
        UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
    <Style TargetType="GridViewColumnHeader">
      <Setter Property="Background" Value="#26262F"/>
      <Setter Property="Foreground" Value="#9A9AA8"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="GridViewColumnHeader">
            <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ListViewItem">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="#D4D4DC"/>
      <Setter Property="Padding" Value="6,5"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListViewItem">
            <Border x:Name="rowBd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
              <GridViewRowPresenter Content="{TemplateBinding Content}" HorizontalAlignment="Stretch"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="rowBd" Property="Background" Value="#2A2A38"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="rowBd" Property="Background" Value="#0F4C81"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ListBoxItem">
      <Setter Property="Foreground" Value="#C8C8D4"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Margin" Value="0,1"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Border x:Name="catBd" Background="Transparent" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="catBd" Property="Background" Value="#2A2A38"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="catBd" Property="Background" Value="#0F4C81"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="DarkBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#D4D4DC"/>
      <Setter Property="Background" Value="#2E2E3C"/>
      <Setter Property="BorderBrush" Value="#3C3C4C"/>
      <Setter Property="Padding" Value="11,6"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="6,0,0,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#3A3A4C"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#262634"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="AccentBtn" TargetType="Button" BasedOn="{StaticResource DarkBtn}">
      <Setter Property="Background" Value="#0F6CBD"/>
      <Setter Property="BorderBrush" Value="#2E8BD6"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#C8C8D4"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="6,0,0,0"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="54"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="5"/>
      <RowDefinition Height="230" MinHeight="80"/>
      <RowDefinition Height="26"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Border Grid.Row="0" Background="#22222E" Padding="14,0">
      <DockPanel>
        <StackPanel DockPanel.Dock="Left" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Text="DevOptimizer" FontSize="17" FontWeight="Bold" Foreground="#4EC9B0"/>
          <TextBlock Text="  Script Hub" FontSize="13" Foreground="#8A8A98" VerticalAlignment="Center" Margin="2,2,0,0"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
          <CheckBox x:Name="ChkElevated" Content="Elevated"/>
          <CheckBox x:Name="ChkDryRun" Content="Dry run"/>
          <Button x:Name="BtnRun" Content="Run  ▶" Style="{StaticResource AccentBtn}"/>
          <Button x:Name="BtnFav" Content="★ Favorite" Style="{StaticResource DarkBtn}"/>
          <Button x:Name="BtnLocation" Content="Folder" Style="{StaticResource DarkBtn}"/>
          <Button x:Name="BtnRefresh" Content="⟳ Refresh" Style="{StaticResource DarkBtn}"/>
        </StackPanel>
        <Grid VerticalAlignment="Center">
          <Border Background="#14141C" BorderBrush="#3C3C4C" BorderThickness="1" CornerRadius="5">
            <TextBox x:Name="SearchBox" Background="Transparent" Foreground="#E8E8EE" BorderThickness="0"
                     CaretBrush="#FFFFFF" Padding="10,6" Margin="1" VerticalContentAlignment="Center"
                     MaxWidth="520" HorizontalAlignment="Left" Width="440"/>
          </Border>
          <TextBlock x:Name="SearchHint" Text="🔍  Search commands..." Foreground="#6A6A78" Margin="12,0,0,0"
                     VerticalAlignment="Center" IsHitTestVisible="False"/>
        </Grid>
      </DockPanel>
    </Border>

    <!-- Main -->
    <Grid Grid.Row="1" x:Name="MainGrid">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="215"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="6"/>
        <ColumnDefinition Width="330"/>
      </Grid.ColumnDefinitions>

      <Border Grid.Column="0" Background="#22222E" Margin="10,0,0,10" CornerRadius="6" Padding="5">
        <DockPanel>
          <Button DockPanel.Dock="Bottom" x:Name="BtnSettings" Content="⚙  Settings" Style="{StaticResource DarkBtn}"
                  Margin="4,4,4,2" HorizontalAlignment="Stretch"/>
          <TextBlock DockPanel.Dock="Top" Text="CATEGORIES" Foreground="#8A8A98" FontSize="10.5"
                     FontWeight="Bold" Margin="10,8,0,6"/>
          <ListBox x:Name="CategoryList" Background="Transparent" BorderThickness="0"
                   ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
        </DockPanel>
      </Border>

      <Border Grid.Column="1" Background="#22222E" Margin="10,0,0,10" CornerRadius="6" Padding="5">
        <DockPanel>
          <DockPanel DockPanel.Dock="Top" Margin="8,8,8,6">
            <TextBlock DockPanel.Dock="Right" x:Name="CmdCount" Text="" Foreground="#8A8A98" FontSize="10.5"/>
            <TextBlock Text="COMMANDS" Foreground="#8A8A98" FontSize="10.5" FontWeight="Bold"/>
          </DockPanel>
          <ListView x:Name="CommandList" Background="Transparent" BorderThickness="0"
                    ScrollViewer.HorizontalScrollBarVisibility="Disabled">
            <ListView.View>
              <GridView>
                <GridViewColumn Header="" Width="30">
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding Star}" Foreground="#D7BA7D" FontWeight="Bold"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="Name" Width="220">
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding Name}" Foreground="#E8E8EE" FontWeight="SemiBold"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="Description" x:Name="ColDescription" Width="420">
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding Description}" Foreground="#9A9AA8" TextTrimming="CharacterEllipsis"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="Category" Width="125">
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding Category}" Foreground="#569CD6"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="Admin" Width="46">
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding Admin}" Foreground="#D7BA7D" FontWeight="Bold"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
              </GridView>
            </ListView.View>
          </ListView>
        </DockPanel>
      </Border>

      <GridSplitter Grid.Column="2" Width="6" HorizontalAlignment="Stretch" Background="Transparent"/>

      <Border Grid.Column="3" Background="#22222E" Margin="0,0,10,10" CornerRadius="6" Padding="14,12">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="DetailPanel"/>
        </ScrollViewer>
      </Border>
    </Grid>

    <!-- Settings overlay (same row as MainGrid; visibility-toggled) -->
    <Border Grid.Row="1" x:Name="SettingsPanel" Background="#1B1B24" Visibility="Collapsed" Margin="10,0,10,10"
            CornerRadius="6" Padding="24,18">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="360"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0">
          <TextBlock Text="SETTINGS" Foreground="#4EC9B0" FontSize="16" FontWeight="Bold" Margin="0,0,0,14"/>
          <TextBlock Text="Theme" Foreground="#8A8A98" FontSize="11" FontWeight="Bold" Margin="0,8,0,2"/>
          <ComboBox x:Name="CmbTheme" Width="180" HorizontalAlignment="Left">
            <ComboBoxItem Content="dark"/><ComboBoxItem Content="light"/>
          </ComboBox>
          <TextBlock Text="Log level" Foreground="#8A8A98" FontSize="11" FontWeight="Bold" Margin="0,14,0,2"/>
          <ComboBox x:Name="CmbLogLevel" Width="180" HorizontalAlignment="Left">
            <ComboBoxItem Content="debug"/><ComboBoxItem Content="info"/>
            <ComboBoxItem Content="warn"/><ComboBoxItem Content="error"/>
          </ComboBox>
          <CheckBox x:Name="ChkToasts" Content="Toast notifications when long commands finish" Margin="0,16,0,0"/>
          <CheckBox x:Name="ChkAutoStart" Content="Start DevOptimizer when Windows starts" Margin="0,10,0,0"/>
          <CheckBox x:Name="ChkDryRunDefault" Content="Default new runs to dry-run mode" Margin="0,10,0,0"/>
          <StackPanel Orientation="Horizontal" Margin="0,20,0,0">
            <Button x:Name="BtnSaveSettings" Content="Save settings" Style="{StaticResource AccentBtn}" Margin="0"/>
            <Button x:Name="BtnCloseSettings" Content="Back to commands" Style="{StaticResource DarkBtn}" Margin="8,0,0,0"/>
          </StackPanel>
        </StackPanel>
        <StackPanel Grid.Column="1" Margin="30,0,0,0" VerticalAlignment="Top">
          <TextBlock Text="About" Foreground="#4EC9B0" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
          <TextBlock Text="DevOptimizer - Windows 11 application" Foreground="#C8C8D4" FontSize="12.5" TextWrapping="Wrap"/>
          <TextBlock x:Name="SettingsAboutText" Text="" Foreground="#8A8A98" FontSize="11.5" Margin="0,6,0,0" TextWrapping="Wrap"/>
          <TextBlock Text="Settings are stored in config\app-settings.json. The autostart toggle writes a per-user Run entry (HKCU); no elevation is used."
                     Foreground="#6A6A78" FontSize="11" Margin="0,14,0,0" TextWrapping="Wrap"/>
        </StackPanel>
      </Grid>
    </Border>

    <GridSplitter Grid.Row="2" HorizontalAlignment="Stretch" Background="Transparent" ResizeDirection="Rows"/>

    <!-- Output -->
    <Grid Grid.Row="3" Margin="10,0,10,0">
      <Grid.RowDefinitions>
        <RowDefinition Height="30"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <DockPanel Grid.Row="0">
        <TextBlock DockPanel.Dock="Right" x:Name="RunStatus" Text="" Foreground="#D7BA7D" VerticalAlignment="Center" Margin="0,0,12,0"/>
        <Button DockPanel.Dock="Right" x:Name="BtnClearOut" Content="Clear" Style="{StaticResource DarkBtn}"
                Padding="10,3" FontSize="11"/>
        <TextBlock Text="OUTPUT" Foreground="#8A8A98" FontSize="10.5" FontWeight="Bold" VerticalAlignment="Center"/>
      </DockPanel>
      <TextBox x:Name="OutputBox" Grid.Row="1" IsReadOnly="True" FontFamily="Consolas" FontSize="12"
               Background="#14141C" Foreground="#B8D8B8" BorderBrush="#2A2A38" BorderThickness="1"
               VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"
               Padding="8,6"/>
    </Grid>

    <!-- Status bar -->
    <Border Grid.Row="4" Background="#22222E" Padding="12,3">
      <DockPanel>
        <TextBlock DockPanel.Dock="Right" x:Name="StatusBarRight" Text="" Foreground="#8A8A98" FontSize="11"/>
        <TextBlock x:Name="StatusBarLeft" Text="Loading registry..." Foreground="#9A9AA8" FontSize="11"/>
      </DockPanel>
    </Border>
  </Grid>
</Window>
'@

# =====================================================================
# Window wiring
# =====================================================================

try {
    $win = [System.Windows.Markup.XamlReader]::Parse($xamlXml)
} catch {
    Log-D ("xaml parse FAILED: " + $_.Exception.Message)
    [System.Windows.Forms.MessageBox]::Show("Failed to load UI: $($_.Exception.Message)", 'DevOptimizer') | Out-Null
    throw
}
Log-D 'checkpoint: xaml parsed'

# XamlReader.Parse does not auto-create variables for x:Name - map them explicitly
foreach ($n in @('SearchBox', 'SearchHint', 'CategoryList', 'CommandList', 'DetailPanel', 'CmdCount',
                 'OutputBox', 'RunStatus', 'StatusBarLeft', 'StatusBarRight', 'ChkElevated', 'ChkDryRun',
                 'BtnRun', 'BtnFav', 'BtnLocation', 'BtnRefresh', 'BtnClearOut', 'ColDescription',
                 'MainGrid', 'SettingsPanel', 'BtnSettings', 'CmbTheme', 'CmbLogLevel',
                 'ChkToasts', 'ChkAutoStart', 'ChkDryRunDefault', 'BtnSaveSettings', 'BtnCloseSettings',
                 'SettingsAboutText')) {
    Set-Variable -Name $n -Value $win.FindName($n) -Scope Script
}
$missing = @('SearchBox', 'SearchHint', 'CategoryList', 'CommandList', 'DetailPanel', 'CmdCount',
             'OutputBox', 'RunStatus', 'StatusBarLeft', 'StatusBarRight', 'ChkElevated', 'ChkDryRun',
             'BtnRun', 'BtnFav', 'BtnLocation', 'BtnRefresh', 'BtnClearOut', 'MainGrid', 'SettingsPanel',
             'BtnSettings', 'CmbTheme', 'CmbLogLevel', 'ChkToasts', 'ChkAutoStart', 'ChkDryRunDefault',
             'BtnSaveSettings', 'BtnCloseSettings') |
    Where-Object { -not (Get-Variable -Name $_ -Scope Script -ValueOnly -ErrorAction SilentlyContinue) }
if ($missing) { throw "XAML elements not found: $($missing -join ', ')" }
Log-D 'checkpoint: controls bound'

$win.Add_SourceInitialized({
    if (Test-Path $script:IconPath) {
        try {
            $win.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]$script:IconPath)
        } catch { }
    }
    # Win 11 chrome: dark titlebar, rounded corners, Mica backdrop (silent fallback per feature)
    try {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper -ArgumentList $win
        Set-WindowChrome -WindowHandle $helper.Handle | Out-Null
    } catch { }
})

# Log (and survive) any unhandled dispatcher exception instead of dying silently
$app = New-Object System.Windows.Application
$app.Add_DispatcherUnhandledException({
    param($s, $e)
    Log-D ("dispatcher exception: " + $e.Exception.Message + " :: at " + $e.Exception.TargetSite)
    try { Set-Status ("Error: " + $e.Exception.Message) } catch { }
    $e.Handled = $true
})

$SearchBox.Add_TextChanged({
    $SearchHint.Visibility = if ($SearchBox.Text -eq '') { 'Visible' } else { 'Hidden' }
    Update-CommandView
})

$CategoryList.Add_SelectionChanged({ Update-CommandView })

$CommandList.Add_SelectionChanged({ Update-Detail })

$CommandList.Add_MouseDoubleClick({ Invoke-Selected })

$BtnRun.Add_Click({ Invoke-Selected })

$BtnFav.Add_Click({
    $sel = $CommandList.SelectedItem
    if (-not $sel) { Set-Status 'Select a command first.'; return }
    $name = $sel.Cmd.name
    if ($script:Favorites -contains $name) {
        $script:Favorites = @($script:Favorites | Where-Object { $_ -ne $name })
        Set-Status "Removed '$name' from favorites."
    } else {
        $script:Favorites = @($script:Favorites) + $name
        Set-Status "Added '$name' to favorites."
    }
    try { Save-Favorites } catch { Set-Status "Failed to save favorites: $($_.Exception.Message)" }
    Update-Categories
    Update-CommandView
})

$BtnLocation.Add_Click({
    $sel = $CommandList.SelectedItem
    if (-not $sel) { return }
    $p = Join-Path $script:RootPath ($sel.Cmd.path -replace '/', '\')
    if (Test-Path $p) {
        Start-Process explorer.exe -ArgumentList "/select,`"$p`""
    } else {
        Set-Status "Script not found: $p"
    }
})

$BtnRefresh.Add_Click({
    try {
        Load-Data
        Update-Categories
        Update-CommandView
        Set-Status "Registry reloaded ($($script:Commands.Count) commands)."
    } catch {
        Set-Status "Reload failed: $($_.Exception.Message)"
    }
})

$BtnClearOut.Add_Click({ $OutputBox.Clear() })

$BtnSettings.Add_Click({
    Initialize-SettingsView
    Show-SettingsView $true
})

$BtnSaveSettings.Add_Click({ Save-SettingsFromView })

$BtnCloseSettings.Add_Click({ Show-SettingsView $false })

$win.Add_Closed({
    try { $script:Timer.Stop() } catch { }
    try { $script:InstanceMutex.Mutex.Dispose() } catch { }
})

# Keep the Description column fitted to the available width
$win.Add_SizeChanged({
    try {
        $ColDescription.Width = [Math]::Max(220, $CommandList.ActualWidth - 30 - 220 - 125 - 46 - 60)
    } catch { }
})

# =====================================================================
# Start
# =====================================================================

New-HubIcon -Path $script:IconPath

try {
    Load-Data
} catch {
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'DevOptimizer - Registry Error') | Out-Null
    return
}

Update-Categories
Update-Detail
Log-D 'checkpoint: ui populated'

$ver = $script:Registry.version
if (-not $ver) { $ver = '?' }
$StatusBarRight.Text = "{0} commands | {1} categories | registry v{2}" -f $script:Commands.Count, @($script:Registry.categories).Count, $ver
Set-Status 'Ready.'

$ChkDryRun.IsChecked = [bool]$script:AppSettings.defaultDryRun

# --- Deep links (jump list / launcher args) ---
# Input validation at the protocol entry point: values are bounded strings and
# must resolve against the registry. This is the enforcing boundary regardless
# of how the arguments arrived (launcher exe, jump list, direct script call).
$deeplinkUnsafe = '[\r\n\x00]'
if ($Command -match $deeplinkUnsafe)  { Log-D 'deeplink: rejected unsafe command value';  $Command  = $null }
if ($Category -match $deeplinkUnsafe) { Log-D 'deeplink: rejected unsafe category value'; $Category = $null }

if ($Settings) {
    Log-D "deeplink: settings view requested"
    Initialize-SettingsView
    Show-SettingsView $true
} elseif ($Category) {
    $idx = $script:CategoryKeys.IndexOf($Category)
    if ($idx -ge 0) {
        Log-D ("deeplink: category '{0}'" -f $Category)
        $CategoryList.SelectedIndex = $idx
    } else {
        Log-D ("deeplink: category '{0}' not found in registry - ignored" -f $Category)
        Set-Status ("Deep link ignored: unknown category '{0}'." -f $Category)
    }
} elseif ($Command) {
    $CategoryList.SelectedIndex = 0
    $SearchBox.Text = ''
    $match = @($script:Commands | Where-Object { $_.name -eq $Command }) | Select-Object -First 1
    if ($match) {
        Log-D ("deeplink: command '{0}'" -f $Command)
        $row = @($CommandList.ItemsSource) | Where-Object { $_.Name -eq $match.name } | Select-Object -First 1
        if ($row) { $CommandList.SelectedItem = $row }
    } else {
        Log-D ("deeplink: command '{0}' not found in registry - ignored" -f $Command)
        Set-Status ("Deep link ignored: unknown command '{0}'." -f $Command)
    }
}

# --- Taskbar jump list (only meaningful when launched via the exe) ---
try {
    if (Test-Path $script:LauncherExe) {
        $jl = New-Object System.Windows.Shell.JumpList
        foreach ($def in @(
            @{ Title = 'Health snapshot'; Desc = 'Capture a Windows 11 health snapshot'; Args = '-Command win11-health-snapshot' },
            @{ Title = 'Cleanup commands';  Desc = 'Open the cleanup category';            Args = '-Category cleanup' },
            @{ Title = 'Settings';          Desc = 'Open DevOptimizer settings';           Args = '-Settings' }
        )) {
            $jt = New-Object System.Windows.Shell.JumpTask
            $jt.Title = $def.Title
            $jt.Description = $def.Desc
            $jt.ApplicationPath = $script:LauncherExe
            $jt.Arguments = $def.Args
            $jt.IconResourcePath = $script:LauncherExe
            $jt.CustomCategory = 'Tasks'
            $jl.JumpItems.Add($jt)
        }
        [System.Windows.Shell.JumpList]::SetJumpList($app, $jl)
    }
} catch {
    Log-D ("jump list skipped: " + $_.Exception.Message)
}

$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds(800)
$script:Timer.Add_Tick({
    if ($script:Runs.Count -eq 0) { return }
    $run = $script:Runs[$script:Runs.Count - 1]

    $tail = ''
    if (Test-Path $run.OutFile) {
        $lines = Get-Content -LiteralPath $run.OutFile -Tail 400 -ErrorAction SilentlyContinue
        if ($lines) { $tail = ($lines -join "`r`n") }
    }
    if ($tail -and $tail -ne $OutputBox.Tag) {
        $OutputBox.Tag = $tail
        $OutputBox.Text = $tail
        $OutputBox.ScrollToEnd()
    }

    if (-not $run.Completed -and (Test-Path $run.DoneFile)) {
        $run.Completed = $true
        $dur = [int]((Get-Date) - $run.Started).TotalSeconds
        $RunStatus.Text = "done: $($run.Name) (${dur}s)"
        $RunStatus.Foreground = New-Brush '#6A9955'
        Set-Status "Completed '$($run.Name)'."
        # Toast on longer runs (duration threshold configurable in settings)
        try {
            if ($script:AppSettings.toasts -and $dur -ge [int]$script:AppSettings.toastMinSeconds) {
                $doneText = (Get-Content -LiteralPath $run.DoneFile -ErrorAction SilentlyContinue) -join ' '
                $success = ($doneText -match 'exitOk=True')
                Send-RunCompleteToast -CommandName $run.Name -Success:$success -DurationSeconds $dur | Out-Null
            }
        } catch { }
    }
})
$script:Timer.Start()

# Headless self-test: DOAPP_SELFTEST=1 exercises the data pipeline without showing the window
if ($env:DOAPP_SELFTEST -eq '1') {
    $fail = $false
    try {
        $failCount = 0
        # Category filter: view count must equal the registry count for that category
        $CategoryList.SelectedIndex = 3
        $catKey = $script:CategoryKeys[3]
        $expected = @($script:Commands | Where-Object { $_.category -eq $catKey }).Count
        Log-D ("selftest: category[3] '$catKey' filter -> " + $CmdCount.Text + " (expected $expected)")
        if ($CmdCount.Text -ne ("{0} shown" -f $expected)) { $fail = $true; $failCount++ }

        # Search: view count must equal the AppCore filter applied to the full registry
        $CategoryList.SelectedIndex = 0
        $SearchBox.Text = 'diagnostic'
        $expectedQ = @($script:Commands | Where-Object { Test-CommandFilter -Command $_ -Query 'diagnostic' }).Count
        Log-D ("selftest: all + search 'diagnostic' -> " + $CmdCount.Text + " (expected $expectedQ)")
        if ($CmdCount.Text -ne ("{0} shown" -f $expectedQ)) { $fail = $true; $failCount++ }
        if ($expectedQ -eq 0) { $fail = $true; $failCount++ }   # positive control

        # Regression: a category NAME must not match its whole category via search
        $SearchBox.Text = [string]$catKey
        $expectedCat = @($script:Commands | Where-Object { Test-CommandFilter -Command $_ -Query $catKey }).Count
        Log-D ("selftest: all + search category name '$catKey' -> " + $CmdCount.Text + " (category has $expected; semantic matches $expectedCat)")
        if ($CmdCount.Text -ne ("{0} shown" -f $expectedCat)) { $fail = $true; $failCount++ }
        if ($expectedCat -ge $expected) { $fail = $true; $failCount++ }
        $SearchBox.Text = ''

        $CommandList.SelectedIndex = 0
        Log-D ("selftest: detail panel children -> " + $DetailPanel.Children.Count)
        if ($DetailPanel.Children.Count -lt 3) { $fail = $true; $failCount++ }

        $CommandList.SelectedIndex = 1
        Log-D ("selftest: detail panel children (row 2) -> " + $DetailPanel.Children.Count)
        if ($failCount -gt 0) { Log-D ("selftest: failed checks = $failCount") }
    } catch {
        Log-D ("SELFTEST EXCEPTION: " + $_.Exception.Message + " :: " + $_.InvocationInfo.PositionMessage)
        $fail = $true
    }
    if ($fail) { Log-D 'SELFTEST FAIL' } else { Log-D 'SELFTEST PASS' }
    return
}

[void]$win.ShowDialog()
Log-D 'checkpoint: ShowDialog returned'
