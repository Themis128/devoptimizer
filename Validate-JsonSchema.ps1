<#
.SYNOPSIS
    Validates a JSON file against a JSON Schema (Draft-07) using .NET JSON Schema validator.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$SchemaPath,

    [Parameter(Mandatory=$true, Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]$JsonPath,

    [Parameter()]
    [switch]$FailOnError
)

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$validatorExe = Join-Path -Path $scriptDir -ChildPath "tools\JsonValidator\bin\Release\net8.0\JsonValidator.exe"

if (-not (Test-Path -Path $validatorExe -PathType Leaf)) {
    Write-Error "JSON Schema validator not found at: $validatorExe"
    Write-Error "Please build the validator first: cd tools\JsonValidator && dotnet build -c Release"
    exit 1
}

$schemaFullPath = Resolve-Path -Path $SchemaPath -ErrorAction Stop
$jsonFullPath = Resolve-Path -Path $JsonPath -ErrorAction Stop

try {
    $argList = @("-SchemaPath", $schemaFullPath, "-JsonPath", $jsonFullPath)
    if ($FailOnError) { $argList += "-FailOnError" }
    & $validatorExe @argList
    $exitCode = $LASTEXITCODE
    exit $exitCode
}
catch {
    Write-Error "Validator execution failed: $($_.Exception.Message)"
    exit 1
}