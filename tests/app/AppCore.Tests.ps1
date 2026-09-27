#Requires -Version 5.1
# DevOptimizer AppCore unit tests (Pester 5+). Requires env:DEVOPT_ROOT.
# All side effects are injected to test-only paths; the real config/registry is untouched.

BeforeAll {
    if (-not $env:DEVOPT_ROOT) { throw "env:DEVOPT_ROOT not set - use scripts\Test-App.ps1" }
    Import-Module (Join-Path $env:DEVOPT_ROOT 'app\DevOptimizer-AppCore.psm1') -Force
    $script:TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "devopt-apptests-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
    $script:TestRunKey = 'HKCU:\Software\DevOptimizer\AppTests\RunProbe'
    if (Test-Path $TestRunKey) { Remove-Item -Path $TestRunKey -Recurse -Force }
}

AfterAll {
    Remove-Item -Path 'HKCU:\Software\DevOptimizer\AppTests' -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppSettings / Save-AppSettings' {

    It 'returns the full default schema when the file is missing' {
        $s = Get-AppSettings -SettingsPath (Join-Path $TmpDir 'missing.json')
        $s.theme            | Should -Be 'dark'
        $s.toasts           | Should -BeTrue
        $s.autostart        | Should -BeFalse
        $s.defaultDryRun    | Should -BeFalse
        $s.logLevel         | Should -Be 'info'
        $s.toastMinSeconds  | Should -Be 10
    }

    It 'round-trips every field through save/load' {
        $p = Join-Path $TmpDir 'roundtrip.json'
        $s = Get-DefaultAppSettings
        $s.theme = 'light'; $s.toasts = $false; $s.autostart = $true
        $s.defaultDryRun = $true; $s.logLevel = 'debug'; $s.toastMinSeconds = 42
        $null = Save-AppSettings -Settings $s -SettingsPath $p
        $r = Get-AppSettings -SettingsPath $p
        $r.theme | Should -Be 'light'
        $r.toasts | Should -BeFalse
        $r.autostart | Should -BeTrue
        $r.defaultDryRun | Should -BeTrue
        $r.logLevel | Should -Be 'debug'
        $r.toastMinSeconds | Should -Be 42
    }

    It 'rejects invalid enum values and keeps the default' {
        $p = Join-Path $TmpDir 'invalid-enum.json'
        '{ "theme": "banana", "logLevel": "verbose" }' | Set-Content -LiteralPath $p
        $r = Get-AppSettings -SettingsPath $p
        $r.theme | Should -Be 'dark'
        $r.logLevel | Should -Be 'info'
    }

    It 'falls back to defaults when the file is corrupted' {
        $p = Join-Path $TmpDir 'corrupt.json'
        '{ this is not json' | Set-Content -LiteralPath $p
        $r = Get-AppSettings -SettingsPath $p
        $r.theme | Should -Be 'dark'
        $r.logLevel | Should -Be 'info'
    }

    It 'drops unknown fields on save (schema-clean output)' {
        $p = Join-Path $TmpDir 'unknown.json'
        $s = Get-DefaultAppSettings
        $s.bogusField = 'x'
        $clean = Save-AppSettings -Settings $s -SettingsPath $p
        $clean.ContainsKey('bogusField') | Should -BeFalse
        (Get-Content -LiteralPath $p -Raw) -notmatch 'bogusField' | Should -BeTrue
    }
}

Describe 'Test-CommandFilter' {

    BeforeAll {
        $script:Cmd = [pscustomobject]@{
            name = 'win-cleanup-tool'; description = 'Removes build junk'
            path = 'tools/win-cleanup-tool.ps1'; tags = @('clean', 'disk'); category = 'ai-ml'
        }
        $script:ByCategoryOnly = [pscustomobject]@{
            name = 'totally-unrelated'; description = 'nothing here'
            path = 'scripts/other.ps1'; tags = @(); category = 'cleanup'
        }
    }

    It 'matches the name' {
        Test-CommandFilter -Command $Cmd -Query 'cleanup' | Should -BeTrue
    }
    It 'matches the description' {
        Test-CommandFilter -Command $Cmd -Query 'junk' | Should -BeTrue
    }
    It 'matches the path' {
        Test-CommandFilter -Command $Cmd -Query 'tools/win' | Should -BeTrue
    }
    It 'matches tags' {
        Test-CommandFilter -Command $Cmd -Query 'disk' | Should -BeTrue
    }
    It 'is case-insensitive' {
        Test-CommandFilter -Command $Cmd -Query 'WIN-CLEANUP' | Should -BeTrue
    }
    It 'empty query matches everything' {
        Test-CommandFilter -Command $Cmd -Query '' | Should -BeTrue
        Test-CommandFilter -Command $Cmd -Query '   ' | Should -BeTrue
    }
    It 'non-matching query returns false' {
        Test-CommandFilter -Command $Cmd -Query 'registry-backup' | Should -BeFalse
    }

    It 'REGRESSION: does not match only because of the category field' {
        Test-CommandFilter -Command $ByCategoryOnly -Query 'cleanup' | Should -BeFalse
    }
}

