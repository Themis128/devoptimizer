$content = Get-Content 'D:\DevOptimizer\SystemCleanup_v5.ps1' -Raw
$openBrace = ([regex]::Matches($content, '\{')).Count
$closeBrace = ([regex]::Matches($content, '\}')).Count
$openParen = ([regex]::Matches($content, '\(')).Count
$closeParen = ([regex]::Matches($content, '\)')).Count

Write-Host "Brace Analysis:" -ForegroundColor Cyan
Write-Host "  Open braces  { : $openBrace"
Write-Host "  Close braces } : $closeBrace"
Write-Host "  Difference     : $($openBrace - $closeBrace)" -ForegroundColor $(if($openBrace -eq $closeBrace){'Green'}else{'Red'})
Write-Host ""
Write-Host "  Open parens  ( : $openParen"
Write-Host "  Close parens ) : $closeParen"
Write-Host "  Difference     : $($openParen - $closeParen)" -ForegroundColor $(if($openParen -eq $closeParen){'Green'}else{'Red'})
