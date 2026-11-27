# sshd-repair.ps1 - diagnose + repair Windows OpenSSH Server (sshd).
# CATEGORY: maintenance
#
# Root cause researched 2026-11-13: Windows OpenSSH >=9.4 dies silently on
# start when C:\ProgramData\ssh\logs ACLs are too broad (upstream issues
# PowerShell/openssh-portable#2281/#2282; post-Oct-2024-update regression).
# Symptom: SCM event 7031 "terminated unexpectedly" loop, sshd logs no error.
# Second failure mode here (2026-11-13): sshd dies during each Docker/WSL
# bounce - SCM recovery actions were empty so it just stayed stopped.
#
# What it does, in order:
#   1. sshd -t config syntax test (an empty DenyUsers/AllowUsers silently
#      kills startup - check first, it's free). Non-elevated "no hostkeys"
#      is a FALSE positive (keys are SYSTEM/Admins-only by design) and only
#      downgrades to indeterminate.
#   2. ProgramData\ssh + logs dir ACL repair via the vendor script
#      FixHostFilePermissions.ps1 (shipped with the OpenSSH capability);
#      manual icacls fallback on the logs dir when the vendor script is absent.
#   3. SCM recovery hardening: restart on 1st/2nd/subsequent failure, 60s,
#      reset counter after 1 day (was empty = die-and-stay-dead).
#   3b. DefaultShell registry pin - the signal-8 session-spawn crash class
#      on 9.5p2 aborts the monitor when DefaultShell is unset/short.
#   4. Start sshd, verify LISTENING on port 22; if it still fails and we are
#      elevated: quarantine the logs dir (upstream last-resort workaround),
#      retry once, then capture `sshd -d` output for the real failure reason.
#   5. When elevated AND -RegisterTask: self-register \DevOptimizer\Sshd-Watch
#      (every 15 min, user+Interactive+Highest - same pattern as
#      PopupTaskAudit-Fix: registers without admin, fires elevated via
#      schtasks /run). Bootstrap path from a limited session: the elevated
#      WSL-Memory-Watchdog calls this script with -RegisterTask once.
param(
    [switch]$RegisterTask,
    [switch]$DryRun
)



$ErrorActionPreference = 'Continue'
$logDir = 'D:\DevOptimizer\logs'
$log    = Join-Path $logDir 'sshd-repair.log'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
function Log([string]$m) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"; Write-Output $m }

$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Log "=== sshd-repair (elevated=$elevated dryRun=$DryRun) ==="

$svc = Get-Service sshd -ErrorAction SilentlyContinue
if (-not $svc) { Log "[sshd] service not installed - nothing to do"; exit 0 }
Log ("[sshd] state={0} startType={1}" -f $svc.Status, $svc.StartType)

# --- 1. config syntax test ---
$sshdExe = "$env:WINDIR\System32\OpenSSH\sshd.exe"
if (-not (Test-Path $sshdExe)) { $sshdExe = (Get-Command sshd.exe -ErrorAction SilentlyContinue).Source }
if ($sshdExe) {
    $cfgTest = & $sshdExe -t 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        # Non-elevated sshd -t can't read ProgramData\ssh host keys (SYSTEM/
        # Admins-only ACL by design) -> "no hostkeys available" is a false
        # positive. Only a real config error should abort.
        if (-not $elevated -and $cfgTest -match 'no hostkeys') {
            Log "[config] indeterminate non-elevated (host keys unreadable by design) - continuing"
        } else {
            Log "[config] sshd -t FAILED: $(($cfgTest -split "`r?`n" | Select-Object -First 1))"
            Log "[config] fix sshd_config first (common: empty DenyUsers/AllowUsers value); aborting"
            exit 1
        }
    } else {
        Log "[config] OK (sshd -t clean)"
    }
} else {
    Log "[config] sshd.exe not found - skipping syntax test"
}

