# chrome-ext-remove.ps1 — remove a Chrome extension via UI Automation.
# No user click needed: navigates the REAL Chrome profile to
# chrome://extensions/?id=<id>, invokes "Remove extension", confirms the
# dialog. Chrome must be running with a visible window. UIA is used
# because chrome:// pages are unreachable via CDP on the default profile.
# Usage: chrome-ext-remove.ps1 -ExtensionId fheoggkfdfchfphceeifdbepaooicaho
param(
  [Parameter(Mandatory=$true)][string]$ExtensionId,
  [string]$ChromeMatch = 'Chrome'
)
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class FG {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int s);
}
'@

function Find-Window([string]$match) {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
    if ($w.Current.Name -match $match) { return $w }
  }
  return $null
}

function Invoke-ByName($win, [string]$name) {
  $els = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,
    (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)))
  foreach ($el in $els) {
    $p = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    if ($p) { $p.Invoke(); return $true }
  }
  return $false
}

# 1. Focus a visible Chrome window and navigate via omnibox (chrome:// URLs
#    can't be passed on the command line / via start).
$proc = Get-Process chrome -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match $ChromeMatch } |
  Select-Object -First 1
if (-not $proc) { Write-Error "no visible Chrome window"; exit 1 }
[FG]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null
[FG]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 500
[System.Windows.Forms.SendKeys]::SendWait('^l')
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait("chrome://extensions/?id=$ExtensionId")
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Seconds 4

# 2. Invoke "Remove extension" on the details page.
$win = Find-Window $ChromeMatch
if (-not $win) { Write-Error "chrome window gone"; exit 1 }
if (-not (Invoke-ByName $win 'Remove extension')) { Write-Error "remove link not found"; exit 1 }
Start-Sleep -Seconds 2

# 3. Confirm the "Remove "<name>"?" dialog.
$win = Find-Window $ChromeMatch
$btns = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,
  (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)))
foreach ($b in $btns) {
  if ($b.Current.Name -eq 'Remove') {
    $p = $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    if ($p) { $p.Invoke(); Write-Output "removed $ExtensionId"; exit 0 }
  }
}
Write-Error "confirm button not found"; exit 1
