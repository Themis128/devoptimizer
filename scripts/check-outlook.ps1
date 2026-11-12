$ErrorActionPreference = 'SilentlyContinue'
"=== Outlook-ish processes ==="
Get-Process | Where-Object { $_.Name -match 'outlook|olk' } |
  Select-Object Name, Id, StartTime, Responding, MainWindowTitle, Path | Format-Table -AutoSize | Out-String -Width 250

"=== Recent AppModel events (last 20) ==="
Get-WinEvent -LogName 'Microsoft-Windows-AppModel-Runtime/Admin' -MaxEvents 20 |
  Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-List | Out-String -Width 200

"=== Reliability / crash dumps for olk ==="
Get-ChildItem "$env:LOCALAPPDATA\CrashDumps" -ErrorAction SilentlyContinue |
  Where-Object Name -match 'outlook|olk' | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
