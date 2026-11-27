<#
.SYNOPSIS
    WSL swap-pressure watchdog - logs VM swap usage, warns at 80% (event 1003),
    drops guest page cache at 90%, and restarts the docker-desktop distro at 95%
    (2h cooldown) to reclaim swap without a full wsl --shutdown.
.DESCRIPTION
    Runs every 30 minutes via scheduled task \DevOptimizer\WSL-Memory-Watchdog. Logs to
    logs\wsl-memory-pressure.log. Host-side guard prevents waking a shut-down WSL VM.
#>
# WSL memory-pressure watchdog - read-only monitor, safe to run any time.
# Logs WSL swap usage to logs\wsl-memory-pressure.log; writes a Warning event
# (DevOptimizer log, source DevOptimizer, event 1003) when swap usage >= 80% -
# the wedge precondition that killed Devin sessions on 2026-10-02.
# Host-side guard: if the WSL VM is not running, log and exit WITHOUT invoking
# wsl.exe (invoking it would wake the VM every run).
# --- sshd ensure (2026-11-07): omv watchdog remediation ssh-hop needs Windows sshd ---
# 2026-11-14: upgraded to delegate repair to sshd-repair.ps1 (this task runs
# elevated every 30 min, so it is the bootstrap lane for ACL repair, SCM
# recovery actions, and one-time registration of \DevOptimizer\Sshd-Watch).
try {
    $sshdRepair = 'D:\DevOptimizer\scripts\sshd-repair.ps1'
    if (Test-Path $sshdRepair) {
        # In-process call - nested `powershell -File` produced no output when
        # spawned inside the conhost --headless task context (2026-11-14).
        $watchExists = $null -ne (Get-ScheduledTask -TaskName 'Sshd-Watch' -ErrorAction SilentlyContinue)
        if ($watchExists) { & $sshdRepair } else { & $sshdRepair -RegisterTask }
        if (Get-ScheduledTask -TaskName 'Sshd-Watch' -ErrorAction SilentlyContinue) {
            New-Item -ItemType File -Path 'D:\DevOptimizer\logs\.sshd-watch-registered' -Force | Out-Null
        }
    } else {
        $sshd = Get-Service sshd -ErrorAction SilentlyContinue
        if ($sshd -and $sshd.StartType -ne 'Automatic') { Set-Service sshd -StartupType Automatic }
        if ($sshd -and $sshd.Status -ne 'Running') {
            try { Start-Service sshd -ErrorAction Stop }
            catch {
                "$(Get-Date -Format o) $($_.Exception.Message)" | Out-File -Append C:\Users\tbaltzakis\devin-scripts\sshd_err.txt
                & 'C:\Program Files\OpenSSH\sshd.exe' -t 2>&1 | Out-File -Append C:\Users\tbaltzakis\devin-scripts\sshd_err.txt
            }
        }
    }
} catch {}

