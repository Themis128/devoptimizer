$path = 'D:\DevOptimizer\SystemCleanup_v5.ps1'
$bytes = [System.IO.File]::ReadAllBytes($path)

Write-Host "File: $path" -ForegroundColor Cyan
Write-Host "Size: $($bytes.Length) bytes"
Write-Host "BOM (first 3 bytes): $([BitConverter]::ToString($bytes[0..2]))"

# Check for problematic characters around line 899
$lines = Get-Content $path
$targetLine = 898  # 0-indexed for line 899

Write-Host "`nLine 899 hex dump:" -ForegroundColor Yellow
$lineBytes = [System.Text.Encoding]::UTF8.GetBytes($lines[$targetLine])
Write-Host "  Bytes: $($lineBytes.Length)"
Write-Host "  Content: $($lines[$targetLine])"

# Show surrounding lines
Write-Host "`nContext (lines 895-905):" -ForegroundColor Yellow
for ($i = 894; $i -lt 905 -and $i -lt $lines.Length; $i++) {
    $lineNum = $i + 1
    $content = $lines[$i]
    if ($content.Length -gt 80) { $content = $content.Substring(0, 77) + "..." }
    Write-Host ("{0,4}: {1}" -f $lineNum, $content)
}
