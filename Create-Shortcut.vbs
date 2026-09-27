' Create DevOptimizer Desktop Shortcut using VBScript
' Uses CommonDesktopDirectory (Public Desktop) to avoid OneDrive issues

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Get Public Desktop path (works for all users)
publicDesktop = WshShell.ExpandEnvironmentStrings("%PUBLIC%") & "\Desktop"

If fso.FolderExists(publicDesktop) Then
    shortcutPath = publicDesktop & "\DevOptimizer.lnk"
    Set WshShortcut = WshShell.CreateShortcut(shortcutPath)
    
    WshShortcut.TargetPath = "cmd.exe"
    WshShortcut.Arguments = "/c D:\DevOptimizer\DevOptimizer.bat"
    WshShortcut.WorkingDirectory = "D:\DevOptimizer"
    WshShortcut.Description = "DevOptimizer Script Hub - Unified CLI"
    WshShortcut.IconLocation = "C:\Windows\System32\shell32.dll, 0"
    WshShortcut.Save
    
    WScript.Echo "Desktop shortcut created at: " & shortcutPath
Else
    WScript.Echo "Public Desktop not found at: " & publicDesktop
End If

' Create Start Menu shortcut (Common Programs)
commonPrograms = WshShell.ExpandEnvironmentStrings("%PROGRAMDATA%") & "\Microsoft\Windows\Start Menu\Programs"
If fso.FolderExists(commonPrograms) Then
    shortcutPath2 = commonPrograms & "\DevOptimizer.lnk"
    Set WshShortcut2 = WshShell.CreateShortcut(shortcutPath2)
    WshShortcut2.TargetPath = "cmd.exe"
    WshShortcut2.Arguments = "/c D:\DevOptimizer\DevOptimizer.bat"
    WshShortcut2.WorkingDirectory = "D:\DevOptimizer"
    WshShortcut2.Description = "DevOptimizer Script Hub - Unified CLI"
    WshShortcut2.IconLocation = "C:\Windows\System32\shell32.dll, 0"
    WshShortcut2.Save
    WScript.Echo "Start Menu shortcut created at: " & shortcutPath2
Else
    WScript.Echo "Common Programs not found at: " & commonPrograms
End If