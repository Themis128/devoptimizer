# Wrapper to run Google Calendar MCP server with suppressed stderr
# This script runs the MCP server and redirects stderr to a log file

$logFile = "C:\Users\tbaltzakis\.zcode\logs\google-calendar-mcp.log"
$ErrorActionPreference = "Stop"

# Ensure log directory exists
$logDir = Split-Path $logFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Set GOOGLE_OAUTH_CREDENTIALS to the actual credentials file location
$env:GOOGLE_OAUTH_CREDENTIALS = "C:\Users\tbaltzakis\.config\google-calendar-mcp\gcp-oauth.keys.json"

# Run the MCP server with stderr redirected to log file, stdout to temp file then discard
$stdoutFile = "$env:TEMP\google-calendar-mcp-stdout-$([Guid]::NewGuid()).tmp"
$process = Start-Process "C:\Program Files\nodejs\npx.cmd" -ArgumentList "-y", "@cocal/google-calendar-mcp@2.7.0", "start" -RedirectStandardError $logFile -RedirectStandardOutput $stdoutFile -NoNewWindow -Wait -PassThru
Remove-Item $stdoutFile -Force -ErrorAction SilentlyContinue
exit $process.ExitCode
