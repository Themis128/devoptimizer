# Simple test to see if we're running elevated
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
$isAdmin = $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isAdmin | Out-File -FilePath "D:\DevOptimizer\scripts\elevation_test_result.txt" -Encoding ASCII