Write-Host "=== Compacting WSL vhdx ===" -ForegroundColor Cyan
optimize-vhd -Path '\\wsl.localhost\Ubuntu-26.04\ext4.vhdx' -Mode Full
Write-Host "Done!"
Read-Host "Press Enter to exit"