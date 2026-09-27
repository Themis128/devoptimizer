' DevOptimizer App - silent launcher (no console flash)
' Runs the WPF GUI via wscript so no PowerShell console window appears.
Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = "D:\DevOptimizer"
sh.Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File ""D:\DevOptimizer\DevOptimizer-App.ps1""", 0, False