# --- 2. ACL repair (elevated only) ---
$fixScript = "$env:WINDIR\System32\OpenSSH\FixHostFilePermissions.ps1"
if (-not $elevated) {
    Log "[acl] not elevated - skipping ProgramData\ssh repair (run via AdminCleanupTask)"
} elseif (Test-Path $fixScript) {
    if (-not $DryRun) {
        $aclOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $fixScript -Confirm:$false 2>&1 | Out-String
        Log "[acl] FixHostFilePermissions ran: $(($aclOut -split "`n" | Select-Object -Last 2) -join ' | ')"
    } else { Log "[acl] would run FixHostFilePermissions.ps1 (dry-run)" }
} else {
    # Manual fallback: logs dir is the known-bad ACL; SYSTEM+Administrators only.
    $logsPath = 'C:\ProgramData\ssh\logs'
    if (Test-Path $logsPath) {
        if (-not $DryRun) {
            icacls $logsPath /inheritance:r /grant 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' 2>&1 | Out-Null
            Log "[acl] logs dir re-ACL'd manually (vendor script absent)"
        } else { Log "[acl] would re-ACL $logsPath to SYSTEM+Admins only (dry-run)" }
    }
}

# --- 2b. host-key ownership + ACL hardening ---
# 2026-11-14 root cause (verified via SYSTEM-context diag): sshd 9.5p2
# ignores every host key as "Bad owner"/"too open" when the private keys'
# OWNER isn't SYSTEM/Administrators (happens after manual sshd/keygen
# runs) -> service exits "no hostkeys available" while elevated-admin
# sshd -d still works. Fix: owner=SYSTEM, ACL=SYSTEM+Admins only.
if ($elevated -and -not $DryRun) {
    Get-ChildItem 'C:\ProgramData\ssh\ssh_host_*_key' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '\.pub$' } | ForEach-Object {
            icacls $_.FullName /setowner 'NT AUTHORITY\SYSTEM' 2>&1 | Out-Null
            icacls $_.FullName /inheritance:r /grant 'NT AUTHORITY\SYSTEM:(F)' 'BUILTIN\Administrators:(F)' 2>&1 | Out-Null
            Log "[acl] hardened host key $($_.Name) (owner=SYSTEM, SYSTEM+Admins only)"
        }
}

# --- 3. SCM recovery hardening ---
$actions = & sc.exe qfailure sshd 2>&1 | Out-String
if ($actions -notmatch 'RESTART') {
    if ($elevated -and -not $DryRun) {
        & sc.exe failure sshd reset=86400 actions=restart/60000/restart/60000/restart/60000 2>&1 | Out-Null
        Log "[scm] recovery actions set: restart x3 @60s, reset after 1d"
    } else {
        Log "[scm] no recovery actions configured - need elevation to set (restart x3 @60s)"
    }
} else {
    Log "[scm] recovery actions already configured"
}

# --- 3b. DefaultShell registry fix ---
# Signal-8 (SIGFPE/abort) crash class on 9.5p2: service runs fine until a
# client session spawns the default shell - an unset/short DefaultShell path
# aborts the monitor. Pin the full path (documented workaround).
if ($elevated -and -not $DryRun) {
    $sshReg = 'HKLM:\SOFTWARE\OpenSSH'
    $shell  = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path $sshReg)) { New-Item -Path $sshReg -Force | Out-Null }
    $cur = (Get-ItemProperty $sshReg -Name DefaultShell -ErrorAction SilentlyContinue).DefaultShell
    if ($cur -ne $shell) {
        Set-ItemProperty $sshReg -Name DefaultShell -Value $shell
        Set-ItemProperty $sshReg -Name DefaultShellCommandOption -Value '/c' -ErrorAction SilentlyContinue
        Log "[shell] DefaultShell pinned -> $shell"
    } else {
        Log "[shell] DefaultShell already $shell"
    }
}

# --- 4. start + verify ---
if ($svc.Status -ne 'Running') {
    if ($elevated -and -not $DryRun) {
        Start-Service sshd -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } else {
        Log ("[start] sshd is {0} - need elevation to start (or wait for SCM)" -f $svc.Status)
    }
}
$svc2 = Get-Service sshd -ErrorAction SilentlyContinue
if ($svc2.Status -ne 'Running' -and $elevated -and -not $DryRun) {
    # Signal-8 crash loop on 9.5p2: the documented last resort is removing the
    # logs dir entirely - sshd then skips the file appender (ETW still logs).
    # Take one backup listing, delete, retry start once.
    $logsPath = 'C:\ProgramData\ssh\logs'
    if (Test-Path $logsPath) {
        $bak = "$logsPath.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Move-Item $logsPath $bak -Force -ErrorAction SilentlyContinue
        Log "[escalate] crash-loop: moved logs dir -> $bak; retrying start"
        Start-Service sshd -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $svc2 = Get-Service sshd -ErrorAction SilentlyContinue
    }
}
if ($svc2.Status -eq 'Running') {
    $listen = & netstat -ano 2>&1 | Select-String ':22\s+.*LISTENING' | Select-Object -First 1
    Log ("[verify] sshd Running; port22 listening: {0}" -f [bool]$listen)
} else {
    Log ("[verify] sshd still {0}" -f $svc2.Status)
    if ($elevated -and -not $DryRun -and $sshdExe) {
        # Self-diagnosis: run sshd in debug on a scratch port, capture the
        # real failure reason (the service crash reports nothing).
        Log "[diag] running sshd -d on :22222 for 6s to capture the failure..."
        $dbg = Start-Job -ScriptBlock {
            & $using:sshdExe -d -p 22222 2>&1 | Select-Object -First 40
        }
        Start-Sleep -Seconds 6
        Stop-Job $dbg -ErrorAction SilentlyContinue
        $dbgOut = Receive-Job $dbg -ErrorAction SilentlyContinue | Out-String
        Remove-Job $dbg -Force -ErrorAction SilentlyContinue
        ($dbgOut -split "`r?`n" | Select-Object -Last 12) | ForEach-Object { Log "[diag] $_" }

        # SYSTEM-context diag: service runs as LocalSystem; elevated-admin
        # -d masks SYSTEM-only failures (ACLs, profile, token). Temp task.
        $diagScript = 'D:\DevOptimizer\scripts\sshd-system-diag.ps1'
        $diagOut    = 'D:\DevOptimizer\logs\sshd-system-diag.log'
        if (Test-Path $diagScript) {
            $tn = '\DevOptimizer\Sshd-SystemDiag-Temp'
            try {
                $dact = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' `
                    -Argument ('--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $diagScript + '"')
                $dpri = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
                Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Sshd-SystemDiag-Temp' `
                    -Action $dact -Principal $dpri -Force | Out-Null
                Remove-Item $diagOut -Force -ErrorAction SilentlyContinue
                Start-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Sshd-SystemDiag-Temp'
                $waited = 0
                while (-not (Test-Path $diagOut) -and $waited -lt 30) { Start-Sleep 2; $waited += 2 }
                Start-Sleep -Seconds 15
                if (Test-Path $diagOut) {
                    Get-Content $diagOut | Select-Object -Last 40 | ForEach-Object { Log "[sysdiag] $_" }
                } else {
                    Log "[sysdiag] no output produced (task may have failed to launch)"
                }
            } catch {
                Log "[sysdiag] failed: $($_.Exception.Message)"
            } finally {
                Unregister-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Sshd-SystemDiag-Temp' -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
    }
}

# --- 5. self-register elevated watch task ---
if ($RegisterTask) {
    if (-not $elevated) {
        Log "[task] -RegisterTask needs elevation; bootstrap via: schtasks /run /tn AdminCleanupTask"
        exit 3
    }
    if ($DryRun) { Log "[task] would register \DevOptimizer\Sshd-Watch (dry-run)"; exit 0 }
    $act = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' `
        -Argument '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\sshd-repair.ps1"'
    $trg = New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes 15)
    # Same pattern as PopupTaskAudit-Fix / AdminCleanupTask: user+Interactive
    # +Highest registers without admin and fires elevated via schtasks /run.
    $pri = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Sshd-Watch' `
        -Action $act -Trigger $trg -Principal $pri -Force | Out-Null
    Log "[task] \DevOptimizer\Sshd-Watch registered (15 min, headless)"
}
Log "=== sshd-repair done ==="
