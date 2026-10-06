# Watches for console-process spawns (powershell/pwsh/cmd/wsl/conhost) for 5 min
# and logs name, pid, parent pid+name, commandline. Run hidden in background.
$log = 'D:\DevOptimizer\scripts\_popup-watch.log'
"=== watch start $(Get-Date -Format o) ===" | Out-File $log -Encoding utf8
$seen = @{}
$end = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $end) {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe' or Name='pwsh.exe' or Name='cmd.exe' or Name='wsl.exe' or Name='conhost.exe' or Name='WindowsTerminal.exe'" -ErrorAction SilentlyContinue |
        ForEach-Object {
            if (-not $seen[$_.ProcessId]) {
                $seen[$_.ProcessId] = $true
                $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($_.ParentProcessId)" -ErrorAction SilentlyContinue
                $pname = if ($parent) { $parent.Name } else { '?' }
                $pcmd = if ($parent) { ($parent.CommandLine -replace '"','''') } else { '' }
                $line = "{0} {1} pid={2} parent={3}({4}) cmd={5} pcmd={6}" -f (Get-Date -Format 'HH:mm:ss'), $_.Name, $_.ProcessId, $pname, $_.ParentProcessId, ($_.CommandLine -replace '"',''''), $pcmd
                $line | Out-File $log -Append -Encoding utf8
            }
        }
    Start-Sleep -Milliseconds 800
}
"=== watch end ===" | Out-File $log -Append -Encoding utf8
