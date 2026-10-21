$os = Get-CimInstance Win32_OperatingSystem
"Free: {0:N2} GB" -f ($os.FreePhysicalMemory/1MB)
"Total: {0:N2} GB" -f ($os.TotalVisibleMemorySize/1MB)