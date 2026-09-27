Write-Host "=== Compacting WSL vhdx ===" -ForegroundColor Cyan
$vhdxPath = 'C:\Users\tbaltzakis\AppData\Local\wsl\{12c19879-cec8-4dd1-9fe4-7049940b6a2f}\ext4.vhdx'
Write-Host "Compacting: $vhdxPath"
optimize-vhd -Path $vhdxPath -Mode Full
Write-Host "Done!"
Read-Host "Press Enter to exit"