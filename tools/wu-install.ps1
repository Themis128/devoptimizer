# WU install: search pending updates, download, install, report. ASCII-only.
# Exit codes: 0 = installed/nothing-to-do, 1 = install failed, 2 = aborted stage.
# Failures are also written to the log with a FATAL marker and an explicit stage.
param(
    [string]$Log = 'D:\DevOptimizer\logs\wu-install.log'
)
$ErrorActionPreference = 'Stop'
"=== WU install started $(Get-Date -Format s) ===" | Out-File $Log -Encoding utf8

function Fail([string]$stage, [string]$detail) {
    "FATAL: $stage failed: $detail" | Add-Content $Log
    "=== WU install ABORTED $(Get-Date -Format s) ===" | Add-Content $Log
    exit 2
}

try {
    $session = New-Object -ComObject Microsoft.Update.Session
} catch {
    Fail "WU COM session" $_.Exception.Message
}

try {
    "Searching..." | Add-Content $Log
    $searcher = $session.CreateUpdateSearcher()
    $result = $searcher.Search("IsInstalled=0 and IsHidden=0")
} catch {
    Fail "search (is wuauserv running? network up?)" $_.Exception.Message
}
"Found: $($result.Updates.Count) update(s)" | Add-Content $Log
foreach ($u in $result.Updates) { "  - $($u.Title)" | Add-Content $Log }
if ($result.Updates.Count -eq 0) {
    "NOTHING TO DO" | Add-Content $Log
    "=== WU install done $(Get-Date -Format s) ===" | Add-Content $Log
    exit 0
}

$coll = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($u in $result.Updates) {
    try {
        if (-not $u.EulaAccepted) { $u.AcceptEula() }
    } catch {
        "  EULA note for $($u.Title): $($_.Exception.Message)" | Add-Content $Log
    }
    [void]$coll.Add($u)
}

try {
    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $coll
    "Downloading..." | Add-Content $Log
    $dl = $downloader.Download()
} catch {
    Fail "download" $_.Exception.Message
}
"Download result: $($dl.ResultCode) (2=OK, 3=partial, 4=failed, 5=aborted)" | Add-Content $Log
if ($dl.ResultCode -notin 2, 3) {
    Fail "download" "ResultCode $($dl.ResultCode)"
}

try {
    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $coll
    "Installing..." | Add-Content $Log
    $inst = $installer.Install()
} catch {
    Fail "install" $_.Exception.Message
}
"Install result: $($inst.ResultCode) (2=OK, 3=SucceededWithErrors, 4=Failed, 5=Aborted)" | Add-Content $Log
for ($i = 0; $i -lt $coll.Count; $i++) {
    $r = $inst.GetUpdateResult($i)
    "  [$($r.ResultCode)] $($coll.Item($i).Title)" | Add-Content $Log
}
if ($inst.RebootRequired) {
    "REBOOT_REQUIRED" | Add-Content $Log
}
"=== WU install done $(Get-Date -Format s) ===" | Add-Content $Log
if ($inst.ResultCode -in 2, 3) {
    exit 0
}
exit 1
