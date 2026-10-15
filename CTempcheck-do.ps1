Set-Location C:\Users\Public\Microsoft\Windows; Get-ChildItem DeliveryOptimization -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum
