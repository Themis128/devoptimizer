<#
.SYNOPSIS
    Otter Notes toggle - small always-on-top widget with a Notes on/off button.

.DESCRIPTION
    Floating mini-window that toggles Otter.ai recording (the "Themis notes"
    notetaker) in the chrome-debug-profile browser via scripts\otter_notes.py.
    The button flips between Notes: OFF and Notes: ON; closing the window
    hides it to the system tray where it can be reopened or exited.

    Recording captures the microphone only (otter.ai web limitation).
    For system-audio capture of calls use the Otter desktop app instead.

.PARAMETER StartHidden
    Launch directly into the system tray without showing the window.

.EXAMPLE
    .\Otter-NotesToggle.ps1
#>

# CATEGORY: ai-ml
# TAGS: otter, notetaker, recording, widget, wpf
# REQUIRES: internet

[CmdletBinding()]
param(
    [switch]$StartHidden
)

# WPF requires STA; relaunch under powershell.exe -STA if needed (pwsh defaults to MTA)
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $args = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($StartHidden) { $args += '-StartHidden' }
    Start-Process powershell -ArgumentList $args -WindowStyle Hidden
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:ScriptDir = $PSScriptRoot
$script:Driver    = Join-Path $ScriptDir 'otter_notes.py'
$script:Busy      = $false
$script:Pending   = $null   # @{ Runspace; Handle; OnResult }

#region WPF window
$windowXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="230" Height="86" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowInTaskbar="False"
        ResizeMode="NoResize">
  <Border x:Name="Root" CornerRadius="10" Background="#FF1B1F24"
          BorderBrush="#FF3A4048" BorderThickness="1" Padding="10">
    <DockPanel>
      <Button x:Name="CloseButton" Content="x" DockPanel.Dock="Right"
              Width="22" Height="22" FontSize="11" Foreground="#FF9AA0A6"
              Background="Transparent" BorderThickness="0" Cursor="Hand"/>
      <Button x:Name="ToggleButton" Content="Notes: ..."
              FontSize="16" FontWeight="Bold" Foreground="White"
              Background="#FF39424E" BorderThickness="0" Cursor="Hand"
              VerticalContentAlignment="Center"/>
    </DockPanel>
  </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$windowXaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$toggleButton = $window.FindName('ToggleButton')
$closeButton  = $window.FindName('CloseButton')
$rootBorder   = $window.FindName('Root')
#endregion

$brushOn  = [Windows.Media.BrushConverter]::new().ConvertFromString('#FF1E7A34')
$brushOff = [Windows.Media.BrushConverter]::new().ConvertFromString('#FF8A3030')
$brushMid = [Windows.Media.BrushConverter]::new().ConvertFromString('#FF39424E')

function Set-State([string]$state) {
    switch ($state.ToUpper()) {
        'ON'  { $toggleButton.Content = 'Notes: ON';  $toggleButton.Background = $brushOn }
        'OFF' { $toggleButton.Content = 'Notes: OFF'; $toggleButton.Background = $brushOff }
        default {
            $toggleButton.Content = 'Notes: ...'
            $toggleButton.Background = $brushMid
        }
    }
}

function Apply-Result([string]$result) {
    if ($result -match '^(ON|OFF)$') {
        Set-State $result
        $toggleButton.ToolTip = $null
    } else {
        Set-State 'UNKNOWN'
        $toggleButton.ToolTip = "Error: $result"
    }
    $script:Busy = $false
    $toggleButton.IsEnabled = $true
}

function Start-OtterAction([string]$action, [scriptblock]$onResult) {
    $script:Busy = $true
    $toggleButton.IsEnabled = $false

    $ps = [powershell]::Create()
    [void]$ps.AddScript({
        param($driver, $act, $dir)
        Set-Location $dir
        $out = & python "`"$driver`"" $act 2>$null
        if ($out) { ($out | Select-Object -Last 1).ToString().Trim() } else { 'ERR:no output' }
    }).AddArgument($script:Driver).AddArgument($action).AddArgument($script:ScriptDir)

    $script:Pending = @{
        Runspace  = $ps
        Handle    = $ps.BeginInvoke()
        OnResult  = $onResult
    }
}

# Poll pending background action
$pollTimer = New-Object System.Windows.Threading.DispatcherTimer
$pollTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$pollTimer.Add_Tick({
    if ($script:Pending -and $script:Pending.Handle.IsCompleted) {
        $pending = $script:Pending
        $script:Pending = $null
        try {
            $result = $pending.Runspace.EndInvoke($pending.Handle) | Select-Object -Last 1
        } catch {
            $result = "ERR:$($_.Exception.Message)"
        }
        $pending.Runspace.Dispose()
        & $pending.OnResult ([string]$result)
    }
})
$pollTimer.Start()

function Invoke-OtterToggle {
    if ($script:Busy) { return }
    Set-State 'UNKNOWN'
    Start-OtterAction 'toggle' { param($r) Apply-Result $r }
}

function Invoke-OtterStatus {
    if ($script:Busy) { return }
    Start-OtterAction 'status' { param($r) Apply-Result $r }
}

# Tray icon
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Text = 'Otter Notes'
$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$trayMenu.Items.Add('Show', $null, { $window.Show(); $window.Activate() })
[void]$trayMenu.Items.Add('Exit', $null, {
    $notifyIcon.Visible = $false
    $window.Close()
    [System.Windows.Application]::Current.Shutdown()
})
$notifyIcon.ContextMenuStrip = $trayMenu
$notifyIcon.add_DoubleClick({ $window.Show(); $window.Activate() })
$notifyIcon.Visible = $true

# Wire events
$toggleButton.Add_Click({ Invoke-OtterToggle })
$closeButton.Add_Click({ $window.Hide() })
$rootBorder.Add_MouseLeftButtonDown({
    param($s, $e)
    if ($e.OriginalSource -isnot [System.Windows.Controls.Button]) { $window.DragMove() }
})

# Periodic state refresh (recording may be toggled from the browser too)
$statusTimer = New-Object System.Windows.Threading.DispatcherTimer
$statusTimer.Interval = [TimeSpan]::FromSeconds(30)
$statusTimer.Add_Tick({ Invoke-OtterStatus })
$statusTimer.Start()

# Position bottom-right of work area
$wa = [System.Windows.SystemParameters]::WorkArea
$window.Left = $wa.Right - $window.Width - 18
$window.Top  = $wa.Bottom - $window.Height - 18

if (-not $StartHidden) { $window.Show() }
Invoke-OtterStatus

[System.Windows.Application]::new().Run($window)
$statusTimer.Stop()
$pollTimer.Stop()
$notifyIcon.Visible = $false
$notifyIcon.Dispose()