# --- Elevated lane: register Windows-Patch-Check-Elevated without UAC ---
# The limited-token Windows-Patch-Check task can only report; machine-scope
# winget + PSWindowsUpdate installs need HighestAvailable. Its registrar
# self-elevates via a UAC prompt - but THIS task already runs elevated every
# 30 min, so register the elevated variant in-process once (no UAC) and drop
# the limited duplicate. Same bootstrap pattern as Sshd-Watch above.
try {
    $patchTask = Get-ScheduledTask -TaskName 'Windows-Patch-Check-Elevated' -ErrorAction SilentlyContinue
    # Re-register when missing OR when the action is not conhost-headless
    # (first registration used a raw powershell.exe action = monthly flash;
    # popup_task_audit verdict FLASH-RISK caught it 2026-11-14).
    $headless = $patchTask -and ($patchTask.Actions[0].Execute -match 'conhost')
    if (-not $headless) {
        $patchXml = 'C:\Users\tbaltzakis\devin-scripts\win-patch-task-elevated.xml'
        if (Test-Path $patchXml) {
            Register-ScheduledTask -TaskName 'Windows-Patch-Check-Elevated' `
                -Xml (Get-Content $patchXml -Raw) -Force -ErrorAction Stop | Out-Null
            Unregister-ScheduledTask -TaskName 'Windows-Patch-Check' -Confirm:$false -ErrorAction SilentlyContinue
            if (Get-ScheduledTask -TaskName 'Windows-Patch-Check-Elevated' -ErrorAction SilentlyContinue) {
                Add-Content -Path 'D:\DevOptimizer\logs\wsl-memory-pressure.log' -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') (re)registered Windows-Patch-Check-Elevated via elevated piggyback (no UAC, headless action)"
            }
        }
    }
} catch {}

# --- Elevated lane: register \DevOptimizer\Net-Soft-Reset (on-demand) ---
# The heal-resistant wedge escalation target for vhdx-compact-on-devin-exit
# (adapter restarts need elevation; the firing task is limited-rights).
try {
    if (-not (Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Net-Soft-Reset' -ErrorAction SilentlyContinue)) {
        & 'D:\DevOptimizer\scripts\network-soft-reset.ps1' -RegisterTask
        Add-Content -Path 'D:\DevOptimizer\logs\wsl-memory-pressure.log' -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') registered Net-Soft-Reset via elevated piggyback"
    }
} catch {}

# --- Elevated lane: register \DevOptimizer\Popup-Flash-Watch (on-demand) ---
# On-demand console-flash catcher for flashes not attributable to any
# scheduled-task action (popup_task_audit stays clean but flashes persist).
try {
    if (-not (Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Popup-Flash-Watch' -ErrorAction SilentlyContinue)) {
        $act = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' `
            -Argument '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\popup-flash-watch.ps1"'
        $trg = New-ScheduledTaskTrigger -Once -At (Get-Date '2030-01-01')
        $pri = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
        Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Popup-Flash-Watch' `
            -Action $act -Trigger $trg -Principal $pri -Force -ErrorAction Stop | Out-Null
        Add-Content -Path 'D:\DevOptimizer\logs\wsl-memory-pressure.log' -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') registered Popup-Flash-Watch via elevated piggyback (on-demand)"
    }
} catch {}

# --- Elevated lane: register \DevOptimizer\Phone-Tailnet-Watch (10 min) ---
# Layer-2 phone-tailnet watchdog: relaunches the phone's Tailscale app over
# adb when galaxy-s22 drops off the tailnet (omv watcher is layer 1; this
# host covers USB serial + DHCP-drift LAN endpoints omv can't see).
try {
    if (-not (Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Phone-Tailnet-Watch' -ErrorAction SilentlyContinue)) {
        $act = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' `
            -Argument '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\phone-tailnet-watch.ps1"'
        $trg = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10)
        $pri = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Phone-Tailnet-Watch' `
            -Action $act -Trigger $trg -Principal $pri -Force -ErrorAction Stop | Out-Null
        Add-Content -Path 'D:\DevOptimizer\logs\wsl-memory-pressure.log' -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') registered Phone-Tailnet-Watch via elevated piggyback (10 min)"
    }
} catch {}

# --- Elevated lane: register \DevOptimizer\DeepClean-Elevated (monthly 1st 04:00) ---
# Sections 0-5 of admin-cleanup-elevated.ps1 with -SkipVhdx: DISM component
# store, WU download cache, Delivery Optimization cache, oldest shadow copy,
# Windows.old. Docker/WSL untouched, so it is safe to fire any time.
try {
    $dcTask = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'DeepClean-Elevated' -ErrorAction SilentlyContinue
    $dcActionOk = $dcTask -and ($dcTask.Actions.Arguments -match 'SkipVhdx') -and ($dcTask.Actions.Execute -match 'conhost\.exe')
    if (-not $dcActionOk) {
        & schtasks.exe /create /tn '\DevOptimizer\DeepClean-Elevated' /sc monthly /d 1 /st 04:00 /rl HIGHEST /ru $env:USERNAME `
            /tr "C:\Windows\System32\conhost.exe --headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"D:\DevOptimizer\scripts\admin-cleanup-elevated.ps1`" -SkipVhdx" /f | Out-Null
        Add-Content -Path 'D:\DevOptimizer\logs\wsl-memory-pressure.log' -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') registered DeepClean-Elevated via elevated piggyback (monthly 1st 04:00, -SkipVhdx)"
    }
} catch {}


# --- CDP relay firewall pin (2026-11-07): WSL->host 9229 blocked inbound ---
try {
    if (-not (Get-NetFirewallRule -DisplayName 'CDP-Relay-9229' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName 'CDP-Relay-9229' -Direction Inbound -Protocol TCP -LocalPort 9229 -Action Allow | Out-Null
    }
} catch {}

$ErrorActionPreference = 'SilentlyContinue'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$logFile = 'D:\DevOptimizer\logs\wsl-memory-pressure.log'

$vm = Get-Process vmmemWSL -ErrorAction SilentlyContinue
if (-not $vm) {
    Add-Content -Path $logFile -Value "$stamp WSL not running (skipped)"
    exit 0
}

$swapLine = (wsl -e bash -c "free -m") -replace "`r", "" | Where-Object { $_ -match '^Swap:' } | Select-Object -First 1
if ($swapLine -match '^Swap:\s+(\d+)\s+(\d+)\s+(\d+)') {
    $total = [int]$matches[1]
    $used = [int]$matches[2]
    if ($total -gt 0) {
        $pct = [math]::Round(100 * $used / $total)
        Add-Content -Path $logFile -Value "$stamp swap ${used}/${total} MB (${pct}%), vmmemWSL $([math]::Round($vm.WS/1GB,1)) GB"
        if ($pct -ge 80) {
            Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1003 -EntryType Warning `
                -Message "WSL swap pressure ${pct}% (${used}/${total} MB) - wedge risk. Schedule a wsl --shutdown during idle or start fewer containers." `
                -ErrorAction SilentlyContinue
            Add-Content -Path $logFile -Value "$stamp WARNING: swap pressure ${pct}% - event 1003 written"
        }
        if ($pct -ge 90) {
            # Auto-reclaim guest page cache - the same safe first-aid this
            # script previously only advised at 95%. Level 1 (pagecache only)
            # is non-destructive: dirty pages are synced first, cold cache
            # refills from disk on next touch.
            wsl -d Ubuntu-24.04 -u root -- sh -c "sync; echo 1 > /proc/sys/vm/drop_caches" | Out-Null
            Add-Content -Path $logFile -Value "$stamp ACTION: swap ${pct}% - dropped guest page cache"
        }
        if ($pct -ge 95) {
            # Auto-remediate: restart ONLY the docker-desktop distro, not a
            # full wsl --shutdown. Containers come back on restart policies in
            # under a minute and Ubuntu sessions survive - verified 2026-10-25:
            # swap 8.0/8.0 GB -> 0.6 GB, RAM available 3.6 -> 10 GB, public
            # endpoints blipped <60s. 2h cooldown avoids restart loops when
            # the pressure is not docker-owned (e.g. a host-side process).
            $stampFile = 'D:\DevOptimizer\logs\dd-restart.cooldown'
            $cooldownActive = $false
            if (Test-Path $stampFile) {
                if ((Get-Item $stampFile).LastWriteTime -gt (Get-Date).AddHours(-2)) { $cooldownActive = $true }
            }
            if ($cooldownActive) {
                Add-Content -Path $logFile -Value "$stamp CRITICAL: swap ${pct}% persists; docker-desktop restart in 2h cooldown - schedule wsl --shutdown during idle"
            } else {
                $dockerExe = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
                if (Test-Path $dockerExe) {
                    & $dockerExe desktop restart | Out-Null
                    Add-Content -Path $logFile -Value "$stamp ACTION: swap ${pct}% - docker desktop restart issued (auto-remediate)"
                } else {
                    wsl --terminate docker-desktop | Out-Null
                    Add-Content -Path $logFile -Value "$stamp ACTION: swap ${pct}% - wsl --terminate docker-desktop (docker.exe not found)"
                }
                New-Item -ItemType File -Path $stampFile -Force | Out-Null
                Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1003 -EntryType Warning `
                    -Message "WSL swap ${pct}% exhausted - docker-desktop distro restarted to reclaim (2h cooldown armed)." `
                    -ErrorAction SilentlyContinue
            }
        }
    }
}


# Orphaned WSL swap.vhdx reaper (2026-11-11): crashed/terminated VMs leave
# their swap disk in %TEMP%\<GUID>\ behind; five orphans held ~63GB and
# filled C: to 0.7GB free, crashing Docker Desktop and feeding the vsock
# flap loop. The reaper only touches files older than 2h and skips locked
# (live VM) files, so it is safe to run every pass.
try {
    & 'D:\DevOptimizer\scripts\cleanup-wsl-swap-orphans.ps1' | Out-Null
} catch {
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') swap-orphan reaper failed: $($_.Exception.Message)"
}

# C: free-space guard: swap.vhdx + docker_data.vhdx live on C:; when it drops
# below 15GB the guest swap can't grow and Docker Desktop crashes. Warn at
# 15GB, critical at 5GB (event 1004). Reclaims come from the reaper above and
# the nightly VHDX compaction tasks.
try {
    $cFreeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') C: free ${cFreeGB} GB"
    if ($cFreeGB -lt 5) {
        Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1004 -EntryType Error `
            -Message "C: drive critically low: ${cFreeGB} GB free. WSL swap.vhdx and docker_data.vhdx cannot grow - expect WSL stalls and Docker Desktop crashes. Run cleanup-wsl-swap-orphans.ps1 and VHDX compaction." `
            -ErrorAction SilentlyContinue
        Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') CRITICAL: C: free ${cFreeGB} GB - event 1004 written"
    } elseif ($cFreeGB -lt 15) {
        Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1004 -EntryType Warning `
            -Message "C: drive low: ${cFreeGB} GB free. WSL/Docker VHDX growth at risk." `
            -ErrorAction SilentlyContinue
        Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') WARNING: C: free ${cFreeGB} GB - event 1004 written"
    }
} catch {}

# Commit-charge guard (2026-11-27): the night's Devin renderer crash loop
# (-36861 x2 + renderer OOM 0xE0000008) was host COMMIT exhaustion, invisible
# to every existing guard: the only configured D:\pagefile.sys (8-32GB) sits on
# a BitLocker auto-unlock data volume - SMSS skips those at boot, so the file
# never activates and the commit limit was pinned at RAM + C:'s fixed 2GB
# (~33.7GB). vmmemWSL (~10GB) + the post-boot app herd crossed it and
# Windows killed renderers/services (NahimicSvc64 AV 22:54:23 was the same
# casualty class). Fix 2026-11-28: C: pagefile 8192/32768 (OS volume), D:
# entry dropped. Log every pass; event 1005 warning <2GB free commit,
# error <0.75GB; critical-tier page at <0.75GB (band-gated by Notify.ps1).
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $cLimitGB = [math]::Round($os.TotalVirtualMemorySize / 1MB, 1)
    $cFreeGB = [math]::Round($os.FreeVirtualMemory / 1MB, 1)
    $cUsedGB = [math]::Round($cLimitGB - $cFreeGB, 1)
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') commit ${cUsedGB}/${cLimitGB} GB (free ${cFreeGB} GB)"
    if ($cFreeGB -lt 0.75) {
        Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1005 -EntryType Error `
            -Message "Commit charge critical: ${cUsedGB}/${cLimitGB} GB (free ${cFreeGB} GB). Windows kills renderer processes and services at this level (the 2026-11-27 Devin -36861/OOM crash class). Check vmmemWSL commit and verify the C: pagefile config (C:\pagefile.sys 8192 32768 in PagingFiles) is active." `
            -ErrorAction SilentlyContinue
        Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') CRITICAL: commit free ${cFreeGB} GB - event 1005 written"
        try {
            . "$PSScriptRoot\lib\Notify.ps1"
            Send-DevOptAlert -Severity Critical -Force `
                -Title 'Commit charge - virtual memory wall' `
                -Message "commit ${cUsedGB}/${cLimitGB} GB, free ${cFreeGB} GB - renderer/service kills imminent; verify C: pagefile 8192/32768 active in PagingFiles + check vmmemWSL" `
                -Tags 'warning','memory' -EventId 1005
            Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') page sent: commit free ${cFreeGB} GB (critical tier)"
        } catch {
            Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') commit page failed: $($_.Exception.Message)"
        }
    } elseif ($cFreeGB -lt 2) {
        Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1005 -EntryType Warning `
            -Message "Commit charge low: ${cUsedGB}/${cLimitGB} GB (free ${cFreeGB} GB). Renderer kills begin when this approaches 0." `
            -ErrorAction SilentlyContinue
        Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') WARNING: commit free ${cFreeGB} GB - event 1005 written"
    }
} catch {}

# Headless rewrap piggyback: this task runs elevated every 30 min and owns
# no console window (conhost --headless), so it is the safe carrier for
# fixing the highest-run-level tasks that unelevated shells cannot touch.
try {
    $rewrapLog = 'D:\DevOptimizer\scripts\_rewrap-headless-all.log'
    $marker = 'D:\DevOptimizer\scripts\_rewrap-last-run.stamp'
    $last = if (Test-Path $marker) { (Get-Item $marker).LastWriteTime } else { [datetime]::MinValue }
    if (((Get-Date) - $last).TotalHours -ge 6) {
        & 'D:\DevOptimizer\scripts\_rewrap-headless-all.ps1'
        New-Item -ItemType File -Path $marker -Force | Out-Null
        Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') rewrap-headless-all piggybacked (6h throttle)"
    }
} catch {
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') rewrap piggyback failed: $($_.Exception.Message)"
}

# Elevated-once lane: drop a .ps1 into D:\DevOptimizer\elevated-once\ and it
# runs here (elevated, headless) on the next pass, then is deleted. For
# one-shot admin changes unelevated shells cannot do (e.g. IP forwarding).
# Trigger immediately: schtasks /run /tn '\DevOptimizer\WSL-Memory-Watchdog'
try {
    $onceDir = 'D:\DevOptimizer\elevated-once'
    if (Test-Path $onceDir) {
        Get-ChildItem $onceDir -Filter *.ps1 -File | ForEach-Object {
            try {
                & $_.FullName
                Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') elevated-once ran $($_.Name)"
            } catch {
                Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') elevated-once FAILED $($_.Name): $($_.Exception.Message)"
            }
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }
} catch {}
