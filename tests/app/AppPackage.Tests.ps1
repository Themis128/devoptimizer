#Requires -Version 5.1
# DevOptimizer application package integration tests (Pester 5+). Requires env:DEVOPT_ROOT.

BeforeAll {
    if (-not $env:DEVOPT_ROOT) { throw "env:DEVOPT_ROOT not set - use scripts\Test-App.ps1" }
    $script:Root = $env:DEVOPT_ROOT
    $script:Exe = Join-Path $Root 'app\bin\DevOptimizer.exe'
    $script:Ico = Join-Path $Root 'app\DevOptimizer.ico'
    $script:AppScript = Join-Path $Root 'DevOptimizer-App.ps1'
    $script:UninstKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DevOptimizer'
}

Describe 'Launcher executable' {

    It 'exists and is a small single-file exe' {
        Test-Path $Exe | Should -BeTrue
        (Get-Item $Exe).Length / 1MB | Should -BeLessThan 5
    }

    It '--selfcheck exits 0 and reports a valid script target' {
        $outFile = Join-Path $env:TEMP "devopt-selfcheck-$(Get-Random).txt"
        try {
            # GUI exe: PS 5.1 does not wait on &, so use Start-Process -Wait
            $p = Start-Process -FilePath $Exe -ArgumentList '--selfcheck' -Wait -PassThru `
                     -WindowStyle Hidden -RedirectStandardOutput $outFile
            $p.ExitCode | Should -Be 0
            (Get-Content -LiteralPath $outFile -Raw) | Should -Match 'script=.+\[OK\]'
        } finally {
            Remove-Item $outFile -ErrorAction SilentlyContinue
        }
    }

    It '--selfcheck forwards deep-link arguments' {
        $outFile = Join-Path $env:TEMP "devopt-selfcheck-$(Get-Random).txt"
        try {
            $p = Start-Process -FilePath $Exe -ArgumentList '--selfcheck', '-Category', 'cleanup' -Wait -PassThru `
                     -WindowStyle Hidden -RedirectStandardOutput $outFile
            $p.ExitCode | Should -Be 0
            (Get-Content -LiteralPath $outFile -Raw) | Should -Match 'forwarded=-Category cleanup'
        } finally {
            Remove-Item $outFile -ErrorAction SilentlyContinue
        }
    }

    It 'embeds the brand icon (exe contains icon resources)' {
        $bytes = [System.IO.File]::ReadAllBytes($Exe)
        # The .ico is appended into the Win32 resource section; check a marker of
        # the reserved-but-valid ICONDIR header from our generator survives packing.
        $found = $false
        for ($i = 0; $i -le $bytes.Length - 200; $i++) {
            if ($bytes[$i] -eq 0 -and $bytes[$i + 1] -eq 0 -and $bytes[$i + 2] -eq 1 -and $bytes[$i + 3] -eq 0 -and $bytes[$i + 4] -eq 4 -and $bytes[$i + 5] -eq 0) {
                $found = $true; break
            }
        }
        $found | Should -BeTrue
    }
}

Describe 'Multi-resolution icon' {

    It 'contains the 4 expected directory entries (256/48/32/16)' {
        Test-Path $Ico | Should -BeTrue
        $b = [System.IO.File]::ReadAllBytes($Ico)
        [BitConverter]::ToUInt16($b, 0) | Should -Be 0        # reserved
        [BitConverter]::ToUInt16($b, 2) | Should -Be 1        # type = icon
        $count = [BitConverter]::ToUInt16($b, 4)
        $count | Should -Be 4
        $widths = 0..($count - 1) | ForEach-Object {
            $w = $b[6 + 16 * $_]
            if ($w -eq 0) { 256 } else { $w }
        }
        $widths | Should -Be @(256, 48, 32, 16)
    }
}

