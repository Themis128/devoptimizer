$log = 'D:\DevOptimizer\scripts\_rewrap-headless-all.log'
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') rewrap-all run ===" | Out-File $log -Append -Encoding utf8
$conhost = 'C:\Windows\System32\conhost.exe'
$portablePwsh = 'D:\DevOptimizer\pwsh\pwsh.exe'
# Executables that allocate a visible console when run from Task Scheduler.
$badExe = @('powershell.exe','pwsh.exe','pwsh','powershell','cmd.exe','cmd','wsl.exe','cscript.exe','wscript.exe','cscript','wscript','python.exe','python')
$targets = Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft*' }
foreach ($t in $targets) {
    try {
        $changed = $false
        $newActions = New-Object System.Collections.Generic.List[object]
        foreach ($action in @($t.Actions)) {
            try {
                $exeRaw = ([string]$action.Execute -replace '^"|"$','').Trim()
                if ([string]::IsNullOrEmpty($exeRaw)) { $newActions.Add($action) | Out-Null; continue }
                $exeName = [IO.Path]::GetFileName($exeRaw)
                if ([string]::IsNullOrEmpty($exeName)) { $newActions.Add($action) | Out-Null; continue }
                $exeLow = $exeName.ToLower()
                $isBat = $exeRaw -match '\.(bat|cmd)$'
                $alreadyHeadless = ($exeRaw -match 'conhost') -or ($exeLow -eq 'pythonw.exe') -or ([string]$action.Arguments -match 'conhost')
                if ($alreadyHeadless -or (-not ($badExe -contains $exeLow) -and -not $isBat)) {
                    $newActions.Add($action) | Out-Null; continue
                }
                # python.exe -> pythonw.exe: no console at all (2026-11-13:
                # Idika*/DLinkCloudArchive/EvidenceVideoIndexDaily flashed a
                # cmd window on every run; pythonw is the cleaner fix than
                # conhost --headless wrapping).
                if ($exeLow -eq 'python.exe' -or $exeLow -eq 'python') {
                    $wexe = Join-Path (Split-Path $exeRaw) 'pythonw.exe'
                    if (-not (Test-Path $wexe)) { $wexe = 'pythonw.exe' }
                    $newActions.Add((New-ScheduledTaskAction -Execute $wexe -Argument ([string]$action.Arguments))) | Out-Null
                    $changed = $true
                    continue
                }
                # pwsh.exe resolves to the broken Store stub - use the portable install.
                $runExe = $exeRaw
                if ($exeLow -eq 'pwsh.exe' -or $exeLow -eq 'pwsh') { $runExe = $portablePwsh }
                $newArgs = ('--headless "{0}" {1}' -f $runExe, [string]$action.Arguments).Trim()
                $newActions.Add((New-ScheduledTaskAction -Execute $conhost -Argument $newArgs)) | Out-Null
                $changed = $true
            } catch {
                "ERR-ACT $($t.TaskPath)$($t.TaskName) : $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
                $newActions.Add($action) | Out-Null
            }
        }
        if ($changed) {
            Set-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Action $newActions.ToArray() -ErrorAction Stop | Out-Null
            "FIX  $($t.TaskPath)$($t.TaskName)" | Out-File $log -Append -Encoding utf8
        }
    } catch {
        "ERR  $($t.TaskPath)$($t.TaskName) : $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
    }
}
"DONE" | Out-File $log -Append -Encoding utf8
