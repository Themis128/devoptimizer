# wsl-service-doctor-task.ps1 - weekly env-drift/config sweep of the WSL docker
# stack. Runs service-doctor.sh (wsl-service-healer skill) in-distro for the
# stateful services, logs to logs\service-doctor.log. Warns (event 1004) when
# placeholder env, anonymous-volume shadows, or DB cred mismatches are found -
# the mautic-class failure from 2026-11-02. Pure ASCII (PS 5.1).
$ErrorActionPreference = 'Continue'
$env:WSL_UTF8 = '1'   # wsl.exe writes UTF-16 to pipes by default; UTF-8 keeps log lines + WARN/FAIL/DRIFT matching correct
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$stamp   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$logFile = 'D:\DevOptimizer\logs\service-doctor.log'
$script  = '/mnt/c/Users/tbaltzakis/AppData/Roaming/devin/skills/wsl-service-healer/scripts/service-doctor.sh'
$services = @('mautic','metabase','n8n','social-api','authentik','nextcloud','postiz','espocrm')

$vm = Get-Process vmmemWSL -ErrorAction SilentlyContinue
if (-not $vm) { Add-Content $logFile "$stamp WSL not running (skipped)"; exit 0 }

& wsl.exe -d Ubuntu-24.04 -e bash -c 'command -v docker >/dev/null 2>&1'
if ($LASTEXITCODE -ne 0) {
    Add-Content $logFile "$stamp docker CLI absent in distro (Docker Desktop down?) - sweep skipped"
    exit 0
}

$findings = 0
foreach ($s in $services) {
    $out = @(& wsl.exe -d Ubuntu-24.04 -e bash $script $s 2>&1)
    $out | ForEach-Object { Add-Content $logFile "$stamp [$s] $_" }
    $hits = ($out | Select-String -Pattern 'WARN:|FAIL:|DRIFT:').Count
    if ($hits -gt 0) {
        $findings += $hits
        Add-Content $logFile "$stamp [$s] FINDINGS: $hits issue(s) - see lines above"
    }
}
if ($findings -gt 0) {
    Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1004 -EntryType Warning `
        -Message "service-doctor sweep found $findings issue(s) in WSL stack - see $logFile" `
        -ErrorAction SilentlyContinue
}
Add-Content $logFile "$stamp sweep done: $($services.Count) services, $findings finding(s)"