Describe 'Install registration' {

    It 'is registered in the per-user Apps list (HKCU Uninstall)' {
        Test-Path $UninstKey | Should -BeTrue
        $e = Get-ItemProperty -Path $UninstKey
        $e.DisplayName | Should -Be 'DevOptimizer'
        $e.UninstallString | Should -Match 'Uninstall-DevOptimizer\.ps1'
        $e.InstallLocation | Should -Be $Root
    }

    It 'has a Start Menu shortcut targeting the launcher' {
        $lnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'DevOptimizer\DevOptimizer.lnk'
        Test-Path $lnk | Should -BeTrue
        $shell = New-Object -ComObject WScript.Shell
        ($shell.CreateShortcut($lnk)).TargetPath | Should -Be $Exe
    }
}

Describe 'Application script (Win 11 integration)' {

    BeforeAll {
        $script:AppText = Get-Content -LiteralPath $AppScript -Raw
    }

    It 'parses as PowerShell without errors' {
        $errs = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($AppScript, [ref]$null, [ref]$errs)
        $errs.Count | Should -Be 0
    }

    It 'embeds a well-formed XAML document with the expected named controls' {
        $m = [regex]::Match($AppText, '(?s)\$xamlXml = @''\r?\n(.+?)\r?\n''@')
        $m.Success | Should -BeTrue
        $xaml = $m.Groups[1].Value
        { $null = [xml]$xaml } | Should -Not -Throw
        foreach ($name in @('MainGrid', 'SettingsPanel', 'BtnSettings', 'CmbTheme', 'CmbLogLevel',
                            'ChkToasts', 'ChkAutoStart', 'BtnSaveSettings', 'CategoryList', 'CommandList')) {
            $xaml | Should -Match ("x:Name=`"{0}`"" -f $name)
        }
    }

    It 'wires the Win 11 components' {
        $AppText | Should -Match 'Import-Module .*DevOptimizer-AppCore\.psm1'
        $AppText | Should -Match 'Test-SingleInstance'
        $AppText | Should -Match 'Set-WindowChrome'
        $AppText | Should -Match 'Send-RunCompleteToast'
        $AppText | Should -Match 'System\.Windows\.Shell\.JumpList'
        $AppText | Should -Match 'Test-CommandFilter'
    }

    It 'accepts deep-link parameters' {
        foreach ($p in @('param', '\$Command', '\$Category', '\[switch\]\$Settings')) {
            $AppText | Should -Match $p
        }
    }

    It 'validates deep-link values at the protocol entry point' {
        $AppText | Should -Match 'deeplinkUnsafe'                                   # unsafe-value rejection
        $AppText | Should -Match "not found in registry - ignored"                  # registry resolution enforced
        $AppText | Should -Match "unknown category"                                 # category resolution enforced
    }

    It 'loads settings from the AppCore schema path' {
        $AppText | Should -Match "Get-AppSettings -SettingsPath"
        $AppText | Should -Match 'app-settings\.json'
    }
}

Describe 'Hub registry metadata' {

    BeforeAll {
        $script:Registry = (Get-Content (Join-Path $Root 'config\hub-registry.json') -Raw | ConvertFrom-Json)
    }

    It 'is schema-valid per hub-registry.schema.json constraints (name pattern, description cap)' {
        foreach ($c in $Registry.commands) {
            $c.name | Should -Match '^[a-z0-9-]+$'
            $c.description.Length | Should -BeLessOrEqual 500
        }
    }

    It 'marks scripts that carry #Requires -RunAsAdministrator (regression: dev-optimizer-fixed)' {
        $c = $Registry.commands | Where-Object { $_.name -eq 'dev-optimizer-fixed' }
        $c | Should -Not -BeNullOrEmpty
        $c.requiresAdmin | Should -BeTrue
        $target = Join-Path $Root ($c.path -replace '/', '\')
        (Get-Content -LiteralPath $target -TotalCount 5) -match 'RunAsAdministrator' | Should -Not -BeNullOrEmpty
    }
}

Describe 'Installer scripts' {

    It 'install and uninstall scripts exist and parse' {
        foreach ($f in @('installer\Install-DevOptimizer.ps1', 'installer\Uninstall-DevOptimizer.ps1')) {
            $p = Join-Path $Root $f
            Test-Path $p | Should -BeTrue
            $errs = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$errs)
            $errs.Count | Should -Be 0
        }
    }
}
