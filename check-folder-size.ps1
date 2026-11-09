$size = (Get-ChildItem 'D:\Nuxt Projects\llm-dev-agent' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
[math]::Round($size/1GB,2)