#Requires -Version 5.1
# CATEGORY: verification
# Verify-CommandMatrix.ps1 - Phase E static matrix over the hub registry.
# Read-only checks on every registry command:
#   1. path resolves to an existing file
#   2. entryPoint matches file extension
#   3. ps1 scripts parse with 0 AST errors
#   4. requiresAdmin <-> #Requires -RunAsAdministrator (both directions)
#   5. script Mandatory params missing from registry -> ERROR
#   6. registry params not in script param block -> WARN
#   7. registry params on cmd/python entrypoints -> WARN (Execute-Command emits PS-style args)
# Exit 1 on any ERROR finding; WARNs do not fail the run.

param(
    [string]$JsonReport = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$root = 'D:\DevOptimizer'
$registryPath = Join-Path $root 'config\hub-registry.json'
$logFile = Join-Path $root 'logs\app-runs\command-matrix.log'
$extMap = @{ powershell = @('.ps1'); cmd = @('.bat','.cmd'); python = @('.py') }

$registry = Get-Content $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$commands = @($registry.commands)
$findings = New-Object System.Collections.Generic.List[object]
$script:parseCount = 0

function Add-Finding {
    param([string]$Level, [string]$CmdName, [string]$Check, [string]$Detail)
    $script:findings.Add([pscustomobject]@{ Level = $Level; Command = $CmdName; Check = $Check; Detail = $Detail })
    if (-not $Quiet) {
        $color = @{ ERROR = 'Red'; WARN = 'Yellow' }[$Level]
        Write-Host ("[{0,-5}] {1}: {2} - {3}" -f $Level, $CmdName, $Check, $Detail) -ForegroundColor $color
    }
    Add-Content -Path $logFile -Value ("[{0}] [{1}] {2}: {3} - {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $CmdName, $Check, $Detail) -Encoding UTF8
}

foreach ($c in $commands) {
    $name = $c.name
    $path = Join-Path $root ($c.path -replace '/', '\')

    # 1. path resolves
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Finding 'ERROR' $name 'path' "registry path not found: $($c.path)"
        continue
    }

    $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()

    # 2. entryPoint vs extension
    $expected = $extMap[$c.entryPoint]
    if ($expected -and $expected -notcontains $ext) {
        Add-Finding 'ERROR' $name 'entrypoint' "entryPoint '$($c.entryPoint)' does not match extension '$ext'"
    }

    # 3. ps1 parse
    $paramBlock = $null
    if ($ext -eq '.ps1') {
        $errs = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errs)
        if ($errs.Count -gt 0) {
            Add-Finding 'ERROR' $name 'parse' ($errs[0].Message + ' @ line ' + $errs[0].Extent.StartLineNumber)
        } else {
            $script:parseCount++
            $paramBlock = $ast.ParamBlock
        }
    }

    # 4. admin flag both directions
    $head = @(Get-Content -LiteralPath $path -TotalCount 30 -ErrorAction SilentlyContinue)
    $hasRunAs = [bool]($head | Where-Object { $_ -match '#Requires\s+-RunAsAdministrator' })
    if ($c.requiresAdmin -and -not $hasRunAs) {
        Add-Finding 'WARN' $name 'admin-flag' 'registry says requiresAdmin but script lacks #Requires -RunAsAdministrator (elevation handled by Execute-Command)'
    }
    if ((-not $c.requiresAdmin) -and $hasRunAs) {
        Add-Finding 'ERROR' $name 'admin-flag' 'script has #Requires -RunAsAdministrator but registry lacks requiresAdmin - would fail instantly at execute'
    }

    # 5/6/7. parameter cross-check (ps1 only for 5/6)
    $regParams = @($c.parameters)
    if ($regParams.Count -gt 0 -and $c.entryPoint -in @('cmd','python')) {
        Add-Finding 'WARN' $name 'param-format' "entryPoint '$($c.entryPoint)' has registry params - Execute-Command emits PS-style -Name:Value args that '$($c.entryPoint)' interpreters reject"
    }
    if ($ext -eq '.ps1' -and $paramBlock) {
        $scriptParams = @{}
        foreach ($p in $paramBlock.Parameters) { $scriptParams[$p.Name.VariablePath.UserPath] = $p }

        foreach ($rp in $regParams) {
            if (-not $scriptParams.ContainsKey($rp.name)) {
                Add-Finding 'WARN' $name 'param' "registry param '$($rp.name)' not in script param block - app dialog offers a dead parameter"
            }
        }

        foreach ($sp in $paramBlock.Parameters) {
            $mandatory = $false
            foreach ($attr in $sp.Attributes) {
                if ($attr -is [System.Management.Automation.Language.AttributeAst] -and $attr.TypeName.Name -match 'Parameter') {
                    foreach ($na in $attr.NamedArguments) {
                        if ($na.ArgumentName -eq 'Mandatory' -and $na.Argument.Expression -and $na.Argument.Expression.Value) {
                            $mandatory = $true
                        }
                    }
                }
            }
            if ($mandatory) {
                $pn = $sp.Name.VariablePath.UserPath
                $inReg = [bool]($regParams | Where-Object { $_.name -eq $pn })
                if (-not $inReg) {
                    Add-Finding 'ERROR' $name 'param' "script Mandatory param '$pn' missing from registry - execute fails 'Required parameter missing'"
                }
            }
        }
    }
}

# --- summary ------------------------------------------------------------------
$errors = @($script:findings | Where-Object Level -eq 'ERROR')
$warns = @($script:findings | Where-Object Level -eq 'WARN')
if (-not $Quiet) {
    Write-Host ''
    Write-Host ("Matrix: {0} commands | parse-checked {1} ps1 | {2} ERROR, {3} WARN" -f $commands.Count, $script:parseCount, $errors.Count, $warns.Count)
}
Add-Content -Path $logFile -Value ("[SUMMARY] {0} commands, {1} ps1 parsed, {2} ERROR, {3} WARN" -f $commands.Count, $script:parseCount, $errors.Count, $warns.Count) -Encoding UTF8

if ($JsonReport) {
    $report = [ordered]@{
        date    = (Get-Date).ToString('o')
        total   = $commands.Count
        parseChecked = $script:parseCount
        errors  = $errors.Count
        warns   = $warns.Count
        findings = $script:findings
    }
    $report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $JsonReport -Encoding UTF8
}

if ($errors.Count -gt 0) { exit 1 }
exit 0
