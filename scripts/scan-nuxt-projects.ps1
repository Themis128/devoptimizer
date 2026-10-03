<#
.SYNOPSIS
    DevOptimizer automation script: scan-nuxt-projects.
.DESCRIPTION
    DevOptimizer automation script: scan-nuxt-projects.
#>

# Analyze D:\Nuxt Projects: per-project node_modules size + last real source activity
$root = 'D:\Nuxt Projects'
foreach ($proj in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
    $nm = Join-Path $proj.FullName 'node_modules'
    $nmGB = 0
    if (Test-Path $nm) {
        $s = (Get-ChildItem $nm -Recurse -File -Force -ErrorAction SilentlyContinue |
              Measure-Object -Property Length -Sum).Sum
        if ($null -ne $s) { $nmGB = [math]::Round($s/1GB, 2) }
    }
    # newest mtime among files NOT under node_modules = last real dev activity
    $last = (Get-ChildItem $proj.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notlike '*\node_modules\*' } |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 1).LastWriteTime
    $age = if ($last) { [math]::Round(((Get-Date) - $last).TotalDays, 0) } else { -1 }
    Write-Host ("{0,-40} node_modules={1,8} GB   lastActivity={2} days ago" -f $proj.Name, $nmGB, $age)
}