Describe 'Set-AutoStart / Test-AutoStart (injected Run key)' {

    BeforeEach {
        if (Test-Path $TestRunKey) { Remove-Item -Path $TestRunKey -Recurse -Force }
    }
    AfterAll {
        Remove-Item -Path 'HKCU:\Software\DevOptimizer\AppTests' -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'starts disabled' {
        Test-AutoStart -RunKeyPath $TestRunKey | Should -BeFalse
    }
    It 'enables with a quoted exe target' {
        $r = Set-AutoStart -Enabled:$true -RunKeyPath $TestRunKey -TargetExe 'C:\DevOptimizer\app\bin\DevOptimizer.exe'
        $r | Should -BeTrue
        $v = (Get-ItemProperty -Path $TestRunKey -Name 'DevOptimizer').DevOptimizer
        $v | Should -Be '"C:\DevOptimizer\app\bin\DevOptimizer.exe"'
    }
    It 'disables cleanly' {
        $null = Set-AutoStart -Enabled:$true -RunKeyPath $TestRunKey -TargetExe 'x.exe'
        Set-AutoStart -Enabled:$false -RunKeyPath $TestRunKey | Should -BeFalse
        Test-AutoStart -RunKeyPath $TestRunKey | Should -BeFalse
    }
    It 'requires -TargetExe when enabling' {
        { Set-AutoStart -Enabled:$true -RunKeyPath $TestRunKey } | Should -Throw
    }
}

Describe 'Test-SingleInstance' {

    It 'first acquisition owns the mutex' {
        $a = Test-SingleInstance -MutexName "Local\devopt-test-$(Get-Random)"
        $a.IsFirstInstance | Should -BeTrue
        $a.Mutex.Dispose()
    }

    # Mutexes are thread-affine and reentrant, so a second check from the SAME
    # thread would succeed. Cross-instance semantics must be tested cross-process.
    It 'cross-process: a second instance is blocked, then allowed after release' {
        $name = "Global\devopt-apptest-$(Get-Random)"
        $child = {
            param($MutexName)
            Import-Module (Join-Path $env:DEVOPT_ROOT 'app\DevOptimizer-AppCore.psm1') -Force
            (Test-SingleInstance -MutexName $MutexName).IsFirstInstance
        }
        $a = Test-SingleInstance -MutexName $name
        try {
            $held = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { param(`$n) Import-Module (Join-Path `$env:DEVOPT_ROOT 'app\DevOptimizer-AppCore.psm1') -Force; (Test-SingleInstance -MutexName `$n).IsFirstInstance }" $name
            $held | Should -Be 'False'
        } finally {
            $a.Mutex.Dispose()
        }
        $released = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { param(`$n) Import-Module (Join-Path `$env:DEVOPT_ROOT 'app\DevOptimizer-AppCore.psm1') -Force; (Test-SingleInstance -MutexName `$n).IsFirstInstance }" $name
        $released | Should -Be 'True'
    }
}

Describe 'Set-WindowChrome' {

    It 'returns a safe all-false report for a zero handle without throwing' {
        $r = Set-WindowChrome -WindowHandle ([IntPtr]::Zero)
        $r.DarkTitleBar | Should -BeFalse
        $r.RoundedCorners | Should -BeFalse
        $r.Mica | Should -BeFalse
    }
}

Describe 'Send-RunCompleteToast' {

    It 'does not throw and reports whether the toast was shown' {
        $shown = Send-RunCompleteToast -CommandName 'pester' -Success:$true -DurationSeconds 7
        $shown -is [bool] | Should -BeTrue
    }
}
