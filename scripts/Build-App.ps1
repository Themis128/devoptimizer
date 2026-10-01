#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the DevOptimizer Windows 11 application artifacts:
    a multi-resolution icon, the single-file launcher EXE, and the
    C# WPF shell (DevOptimizer.App) published framework-dependent with ReadyToRun.

.EXAMPLE
    pwsh -NoProfile -File scripts\Build-App.ps1
#>

param(
    [switch]$SkipIcon,
    [switch]$SkipExe
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$icoPath = Join-Path $root 'app\DevOptimizer.ico'
$binDir = Join-Path $root 'app\bin'

Add-Type -AssemblyName System.Drawing

function New-BrandBitmap {
    param([int]$Size)

    # Brand: blue->teal gradient rounded tile with a white 'D' (matches the hub identity)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

    $radius = [Math]::Max(2, [int]($Size * 0.18))
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc($Size - $d - 1, 0, $d, $d, 270, 90)
    $path.AddArc($Size - $d - 1, $Size - $d - 1, $d, $d, 0, 90)
    $path.AddArc(0, $Size - $d - 1, $d, $d, 90, 90)
    $path.CloseFigure()

    $rect = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $rect,
        [System.Drawing.Color]::FromArgb(255, 15, 108, 189),
        [System.Drawing.Color]::FromArgb(255, 78, 201, 176),
        45.0)
    $g.FillPath($brush, $path)

    $fontSize = $Size * 0.62
    $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString('D', $font, [System.Drawing.Brushes]::White, ([System.Drawing.RectangleF]::new(0, 0, $Size, $Size)), $sf)

    $g.Dispose()
    return $bmp
}

function New-MultiResIcon {
    param([string]$OutPath, [int[]]$Sizes = @(256, 48, 32, 16))

    # Draw each size, save as a single-image ICO via GDI, then merge the image
    # blobs into one multi-resolution ICO file.
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "devopt-icon-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    try {
        $images = @()
        foreach ($size in $Sizes) {
            $bmp = New-BrandBitmap -Size $size
            try {
                $hicon = $bmp.GetHicon()
                $icon = [System.Drawing.Icon]::FromHandle($hicon)
                $file = Join-Path $tmpDir "$size.ico"
                $fs = [System.IO.File]::Create($file)
                try { $icon.Save($fs) } finally { $fs.Dispose() }
                $images += @{ Size = $size; File = $file }
            } finally {
                $bmp.Dispose()
            }
        }

        # Merge: ICONDIR (6 bytes) + N ICONDIRENTRY (16 bytes each) + image blobs
        $ms = New-Object System.IO.MemoryStream
        $bw = New-Object System.IO.BinaryWriter $ms
        $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$images.Count)

        $offset = 6 + 16 * $images.Count
        $blobs = @()
        foreach ($img in ($images | Sort-Object { $_.Size } -Descending)) {
            $bytes = [System.IO.File]::ReadAllBytes($img.File)
            # single-image ico: [0..5] header, [6..21] entry, data at entry offset
            $dataOffset = [BitConverter]::ToUInt32($bytes, 6 + 12)
            $dataLen = [BitConverter]::ToUInt32($bytes, 6 + 8)
            $blob = [byte[]]$bytes[$dataOffset..($dataOffset + $dataLen - 1)]
            $w = if ($img.Size -ge 256) { 0 } else { $img.Size }
            $bw.Write([byte]$w)          # width (0 = 256)
            $bw.Write([byte]$w)          # height
            $bw.Write([byte]0)           # palette
            $bw.Write([byte]0)           # reserved
            $bw.Write([uint16]1)         # planes
            $bw.Write([uint16]32)        # bitcount
            $bw.Write([uint32]$dataLen)
            $bw.Write([uint32]$offset)
            $blobs += , $blob
            $offset += $dataLen
        }
        foreach ($blob in $blobs) { $bw.Write($blob) }
        $bw.Flush()
        [System.IO.File]::WriteAllBytes($OutPath, $ms.ToArray())
        $bw.Dispose(); $ms.Dispose()
    } finally {
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    }

    # Validate: parse the directory count back out
    $check = [System.IO.File]::ReadAllBytes($OutPath)
    $count = [BitConverter]::ToUInt16($check, 4)
    if ($count -ne $Sizes.Count) { throw "ICO merge failed: $count entries (expected $($Sizes.Count))" }
    return $count
}

if (-not $SkipIcon) {
    $entries = New-MultiResIcon -OutPath $icoPath
    Write-Host ("[icon]  {0} ({1} sizes)" -f $icoPath, $entries)
}

if (-not $SkipExe) {
    $csproj = Join-Path $root 'app\launcher\DevOptimizer.Launcher.csproj'
    if (-not (Test-Path $csproj)) { throw "Launcher project not found: $csproj" }
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    dotnet publish $csproj -c Release -o $binDir --nologo -v m
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed with exit code $LASTEXITCODE" }
    $exe = Join-Path $binDir 'DevOptimizer.exe'
    if (-not (Test-Path $exe)) { throw "Launcher exe missing after publish: $exe" }
    $mb = [Math]::Round((Get-Item $exe).Length / 1MB, 2)
    Write-Host ("[exe]   {0} ({1} MB)" -f $exe, $mb)

    # C# WPF shell: framework-dependent publish with ReadyToRun, laid out next to the
    # launcher (apphost exe + app dll + deps/runtimeconfig + package assemblies).
    $appProject = Join-Path $root 'app\DevOptimizer.App\DevOptimizer.App.csproj'
    if (-not (Test-Path $appProject)) { throw "App project not found: $appProject" }
    dotnet publish $appProject -c Release -r win-x64 --self-contained false -p:PublishReadyToRun=true -o $binDir --nologo -v m
    if ($LASTEXITCODE -ne 0) { throw "App publish failed with exit code $LASTEXITCODE" }
    $appExe = Join-Path $binDir 'DevOptimizer.App.exe'
    if (-not (Test-Path $appExe)) { throw "App exe missing after publish: $appExe" }
    $appMb = [Math]::Round((Get-Item $appExe).Length / 1MB, 2)
    Write-Host ("[app]   {0} ({1} MB)" -f $appExe, $appMb)
}

Write-Host 'Build-App: OK'
